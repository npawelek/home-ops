#!/usr/bin/env bash
# Prepares the data volume before the agent starts. Authoritative on every pod start.
set -euo pipefail

readonly CONFIG_DIR=/run/config
readonly DATA_DIR=/opt/data
readonly PROXY_ENV=HTTP_PROXY,HTTPS_PROXY,NO_PROXY,http_proxy,https_proxy,no_proxy
readonly REPO_URL=https://github.com/npawelek/home-ops.git
readonly REPO_DIR=${DATA_DIR}/repos/home-ops
# bump with the memini chart (lockstep versions); review the plugin diff first, --force accepts a caution scan
readonly MEMINI_PLUGIN_REF=f81b1167713ab15028fd8e09eb832e2970b1b8fb

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

# root-owned sparse checkout of the repo's skills; the agent can read but not edit it
sync_skills() (
  export GIT_CONFIG_GLOBAL=/dev/null
  [[ -d ${REPO_DIR}/.git ]] \
    || git clone --quiet --depth 1 --filter=blob:none --sparse "${REPO_URL}" "${REPO_DIR}"
  git -C "${REPO_DIR}" sparse-checkout set --no-cone /.agents/skills/ \
    && git -C "${REPO_DIR}" fetch --quiet --depth 1 origin main \
    && git -C "${REPO_DIR}" reset --quiet --hard FETCH_HEAD
)

hermes_cli() {
  su - hermes -w "${PROXY_ENV}" -c "HERMES_HOME=${DATA_DIR} /opt/hermes/.venv/bin/hermes $* </dev/null"
}

plugin_revision() {
  /opt/hermes/.venv/bin/python -c \
    'import json, sys; print(json.load(open(sys.argv[1])).get(sys.argv[2], {}).get("revision", ""))' \
    "${DATA_DIR}/plugins/.install-metadata.json" "$1" 2>/dev/null || true
}

install_plugins() {
  [[ -d ${DATA_DIR}/plugins/claude-subscription-directsdk-experimental ]] \
    || hermes_cli plugins install claude-subscription-directsdk \
    || echo "warning: claude-subscription-directsdk install failed" >&2

  [[ $(plugin_revision memini) == "${MEMINI_PLUGIN_REF}" ]] && return 0
  local force=
  [[ -d ${DATA_DIR}/plugins/memini ]] && force=--force
  hermes_cli plugins install ${force} --no-enable --ref "${MEMINI_PLUGIN_REF}" eleboucher/memini-hermes \
    || echo "warning: memini-hermes install failed" >&2
}

main() {
  install_config
  install_mise
  bash "${CONFIG_DIR}/git-init.sh"
  install_env
  sync_skills || echo "warning: skills sync failed; keeping the previous checkout" >&2
  install_plugins
}

main "$@"
