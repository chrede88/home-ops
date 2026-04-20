set quiet
set shell := ['bash', '-euo', 'pipefail', '-c']

_default:
    just --list kube

# open a shell to a node [node]
node-shell node:
    kubectl debug node/{{ node }} -n default -it --image="mirror.gcr.io/alpine:latest" --profile sysadmin
    kubectl delete pod -n default -l app.kubernetes.io/managed-by=kubectl-debug

# prune failed pods in all namespaces
prune-failed-pods:
    kubectl delete pods -A --field-selector status.phase="Failed" --ignore-not-found=true

# list failed pods in all namespaces
list-failed-pods:
    kubectl get pods -A --field-selector status.phase="Failed"

# list completed pods in a namespace
list-completed-pods ns:
    kubectl get pods -n {{ ns }} --field-selector status.phase="Succeeded"

# prune completed pods in a namespace
prune-completed-pods ns:
    kubectl delete pods -n {{ ns }} --field-selector status.phase="Succeeded"

# browse a pvc in namespace [ns] [pvc]
browse-pvc ns pvc:
    kubectl browse-pvc -n {{ ns }} -i mirror.gcr.io/alpine:latest {{ pvc }}

# sync flux Gitrepository [repo]
reconcile-git repo:
    flux reconcile source git {{ repo }}

# sync flux Kustomization [ks]
reconcile-ks ks:
    flux -n flux-system reconcile kustomization {{ ks }}

# sync flux Helmrelease in namespace [ns] [hr]
reconcile-hr ns hr:
    flux -n {{ ns }} reconcile {{ hr }} --with-source

# sync oci repository [repo]
reconcile-oci repo:
    flux -n flux-system reconcile source oci {{ repo }}

# sync all External Secrets objects
sync-es:
    kubectl get es --no-headers -A | while read -r ns name _; do \
        kubectl -n "$ns" annotate --field-manager flux-client-side-apply --overwrite es "$name" force-sync="$(date +%s)"; \
    done

# view secret in namespace [ns] [secret]
view-secret ns secret:
    kubectl view-secret -n {{ ns }} {{ secret }} --all

# get status of CNPG database in namespace [ns] [db]
cnpg-status ns db:
    kubectl cnpg status -n {{ ns }} {{ db }}

# get status of rook-ceph cluster
rook-status:
    kubectl rook-ceph -n rook-ceph ceph status
