# iden-lookup

Finds which IdenHQ group grants access to a Twingate resource — by resource name or URL.

```bash
./iden-lookup.sh https://chatsupport.dericrypt.com/   # by URL
./iden-lookup.sh prod-chatwoot-ind-internal           # by resource name
```

Output:
```
Found 1 resource(s):
  prod-chatwoot-ind-internal — DNS: chatsupport.dericrypt.com | Network: prod-india

Iden group(s) for [prod-chatwoot-ind-internal]:
  devops
  chatwoot-agent
```

## Setup

Needs a logged-in IdenHQ session's cookies:

```bash
cp .iden-auth.example .iden-auth   # then fill in the three values
```

| Var | Where to get it |
|---|---|
| `IDEN_SESSION` | `sessionid` cookie |
| `IDEN_CSRF` | `csrftoken` cookie |
| `IDEN_AWSALB` | `AWSALB` cookie |

Grab them from DevTools → Network → any `api.idenhq.com/graphql` request → Copy as cURL,
then read the values out of the `-b/--cookie` string. `.iden-auth` is gitignored.
Alternatively export the three as env vars instead of using the file.

> `AWSALB` is a load-balancer sticky cookie that rotates — refresh it if you hit auth errors.

## How it works

IdenHQ's GraphQL API (`api.idenhq.com/graphql`) models groups as a closure table,
`app_group_closures`. The script:

1. Looks up the resource by `name` (and by `description`, which holds the DNS) via `app_groups`.
2. Walks **up one level** from the resource to its parent group(s) using an `app_group_closures`
   query filtered on `descendant` + `depth: 1`.

Introspection is disabled on the API; field names were found by reading the app's JS bundles.
Requires `curl` and `jq`.
