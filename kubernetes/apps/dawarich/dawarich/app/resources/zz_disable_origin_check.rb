# frozen_string_literal: true

# Gateway appends "Referrer-Policy: no-referrer" to all responses, so browsers send
# "Origin: null" on same-origin form POSTs and Rails rejects them (422).
# The per-form authenticity token still provides CSRF protection.
ActiveSupport.on_load(:action_controller_base) do
  self.forgery_protection_origin_check = false
end
