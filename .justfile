set quiet
set shell := ['bash', '-euo', 'pipefail', '-c']

mod bootstrap "cluster/bootstrap"
mod kube "cluster/kubernetes"
mod talos "cluster/talos"

_default:
    just --list kube --list-heading $'Available recipes in module "kube" ["just kube <recipe>"]:\n'
    just --list talos --list-heading $'Available recipes in module "talos" ["just talos <recipe>"]:\n'
    just --list bootstrap --list-heading $'Available recipes in module "bootstrap" ["just bootstrap <recipe>"]:\n'

[private]
log lvl msg *args:
    gum log -t rfc3339 -s -l "{{ lvl }}" "{{ msg }}" {{ args }}
