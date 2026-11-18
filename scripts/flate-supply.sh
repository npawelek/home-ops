#!/usr/bin/env bash
set -Eeuo pipefail

# Emit dummy Secrets for SOPS keys that renders reference: cluster-secrets for every
# namespace that includes the sops component, plus HelmRelease valuesFrom inputs.
# flate leaves SOPS values unreadable, so feed this to `--supply -`.

ROOT_DIR="$(git rev-parse --show-toplevel)"

IFS= read -r -d '' DATA <<'EOF' || true
  ADGUARD_BOOTSTRAP_DNS1: 192.0.2.1
  ADGUARD_BOOTSTRAP_DNS2: 192.0.2.2
  ADGUARD_LB_PRIMARY: 192.0.2.3
  ADGUARD_LB_SECONDARY: 192.0.2.4
  AWS_LOGIN_ALIAS: placeholder
  BACKUP_DESTINATION_PATH_AUTHENTIK: s3://placeholder/authentik
  BACKUP_DESTINATION_PATH_MAIN: s3://placeholder/main
  CERTMANAGER_AWS_ACCESS_KEY_ID: placeholder
  CERTMANAGER_AWS_SECRET_KEY: placeholder
  CLUSTER_GATEWAY_INTERNAL_ADDR: 192.0.2.5
  CNPG_LB: 192.0.2.6
  DERPNAS_ADDR: 192.0.2.7
  EMAIL_FROM: placeholder@example.com
  EMAIL_HOST: smtp.example.com
  EMAIL_PASSWORD: placeholder
  EMAIL_USERNAME: placeholder
  EXTERNALDNS_AWS_ACCESS_KEY_ID: placeholder
  EXTERNALDNS_AWS_SECRET_KEY: placeholder
  FLOOFEATER_ADDR: 192.0.2.8
  HDHOMERUN_ADDR: 192.0.2.9
  HDRSAMSUNG55_ADDR: 192.0.2.10
  HOME_ASSISTANT_LB: 192.0.2.11
  HTTPS_PROXY: http://192.0.2.12:8888
  HTTP_PROXY: http://192.0.2.12:8888
  LMSTUDIO_ADDR: 192.0.2.13
  MOSQUITTO_LB: 192.0.2.14
  NIX_NFS_BUILD_EXPORT: /placeholder
  NO_PROXY: localhost,127.0.0.1,.cluster.local
  NTPD_LB: 192.0.2.15
  OCTOPI_ADDR: 192.0.2.16
  OLD_SECRET_DOMAIN: example.net
  OLLAMA_ADDR: 192.0.2.17
  OTEL_GATEWAY_LB: 192.0.2.18
  POOL_ADDR: 192.0.2.19
  PROXY_LB: 192.0.2.12
  RACKNAS_ADDR: 192.0.2.20
  ROSIE_ADDR: 192.0.2.21
  SECRET_AWS_REGION: us-east-1
  SECRET_DOMAIN: example.com
  TIMEZONE: UTC
  UDMP_ADDR: 192.0.2.22
  VALETUDO_AUTH: cGxhY2Vob2xkZXI=
EOF

grep -l 'components/sops' "${ROOT_DIR}"/kubernetes/apps/*/kustomization.yaml \
  | xargs -n1 yq '.namespace' \
  | sort -u \
  | while read -r ns; do
    printf -- '---\napiVersion: v1\nkind: Secret\nmetadata:\n  name: cluster-secrets\n  namespace: %s\nstringData:\n%s\n' "${ns}" "${DATA}"
  done

cat <<'EOF'
---
apiVersion: v1
kind: Secret
metadata:
  name: authentik-secrets
  namespace: auth
stringData:
  secret-key: placeholder
  email-host: smtp.example.com
  email-username: placeholder
  email-password: placeholder
  email-from: placeholder@example.com
---
apiVersion: v1
kind: Secret
metadata:
  name: credentials-authentik
  namespace: auth
stringData:
  username: placeholder
  password: placeholder
---
apiVersion: v1
kind: Secret
metadata:
  name: flux-web-client
  namespace: flux-system
stringData:
  client-secret: placeholder
EOF
