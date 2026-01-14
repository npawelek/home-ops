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

### Expanding to additional applications

1. Edit the app's `ks.yaml` to include the `authentik-proxy` component:

   ```yaml
   apiVersion: kustomize.toolkit.fluxcd.io/v1
   kind: Kustomization
   metadata:
     name: &app myapp
   spec:
     components:
       - ../../../components/authentik-proxy
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

## LDAP Outpost

TBD ...
