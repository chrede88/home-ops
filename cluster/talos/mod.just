set quiet := true
set shell := ['bash', '-euo', 'pipefail', '-c']

all-nodes := `talosctl config info -o yaml | yq -e '.endpoints | join(",")'`
talhelper_path := justfile_dir() + '/cluster/talos/config'

_default:
    just --list talos

# reboot node [node]
reboot-node node:
    gum confirm "Reboot node {{ node }}?" --default="No" && \
        talosctl -n {{ node }} reboot -m powercycle || exit 0

# shutdown node [node]
shutdown-node node:
    gum confirm "Shutdown node {{ node }}?" --default="No" && \
        talosctl -n {{ node }} shutdown || exit 0

# shutdown cluster
shutdown-cluster:
    gum confirm "Shutdown cluster?" --default="No" && \
        talosctl -n {{ all-nodes }} shutdown --force || exit 0

# get thunderbolt status on node [node]
tb-status node:
    talosctl -n {{ node }} get links | grep thunderbolt

# get thunderbolt statuses from all nodes
tb-status-all:
    talosctl -n {{ all-nodes }} get links | grep thunderbolt

# validate talhelper configuration file
validate-config:
    talhelper validate talconfig {{ talhelper_path }}/talconfig.yaml

# generate talos node configuration files
generate-config: validate-config
    talhelper genconfig -c {{ talhelper_path }}/talconfig.yaml \
    -o {{ talhelper_path }}/clusterconfig \
    -s {{ talhelper_path }}/talsecret.sops.yaml

# apply talos configuration to node [node] [node-name] [--dry-run]
apply-config node node-name *args: generate-config
    talosctl -n {{ node }} apply-config -f {{ talhelper_path }}/clusterconfig/metal-{{ node-name }}.yaml {{ args }}
