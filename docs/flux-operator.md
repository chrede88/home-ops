# Flux Operator
The Flux operator is a fairly new project that aim to transform the old (and maybe a bit clonky) way of using Flux to keep a cluster state up-to-date, into a more modern operator focused approch. You can find the projects Github repo [here](https://github.com/controlplaneio-fluxcd/flux-operator) and the documentation [here](https://fluxcd.control-plane.io/operator/).

I'll layout how I migrated my old Flux to use the operator. This was done with **zero** downtime, which I think is impressive. Great work by the Flux team :+1:

## Installing the Operator
The operator can be installed using a Helm chart. This is very convinient and will be the approach I'll take. It may seem a little crazy, but I'll get Flux to install the Flux operator. A bit like training a guy to take over your current job I guess! For this I'll need to define a HelmRepository and a HelmRelease:

```yaml
# ./cluster/kubernets/flux/resources/helm/flux-operator.yaml
---
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: flux-operator
  namespace: flux-system
spec:
  type: oci
  interval: 2h
  url: oci://ghcr.io/controlplaneio-fluxcd/charts
---
# ./cluster/kubernets/apps/flux-system/flux/flux-operator/helmrelease.yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: flux-operator
spec:
  interval: 30m
  chart:
    spec:
      chart: flux-operator
      version: 0.10.0
      sourceRef:
        kind: HelmRepository
        name: flux-operator
        namespace: flux-system
  install:
    remediation:
      retries: 3
  upgrade:
    cleanupOnFail: true
    remediation:
      retries: 3
  uninstall:
    keepHistory: false
  values:
    serviceMonitor:
      create: true
```

The operator will need a `FluxInstance` to start managing the cluster. In order to make sure the operator is in place and the CRD's are installed I'll make a seperate kustomization for the `FluxInstance` that depends on the kustomization for the Flux operator.

```yaml
# ./cluster/kubernets/apps/flux-system/flux/ks.yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: &app flux-operator
  namespace: flux-system
spec:
  targetNamespace: flux-system
  commonMetadata:
    labels:
      app.kubernetes.io/name: *app
  path: ./cluster/kubernetes/flux-system/flux/flux-operator
  prune: false
  sourceRef:
    kind: GitRepository
    name: flux-system
  wait: false
  interval: 30m
  retryInterval: 1m
  timeout: 5m
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: &app flux-instance
  namespace: flux-system
spec:
  targetNamespace: flux-system
  commonMetadata:
    labels:
      app.kubernetes.io/name: *app
  dependsOn:
    - name: flux-operator
  path: ./cluster/kubernetes/flux-system/flux/flux-instance
  prune: false
  sourceRef:
    kind: GitRepository
    name: flux-system
  wait: false
  interval: 30m
  retryInterval: 1m
  timeout: 5m
```

And finally I'll define the `FluxInstance`.

```yaml
# ./cluster/kubernets/apps/flux-system/flux/flux-instance/instance.yaml
---
apiVersion: fluxcd.controlplane.io/v1
kind: FluxInstance
metadata:
  name: flux
  namespace: flux-system
spec:
  distribution:
    version: "2.4.0"
    registry: "ghcr.io/fluxcd"
  components:
    - source-controller
    - kustomize-controller
    - helm-controller
    - notification-controller
  cluster:
    type: kubernetes
    multitenant: false
    networkPolicy: true
    domain: "cluster.local"
  sync:
    kind: GitRepository
    url: "ssh://git@github.com/chrede88/home-ops.git"
    ref: "refs/heads/main"
    path: "cluster/kubernetes"
    pullSecret: "flux-system"
  kustomize:
    patches:
      - patch: |
          - op: add
            path: /spec/decryption
            value:
              provider: sops
              secretRef:
                name: sops-age
        target:
          kind: Kustomization
```

The `sync` section is important! Make sure this pointing to the correct repository and sub path. Basically, it should be the same values as used for the flux bootstrap command. If you're using SOPS and Age for secret incryption/decryption remember to add a kostomiza patch to the manifest.

Once the operator and `FluxInstance` is deployed you can check if everything vent well by checking the status of the `FluxInstance`:

```zsh
kubectl -n flux-system get fluxinstance flux
```

If the state is `Ready` and the status is something like `Reconciliation finished` you're all set :tada:

### Checking the Flux Status
The operator comes with another new resource called `FluxReport`. This can be used to check the state of Flux.

```zsh
kubectl -n flux-system get fluxreport flux -o yaml
```

### Removing the Old Resources
You can now remove the resources installed by the "old" Flux. If you installed Flux using the standard `bootstrap` method, you should have two files called `gotk-components.yaml` abd `gotk-sync.yaml`. It's now save to remove these from your repository.