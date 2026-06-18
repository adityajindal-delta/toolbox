#!/usr/bin/env bash
# iden-lookup.sh — find the IdenHQ group(s) for a Twingate resource
#
# Usage:
#   ./iden-lookup.sh <twingate-resource-name-or-url>
#
# Examples:
#   ./iden-lookup.sh prod-chatwoot-ind-internal
#   ./iden-lookup.sh https://chatsupport.dericrypt.com/
#
# Requirements: curl, jq
#
# Auth — the script needs three cookie values from a logged-in IdenHQ session.
# Grab them once from any GraphQL request:
#   1. Open https://app.idenhq.com (logged in) → DevTools → Network tab
#   2. Find any request to api.idenhq.com/graphql → right-click → Copy as cURL
#   3. From the -b/--cookie value, copy out: sessionid, csrftoken, AWSALB
#
# Provide them one of two ways:
#   A) Env vars:
#        export IDEN_SESSION=...  IDEN_CSRF=...  IDEN_AWSALB=...
#   B) A local auth file (gitignored) at ./.iden-auth:
#        IDEN_SESSION=...
#        IDEN_CSRF=...
#        IDEN_AWSALB=...
#
# AWSALB is a load-balancer sticky cookie that rotates — refresh it if you hit auth errors.

set -euo pipefail

# Load ./.iden-auth next to the script, if present
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/.iden-auth" ]]; then
  # shellcheck disable=SC1091
  source "${SCRIPT_DIR}/.iden-auth"
fi

SESSION="${IDEN_SESSION:-}"
CSRF="${IDEN_CSRF:-}"
AWSALB="${IDEN_AWSALB:-}"

if [[ -z "$SESSION" || -z "$CSRF" || -z "$AWSALB" ]]; then
  echo "Error: missing IdenHQ credentials." >&2
  echo "Set IDEN_SESSION, IDEN_CSRF and IDEN_AWSALB (env vars or ./.iden-auth)." >&2
  echo "See the header of this script for how to grab them from a GraphQL curl." >&2
  exit 1
fi

SEARCH="${1:?Usage: $0 <twingate-name-or-url>}"
# Strip protocol prefix and trailing slashes/paths
SEARCH="${SEARCH#https://}"
SEARCH="${SEARCH#http://}"
SEARCH="${SEARCH%%/*}"

COOKIES="csrftoken=${CSRF}; sessionid=${SESSION}; AWSALB=${AWSALB}; AWSALBCORS=${AWSALB}"

gql() {
  curl -s 'https://api.idenhq.com/graphql' \
    -H 'accept: application/graphql-response+json, application/json' \
    -H 'content-type: application/json' \
    -H "x-csrftoken: ${CSRF}" \
    -H 'origin: https://app.idenhq.com' \
    -H 'referer: https://app.idenhq.com/' \
    -b "${COOKIES}" \
    -d "$1"
}

# Step 1: find the resource group by name OR dns (description contains the url)
# API doesn't support OR filters, so run two queries and merge
BY_NAME=$(gql "$(jq -n --arg s "$SEARCH" \
  '{query:"query($s:String){app_groups(filters:{name:{i_contains:$s}}){edges{node{external_uuid name description}}}}",variables:{s:$s}}')" \
  | jq '.data.app_groups.edges // []')

BY_DESC_QUERY=$(jq -n --arg s "$SEARCH" \
  '{query:"query($s:String){app_groups(filters:{description:{i_contains:$s},resource_type:{slug:{exact:\"resource\"}}}){edges{node{external_uuid name description}}}}",variables:{s:$s}}')
BY_DESC=$(gql "$BY_DESC_QUERY" | jq '.data.app_groups.edges // []')

# Merge and dedupe by external_uuid
RESULTS=$(jq -n --argjson a "$BY_NAME" --argjson b "$BY_DESC" \
  '($a + $b) | unique_by(.node.external_uuid)')

COUNT=$(echo "$RESULTS" | jq 'length')
if [[ "$COUNT" -eq 0 ]]; then
  echo "No Twingate resource found matching: $SEARCH"
  exit 1
fi

echo "Found $COUNT resource(s):"
echo "$RESULTS" | jq -r '.[] | "  \(.node.name) — \(.node.description)"'
echo ""

# Step 2: for each resource, find its parent IdenHQ groups (depth=1)
echo "$RESULTS" | jq -c '.[]' | while read -r row; do
  UUID=$(echo "$row" | jq -r '.node.external_uuid')
  NAME=$(echo "$row" | jq -r '.node.name')

  PARENTS_PAYLOAD=$(jq -n --arg uuid "$UUID" '{
    query: "query($uuid: UUID) { app_group_closures( filters: { descendant: { external_uuid: { exact: $uuid } } depth: { exact: 1 } } ) { edges { node { ancestor { external_uuid name resource_type { name } } } } } }",
    variables: { uuid: $uuid }
  }')

  PARENTS=$(gql "$PARENTS_PAYLOAD" | jq '.data.app_group_closures.edges')

  echo "Iden group(s) for [$NAME]:"
  echo "$PARENTS" | jq -r '.[] | "  \(.node.ancestor.name)"'
  echo ""
done
