#!/usr/bin/env bash
set -Eeuo pipefail

# Render the Flux tree with flate and validate it with flux-schema.
# Extra args go to `flate build all` (e.g. -n <namespace>). Changed-only when
# FLATE_BASE is set (CI). Used by `task validate` and .github/workflows/flate.yaml.

ROOT_DIR="$(git rev-parse --show-toplevel)"

# flate wipes SOPS values to ..PLACEHOLDER_<KEY>.. (also after ${VAR/./-}),
# which fails hostname patterns. Swap in a DNS-safe label.
PLACEHOLDER_SED='s/[.-]\.PLACEHOLDER_[A-Za-z0-9_]+\.\./placeholder/g'

# The API server accepts numeric quantities (resources.limits.cpu: 1, divisor: 1),
# but flux-schema types Quantity as string only, and its skipJSONPath cannot
# descend into arrays. Quote them so upstream charts (cilium, spegel) pass.
QUANTITY_YQ='(.. | select((tag == "!!int" or tag == "!!float") and (path | length >= 3)
  and ((path | .[-1]) == "divisor"
    or ((path | .[-3]) == "resources" and ((path | .[-2]) == "limits" or (path | .[-2]) == "requests")))))
  |= (tostring | . style="double")'

# FLATE_KUBE_VERSION and FLATE_API_VERSIONS come from mise (local) or the workflow (CI).
flate build all --path "${ROOT_DIR}/kubernetes/flux/cluster" --no-progress "$@" \
  | sed -E "${PLACEHOLDER_SED}" \
  | yq "${QUANTITY_YQ}" \
  | flux-schema validate --config "${ROOT_DIR}/.fluxschema.yml"
