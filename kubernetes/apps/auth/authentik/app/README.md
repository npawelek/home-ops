# Authentik

Envoy is configured using Authentik with forwardAuth authentication using the managed embedded outpost for high availability. The configuration is defined as a component for reusability, along with terraform to manage the Authentik components via code.

## Forward Auth Configuration

Using the single-application methodology it's possible to maintain granular permissions for all associated users and groups.

### Auth Overview

```
User Request
    ↓
Envoy Gateway
    ↓
SecurityPolicy (component)
    ↓
Authentik Embedded Outpost (/outpost.goauthentik.io/auth/envoy)
    ↓
    [Authenticated] → Forward to application
[Not Authenticated] → Redirect to Authentik
```

### Choosing a component

|Component|Access|Credentials Authentik checks|Use for|
|---|---|---|---|
|`authentik-proxy`|Web only|Session cookie from the browser login|Apps people use only in a browser (default)|
|`authentik-proxy-token`|Web and CLI/MCP|Session cookie, or `Authorization: Basic <user>:<app password>`|Apps that scripts or agents (MCP servers, CLIs) also call|

Both send requests to the same outpost endpoint; `authentik-proxy-token` also forwards the `Authorization` header, so a client that cannot follow a login redirect can authenticate as a service account. Browsers send no `Authorization` header, so web logins behave identically under either component. Use `authentik-proxy` unless something other than a browser needs access.

An app reached only by a CLI can instead carry its own `SecurityPolicy` that forwards `authorization` and not `cookie`, as `media/jellyfin-collections` does.

### Expanding to additional applications

1. Edit the app's `ks.yaml` to include `authentik-proxy` (or `authentik-proxy-token`, see above):

   ```yaml
   apiVersion: kustomize.toolkit.fluxcd.io/v1
   kind: Kustomization
   metadata:
     name: &app myapp
   spec:
     components:
       - ../../../../components/authentik-proxy
     postBuild:
       substitute:
         APP: *app
     # ...
   ```

2. Edit `kubernetes/apps/auth/authentik/app/referencegrant.yaml` to allow namespace:

   ```yaml
   spec:
     from:
       # ... existing namespaces ...
       - group: gateway.envoyproxy.io
         kind: SecurityPolicy
         namespace: myapp-namespace
       # ...
   ```

3. Add `myapp.tf` to the `terraform/authentik` directory for Authentik components:

   * Proxy provider
   * Application
   * Outpost provider attachment
   * Policy binding for the groups allowed in (e.g. `authentik-admins`)

   For `authentik-proxy-token`, also set `intercept_header_auth = true` on the proxy provider and add a service account (`authentik_user` with `type = "service_account"`) plus a user policy binding to the application. With `policy_engine_mode = "any"`, the group binding admits browser logins and the user binding admits the service account. Create the service account's app password in the Authentik UI after the Terraform applies (it stays out of Terraform state); see `open-knowledge.tf`.

## LDAP Outpost

TBD ...
