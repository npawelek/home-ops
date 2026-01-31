data "authentik_outpost" "embedded" {
  name = "authentik Embedded Outpost"
}

data "authentik_service_connection_kubernetes" "local" {
  name = "Local Kubernetes Cluster"
}

resource "authentik_outpost" "ldap" {
  name = "LDAP"
  type = "ldap"
  protocol_providers = [
    authentik_provider_ldap.jellyfin.id
  ]
  service_connection = data.authentik_service_connection_kubernetes.local.id
}
