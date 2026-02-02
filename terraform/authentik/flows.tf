resource "authentik_flow" "ldap_authentication" {
  name               = "ldap-authentication-flow"
  title              = "LDAP Authentication Flow"
  slug               = "ldap-authentication-flow"
  authentication     = "none"
  designation        = "authentication"
  compatibility_mode = true
  layout             = "stacked"
}

resource "authentik_stage_identification" "ldap_identification" {
  name           = "ldap-identification-stage"
  user_fields    = ["username", "email"]
  password_stage = authentik_stage_password.ldap_password.id
}

resource "authentik_stage_password" "ldap_password" {
  name     = "ldap-password-stage"
  backends = ["authentik.core.auth.InbuiltBackend"]
}

resource "authentik_stage_user_login" "ldap_login" {
  name = "ldap-user-login-stage"
}

resource "authentik_flow_stage_binding" "ldap_identification_binding" {
  target = authentik_flow.ldap_authentication.uuid
  stage  = authentik_stage_identification.ldap_identification.id
  order  = 10
}

resource "authentik_flow_stage_binding" "ldap_password_binding" {
  target = authentik_flow.ldap_authentication.uuid
  stage  = authentik_stage_password.ldap_password.id
  order  = 20
}

resource "authentik_flow_stage_binding" "ldap_login_binding" {
  target = authentik_flow.ldap_authentication.uuid
  stage  = authentik_stage_user_login.ldap_login.id
  order  = 30
}
