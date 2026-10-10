#!/usr/bin/env bash
# Renders the agent's git configuration from the secrets projected into this
# container: the GitHub App credentials (GH_APP_*) for authentication, and the
# generated commit-signing key (SSH_SIGNING_KEY*).
#
# Authentication is delegated to git-credential-github-app, installed via mise
# (see mise.toml). It mints short-lived GitHub App installation tokens on demand;
# git-credential-cache holds each token for its lifetime so the GitHub API is not
# called on every git operation.
#
# Signing is delegated to ssh-keygen, reading the key straight from disk. The key
# is only ever used to sign, and anything able to read it out of the pod could
# equally read whatever protected it, so it is stored unencrypted.
set -euo pipefail

: "${HOME:=/opt/data}"

gh_app_dir="${HOME}/.config/github-app"
private_key_file="${gh_app_dir}/private-key.pem"
ssh_dir="${HOME}/.ssh"
signing_key="${ssh_dir}/signing_key"
signing_key_pub="${signing_key}.pub"
allowed_signers="${ssh_dir}/allowed_signers"

install -d -m 0700 "${gh_app_dir}"
printf '%s\n' "${GH_APP_PRIVATE_KEY}" >"${private_key_file}"
chmod 0600 "${private_key_file}"

install -d -m 0700 "${ssh_dir}"
printf '%s\n' "${SSH_SIGNING_KEY}" >"${signing_key}"
chmod 0600 "${signing_key}"
printf '%s\n' "${SSH_SIGNING_KEY_PUB}" >"${signing_key_pub}"
chmod 0644 "${signing_key_pub}"

printf '%s %s\n' "${GIT_COMMITTER_EMAIL}" "${SSH_SIGNING_KEY_PUB}" >"${allowed_signers}"
chmod 0644 "${allowed_signers}"

cat >"${HOME}/.gitconfig" <<EOF
[user]
    name = ${GH_APP_USERNAME}
    email = ${GH_APP_USERNAME}@users.noreply.github.com
    signingkey = ${signing_key}

[checkout]
  defaultRemote = origin

[push]
  default = current
  followTags = true
  autoSetupRemote = true

[pull]
  default = current
  ff = only

[fetch]
  prune = true

[rebase]
  autosquash = true

[credential "https://github.com/npawelek"]
  useHttpPath = true
  helper = "github-app -username ${GH_APP_USERNAME} -appId ${GH_APP_ID} -privateKeyFile ${private_key_file} -installationId ${GH_APP_INSTALLATION_ID}"

[credential "https://github.com"]
  helper = "cache --timeout=43200"

[url "https://github.com"]
  insteadOf = ssh://git@github.com

[url "https://github.com/npawelek"]
  insteadOf = git@github.com:npawelek

[init]
  defaultBranch = main

[gpg]
  format = ssh

[gpg "ssh"]
  allowedSignersFile = ${allowed_signers}

[commit]
  gpgsign = true

[tag]
  gpgsign = true
EOF
chmod 0600 "${HOME}/.gitconfig"

chown -R hermes:hermes "${gh_app_dir}" "${ssh_dir}" "${HOME}/.gitconfig"
