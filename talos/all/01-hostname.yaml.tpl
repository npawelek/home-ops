---
# talhelper derived this from each node's `hostname:`; topf's `host:` is only a
# selection label, so the HostnameConfig document has to be written explicitly.
apiVersion: v1alpha1
kind: HostnameConfig
auto: "off"
hostname: {{ .Node.Host }}
