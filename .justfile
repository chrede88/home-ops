set quiet := true
set shell := ['bash', '-euo', 'pipefail', '-c']

mod kube "cluster/kubernetes"
mod talos "cluster/talos"

_default:
    just --list kube --list-heading $'Available recipes in module "kube" ["just kube <recipe>"]:\n'
    just --list talos --list-heading $'Available recipes in module "talos" ["just talos <recipe>"]:\n'
