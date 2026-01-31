resource "authentik_policy_password" "default" {
  name                    = "default-password-policy"
  length_min              = 16
  amount_uppercase        = 1
  amount_lowercase        = 1
  amount_digits           = 1
  amount_symbols          = 1
  error_message           = "Password must be at least 16 characters with uppercase, lowercase, number, and symbol"
  check_static_rules      = true
  check_have_i_been_pwned = true
  check_zxcvbn            = true
  hibp_allowed_count      = 0
  zxcvbn_score_threshold  = 3
}
