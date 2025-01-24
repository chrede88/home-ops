# Cilium

I installed Cilium at boot, so it could replace Flannel and Kube-proxy. As it was installed using Helm, Flux should be able to take over gracefully.

## Cilium CLI
It can be useful to have the Cilium CLI tool installed on your local dev machine.

```zsh
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
if [ "$(uname -m)" = "arm64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-darwin-${CLI_ARCH}.tar.gz{,.sha256sum}
shasum -a 256 -c cilium-darwin-${CLI_ARCH}.tar.gz.sha256sum
sudo tar xzvfC cilium-darwin-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-darwin-${CLI_ARCH}.tar.gz{,.sha256sum}
```

## Install
I shouldn't have to do anything apart from setting up the Cilium helm chart using Flux.

### Helm repository
I'll setup a Helm repository for Flux. I'll keep all the repositories I need in the same folder so they are easy to find: `./kubernetes/flux-resources/`. These are the files I need to add:

```yaml
# ./cluster/kubernetes/flux/resources/kustomization.yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ./helm
```

```yaml
# ./cluster/kubernetes/flux/resources/helm/kustomization.yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ./cilium.yaml
```

```yaml
# ./cluster/kubernetes/flux/resources/helm/cilium.yaml
---
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: cilium
  namespace: flux-system
spec:
  interval: 2h
  url: https://helm.cilium.io
```

With this I can reference the Helm repository by its name: `cilium`.

### Helm deployment
The actual helm deployment is defined in the `kube-system` folder, as this is the namespace Cilium is install in by default.

These are the files I need:

```yaml
# ./cluster/kubernetes/apps/kube-system/kustomization.yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  # Pre Flux-Kustomizations
  - ./namespace.yaml
  # Flux-Kustomizations
  - ./cilium/ks.yaml # <- adding this line to the main kustomization
components:
  - ../../flux/components/alerts
transformers:
  - |-
    apiVersion: builtin
    kind: NamespaceTransformer
    metadata:
      name: not-used
      namespace: kube-system
    unsetOnly: true
```

```yaml
# ./cluster/kubernetes/apps/kube-system/cilium/ks.yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: &app cilium
  namespace: flux-system
spec:
  targetNamespace: kube-system
  commonMetadata:
    labels:
      app.kubernetes.io/name: *app
  path: ./kubernetes/kube-system/cilium/app
  prune: false # should never be deleted
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
  name: &app cilium-config
  namespace: flux-system
spec:
  targetNamespace: kube-system
  commonMetadata:
    labels:
      app.kubernetes.io/name: *app
  dependsOn:
    - name: cilium
  path: ./kubernetes/kube-system/cilium/config
  prune: false # should never be deleted
  sourceRef:
    kind: GitRepository
    name: flux-system
  wait: false
  interval: 30m
  retryInterval: 1m
  timeout: 5m
```

```yaml
# ./cluster/kubernetes/apps/kube-system/app/kustomization.yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ./helmrelease.yaml
```

```yaml
# ./cluster/kubernetes/apps/kube-system/cilium/app/helmrelease.yaml
---
apiVersion: helm.toolkit.fluxcd.io/v2beta2
kind: HelmRelease
metadata:
  name: cilium
spec:
  interval: 30m
  chart:
    spec:
      chart: cilium
      version: 1.15.5
      sourceRef:
        kind: HelmRepository
        name: cilium
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
    hubble:
      enabled: false
    operator:
      rollOutPods: true
    rollOutCiliumPods: true
    ipam:
      mode: kubernetes
    kubeProxyReplacement: true
    kubeProxyReplacementHealthzBindAddr: 0.0.0.0:10256
    cgroup:
      automount:
        enabled: false
      hostRoot: /sys/fs/cgroup
    k8sServiceHost: localhost
    k8sServicePort: 7445
    l2announcements:
      enabled: true
    gatewayAPI:
      enabled: true
    securityContext:
      capabilities:
        ciliumAgent:
          - CHOWN
          - KILL
          - NET_ADMIN
          - NET_RAW
          - IPC_LOCK
          - SYS_ADMIN
          - SYS_RESOURCE
          - DAC_OVERRIDE
          - FOWNER
          - SETGID
          - SETUID
        cleanCiliumState:
          - NET_ADMIN
          - SYS_ADMIN
          - SYS_RESOURCE
```

The values are identical to the flags set on the initial helm install of Cilium at boot.

And finally some configuration to setup an L2 IP address pool for Services of type LoadBalancer and an L2 Annocement Policy.

```yaml
# ./cluster/kubernetes/apps/kube-system/cilium/config/kustomization.yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ./l2config.yaml
```

```yaml
# ./cluster/kubernetes/apps/kube-system/cilium/config/l2config.yaml
---
apiVersion: cilium.io/v2alpha1
kind: CiliumL2AnnouncementPolicy
metadata:
  name: l2-policy
spec:
  loadBalancerIPs: true
  interfaces: ["^eth[0-9]+"]
  nodeSelector:
    matchLabels:
      kubernetes.io/os: linux
---
apiVersion: cilium.io/v2alpha1
kind: CiliumLoadBalancerIPPool
metadata:
  name: l2-pool
spec:
  allowFirstLastIPs: "Yes"
  blocks:
    - # Controller VIP: 10.10.30.30
      start: 10.10.30.70
      stop: 10.10.30.99
```

Flux now manages Cilium🎉

As I'm planing on using Cilium for Ingress via Gateway API, I need to install the CRDs.

After Flux adds these to the cluster, I'll need to restart Cilium.

```zsh
kubectl -n kube-system rollout restart deployment/cilium-operator
kubectl -n kube-system rollout restart ds/cilium
```

The default `GatewayClass` is not deployed when the CRDs are not present when the Helm Chart is installed at boot. It seems that the Helm Chart must be reinstalled to force the creation of the default GatewayClass called `cilium`. I just changed some values in the Helm Chart, enabling `hubble`. This triggered a reinstall, which created the cilium GatewayClass.

In order to get the hubble UI runnig the following values need to be changed in the helm chart:

```yaml
hubble:
  enabled: true
  relay:
    enabled: true
  ui:
    enabled: true
```