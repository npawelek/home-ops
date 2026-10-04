---
# Alias the node's NIC by MAC (`.Node.Data.mac`) and configure it. The alias name
# ethSel0 is what the nodes already run; renaming it changes every node's config.
apiVersion: v1alpha1
kind: LinkAliasConfig
name: ethSel0
selector:
  match: glob("{{ .Node.Data.mac }}", mac(link.hardware_addr))
---
apiVersion: v1alpha1
kind: LinkConfig
name: ethSel0
mtu: 9000
addresses:
  - address: {{ .Node.IP }}/24
routes:
  - gateway: 192.168.0.1
