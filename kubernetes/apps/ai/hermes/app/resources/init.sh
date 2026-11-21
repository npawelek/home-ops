#!/usr/bin/env bash
# Prepares the data volume before the agent starts. Authoritative on every pod start.
set -euo pipefail

readonly CONFIG_DIR=/run/config
readonly DATA_DIR=/opt/data
readonly PROXY_ENV=HTTP_PROXY,HTTPS_PROXY,NO_PROXY,http_proxy,https_proxy,no_proxy
readonly REPO_URL=https://github.com/npawelek/home-ops.git
readonly REPO_DIR=${DATA_DIR}/repos/home-ops

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

main() {
  install_config
  install_mise
  bash "${CONFIG_DIR}/git-init.sh"
  install_env
  sync_skills || echo "warning: skills sync failed; keeping the previous checkout" >&2
}

main "$@"
