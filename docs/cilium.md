# Cilium

I installed Cilium at boot, so it could replace Flannel and Kubeproxy. As it was installed using Helm, Flux should be able to take over gracefully.

## Install
I shouldn't have to do anything apart from setting up the Cilium helm chart using Flux.

### Helm repository
I'll setup a Helm repository for Flux. I'll keep all the repositories I need in the same folder so they are easy to find: `./kubernetes/flux-resources/`. These are the files I need to add:

```yaml
# kustomization.yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ./helm
```

```yaml
# ./helm/kustomization.yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ./cilium.yaml
```

```yaml
# ./helm/cilium.yaml
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

With this is can reference the Helm repository by its name: `cilium`.

### Helm deployment
The actual helm deployment is defined in the `kube-system` folder, as this is the namespace Cilium is install in by default.

These are the files I need:

```yaml
# kustomization.yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  # Pre Flux-Kustomizations
  - ./namespace.yaml
  - ./slack-token.yaml
  - ./notifications.yaml
  # Flux-Kustomizations
  - ./cilium/ks.yaml # <- adding this line to the main kustomization
```

```yaml
# ./cilium/ks.yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: cilium
  namespace: flux-system
spec:
  targetNamespace: kube-system
  commonMetadata:
    labels:
      app.kubernetes.io/name: cilium
  path: ./kubernetes/kube-system/cilium/app
  prune: false # never should be deleted
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
  name: cilium-config
  namespace: flux-system
spec:
  targetNamespace: kube-system
  commonMetadata:
    labels:
      app.kubernetes.io/name: cilium-config
  dependsOn:
    - name: cilium
  path: ./kubernetes/kube-system/cilium/config
  prune: false # never should be deleted
  sourceRef:
    kind: GitRepository
    name: flux-system
  wait: false
  interval: 30m
  retryInterval: 1m
  timeout: 5m
```

```yaml
# ./cilium/app/kustomization.yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ./helmrelease.yaml
```

```yaml
# ./cilium/app/helmrelease.yaml
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
      version: 1.15.1
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
# ./cilium/config/kustomization.yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ./l2config.yaml
```

```yaml
# ./cilium/config/l2config.yaml
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

Done! Flux now manages Cilium:tada:
