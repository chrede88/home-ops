set quiet
set shell := ['bash', '-euo', 'pipefail', '-c']
set script-interpreter := ['bash', '-euo', 'pipefail']

all-nodes := `talosctl config info -o yaml | yq -e '.endpoints | join(",")'`
controller-node := `talosctl config info -o yaml | yq -e '.endpoints[0]'`

_default:
    just --list bootstrap

[confirm('Bootstrap Cluster [y|N]?')]
[doc('bootstrap Talos, Kubernetes & all resources')]
bootstrap-cluster: nodes kubernetes kubeconfig core apps

[doc('Apply config to all nodes')]
[private]
[script]
nodes:
    just log info "Running stage..." "stage" "$(basename "$0")"
    for node in {{ all-nodes }}; do
        if ! op=$(just talos apply-config "$node" --insecure 2>&1); then
            if [[ "$op" == *"certificate required"* ]]; then
                just log info "Talos already configured, skipping apply of config" "stage" "$(basename "$0")" "node" "$node"
                continue
            fi
            just log fatal "Failed to apply Talos configuration" "stage" "$(basename "$0")" "node" "$node" "output" "$op"
        fi
    done

[doc('Bootstrap Kubernets')]
[private]
[script]
kubernetes:
    just log info "Running stage..." "stage" "$(basename "$0")"
    until op=$(talosctl -n "{{ controller-node }}" bootstrap 2>&1 || true) && [[ "$op" == *"AlreadyExists"* ]]; do
        just log info "Kubernetes bootstrap in progress. Retrying in 5 seconds..." "stage" "$(basename "$0")"
        sleep 5
    done

[doc('Get kubeconfig file')]
[private]
[script]
kubeconfig:
    just log info "Running stage..." "stage" "$(basename "$0")"
        if ! talosctl kubeconfig -n "{{ controller-node }}" --force --merge; then
            just log fatal "Failed to fetch kubeconfig" "stage" "$(basename "$0")"
        fi

[doc('Apply core crds to cluster')]
[private]
[script]
core: ready
    just log info "Running stage..." "stage" "$(basename "$0")"
    if ! kustomize build {{ source_directory() }}/kustomize/apps | just template - | kubectl apply --server-side --force-conflicts -f -; then
        just log fatal "Failed to apply base manifests" "stage" "$(basename "$0")" "file" "$f"
    fi
    if ! helmfile -f "{{ source_directory() }}/helmfile.d/crds.yaml" template -q | yq ea -e 'select(.kind == "CustomResourceDefinition")' | kubectl apply --server-side --force-conflicts -f -; then
        just log fatal "Failed to apply base crds" "stage" "$(basename "$0")"
    fi

[doc('Bootstrap core apps')]
[private]
[script]
apps:
    just log info "Running stage..." "stage" "$(basename "$0")"
        if ! helmfile -f "{{ source_directory() }}/helmfile.d/apps.yaml" sync --hide-notes; then
            just log fatal "Failed to sync helmfile" "stage" "$(basename "$0")"
        fi

[private]
[script]
ready:
    just log info "Running stage..." "stage" "$(basename "$0")"
    if ! kubectl wait nodes --for=condition=Ready=True --all --timeout=10s &>/dev/null; then
        until kubectl wait nodes --for=condition=Ready=False --all --timeout=10s &>/dev/null; do
            just log info "Nodes not available, waiting for nodes to be available. Retrying in 5 seconds..." "stage" "$(basename "$0")"
            sleep 5
        done
    fi
