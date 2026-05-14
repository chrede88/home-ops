set quiet
set shell := ['bash', '-euo', 'pipefail', '-c']
set script-interpreter := ['bash', '-euo', 'pipefail']

all-nodes := `talosctl config info -o yaml | yq -e '.endpoints | join(",")'`
talhelper_path := module_directory() + '/config'

_default:
    just --list talos

[confirm('Reboot node [y|N] ?')]
[doc('reboot node [node]')]
reboot-node node:
    talosctl -n {{ node }} reboot -m powercycle

[confirm('Shutdown node [y|N] ?')]
[doc('shutdown node [node]')]
shutdown-node node:
    talosctl -n {{ node }} shutdown

[confirm('Shutdown cluster [y|N] ?')]
[doc('shutdown cluster')]
shutdown-cluster:
    talosctl -n {{ all-nodes }} shutdown --force

[doc('get thunderbolt status on node [node]')]
tb-status node:
    talosctl -n {{ node }} get links | grep thunderbolt

[doc('get thunderbolt statuses from all nodes')]
tb-status-all:
    talosctl -n {{ all-nodes }} get links | grep thunderbolt

[doc('validate talhelper configuration file')]
validate-config:
    talhelper validate talconfig {{ talhelper_path }}/talconfig.yaml

[doc('generate talos node configuration files')]
generate-config: validate-config
    talhelper genconfig -c {{ talhelper_path }}/talconfig.yaml \
    -o {{ talhelper_path }}/clusterconfig \
    -s {{ talhelper_path }}/talsecret.sops.yaml

[doc('apply talos configuration to node [node] [--dry-run]')]
[script]
apply-config node *args: generate-config
    node_name="$(just talos render-node {{ node }})"
    talosctl -n {{ node }} apply-config -f {{ talhelper_path }}/clusterconfig/metal-${node_name}.yaml {{ args }}

[private]
render-node node:
    yq '.servers[] | select(.ip == "{{ node }}") | .name' {{ justfile_directory() }}/network/overview.yaml
