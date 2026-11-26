resource "authentik_provider_proxy" "open_knowledge" {
  name                         = "open-knowledge-proxy"
  access_token_validity        = var.access_token_validity
  authorization_flow           = data.authentik_flow.default_authorization_flow.id
  invalidation_flow            = data.authentik_flow.default_invalidation_flow.id
  external_host                = "https://ok.${var.domain}"
  internal_host_ssl_validation = true
  mode                         = "forward_single"
  intercept_header_auth        = true
}

resource "authentik_application" "open_knowledge" {
  name               = "OpenKnowledge"
  slug               = "open-knowledge"
  group              = "AI"
  protocol_provider  = authentik_provider_proxy.open_knowledge.id
  meta_icon          = "https://raw.githubusercontent.com/npawelek/home-ops/main/terraform/authentik/icons/open-knowledge.svg"
  meta_launch_url    = "https://ok.${var.domain}"
  policy_engine_mode = "any"
}

resource "authentik_outpost_provider_attachment" "open_knowledge" {
  outpost           = data.authentik_outpost.embedded.id
  protocol_provider = authentik_provider_proxy.open_knowledge.id
}

resource "authentik_policy_binding" "open_knowledge_admins_access" {
  target = authentik_application.open_knowledge.uuid
  group  = data.authentik_group.authentik_admins.id
  order  = 0
}

resource "authentik_user" "open_knowledge_mcp" {
  username = "open-knowledge-mcp"
  name     = "OpenKnowledge MCP"
  path     = "service-accounts"
  type     = "service_account"
}

resource "authentik_policy_binding" "open_knowledge_mcp_access" {
  target = authentik_application.open_knowledge.uuid
  user   = authentik_user.open_knowledge_mcp.id
  order  = 1
}

resource "authentik_user" "open_knowledge_hermes" {
  username = "open-knowledge-hermes"
  name     = "OpenKnowledge Hermes"
  path     = "service-accounts"
  type     = "service_account"
}

resource "authentik_policy_binding" "open_knowledge_hermes_access" {
  target = authentik_application.open_knowledge.uuid
  user   = authentik_user.open_knowledge_hermes.id
  order  = 2
}
