#!/usr/bin/env bash
# Prepares the data volume before the agent starts. Authoritative on every pod start.
set -euo pipefail

readonly CONFIG_DIR=/run/config
readonly DATA_DIR=/opt/data
readonly PROXY_ENV=HTTP_PROXY,HTTPS_PROXY,NO_PROXY,http_proxy,https_proxy,no_proxy

install_config() {
  install -m 0644 -o hermes -g hermes "${CONFIG_DIR}/config.yaml" "${DATA_DIR}/config.yaml"
}

install_mise() {
  mkdir -p "${DATA_DIR}"/.config/mise "${DATA_DIR}"/.local/{bin,share/mise,state/mise} \
    "${DATA_DIR}"/.cache/mise
  cp "${CONFIG_DIR}/mise.toml" "${DATA_DIR}/.config/mise/config.toml"

  # no-ops when $MISE_INSTALL_PATH is already at $MISE_VERSION
  curl -fsSL https://mise.run | sh

  cat >"${DATA_DIR}/.profile" <<EOF
export PATH="${DATA_DIR}/.local/bin:${DATA_DIR}/.local/share/mise/shims:\$PATH"
EOF

  touch "${DATA_DIR}/.bashrc"
  grep -qF "${DATA_DIR}/.local/bin/mise activate bash" "${DATA_DIR}/.bashrc" \
    || echo "eval \"\$(${DATA_DIR}/.local/bin/mise activate bash)\"" >>"${DATA_DIR}/.bashrc"

  chown hermes:hermes "${DATA_DIR}"/.local "${DATA_DIR}"/.local/{bin,share,state}
  chown -R hermes:hermes "${DATA_DIR}"/.bashrc "${DATA_DIR}"/.config \
    "${DATA_DIR}"/.local/bin/mise "${DATA_DIR}"/.local/share/mise \
    "${DATA_DIR}"/.local/state/mise "${DATA_DIR}"/.cache "${DATA_DIR}"/.profile
  su - hermes -w "${PROXY_ENV}" -c "$MISE_INSTALL_PATH prune --yes && $MISE_INSTALL_PATH cache clear"
  su - hermes -w "${PROXY_ENV}" -c "$MISE_INSTALL_PATH install"
}

install_env() {
  local src="/run/secrets/hermes-profiles/default.env"
  [[ -f ${src} ]] || return 0
  install -m 0600 -o hermes -g hermes "${src}" "${DATA_DIR}/.env"
}

opt_out_bundled_skills() {
  [[ -e ${DATA_DIR}/.no-bundled-skills ]] && return 0
  su - hermes -c "HERMES_HOME=${DATA_DIR} /opt/hermes/.venv/bin/hermes skills opt-out --remove --yes" \
    || echo "warning: skills opt-out failed" >&2
}

main() {
  install_config
  install_mise
  bash "${CONFIG_DIR}/git-init.sh"
  install_env
  opt_out_bundled_skills
}

main "$@"
