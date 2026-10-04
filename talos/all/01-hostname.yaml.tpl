---
# topf's `host:` is only a selection label and does not set the hostname, so the
# HostnameConfig document has to be written explicitly.
apiVersion: v1alpha1
kind: HostnameConfig
auto: "off"
hostname: {{ .Node.Host }}
