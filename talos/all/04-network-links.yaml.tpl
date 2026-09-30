---
# talhelper generated these two documents from each node's `networkInterfaces:`
# entry, naming the alias after the selector's index (ethSel0). Keep the name
# so the rendered config stays byte-identical to the talhelper baseline.
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
