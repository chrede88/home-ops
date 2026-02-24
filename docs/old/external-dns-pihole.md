# External DNS

External DNS is great little service that automates the creation of dns records. For now, I'll just deployed it for my local dns which I use pihole for. I'll point External DNS to my main pihole instance and from there orbital sync will sync the rest.

## Flux resources
Let's first define the Flux resources I need. The first thing is a helm repository:

```yaml
# ./cluster/kubernets/flux/resources/helm/external-dns.yaml
---
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: external-dns
  namespace: flux-system
spec:
  interval: 2h
  url: https://kubernetes-sigs.github.io/external-dns/
```

Next the kustomization:

```yaml
# ./cluster/kubernetes/apps/network/external-dns/ks.yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: &app external-dns-internal
  namespace: flux-system
spec:
  targetNamespace: network
  commonMetadata:
    labels:
      app.kubernetes.io/name: *app
  dependsOn:
    - name: pihole
  path: ./cluster/kubernetes/network/external-dns/internal
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
  wait: false
  interval: 30m
  retryInterval: 1m
  timeout: 5m
  decryption:
    provider: sops
    secretRef:
      name: sops-age
```

## HelmRelease
Depending on what service you use for Ingress, you'll have to set different environment variables. I'm using Gateway API, so I'll have to set some `additionalPermissions` in the values.

```yaml
# ./cluster/kubernetes/apps/network/external-dns/internal/helmrelease.yaml
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: &app external-dns-internal
spec:
  interval: 30m
  chart:
    spec:
      chart: external-dns
      version: 1.14.4
      sourceRef:
        kind: HelmRepository
        name: external-dns
        namespace: flux-system
  install:
    remediation:
      retries: 3
  upgrade:
    cleanupOnFail: true
    remediation:
      strategy: rollback
      retries: 3
  values:
    fullnameOverride: *app
    serviceMonitor:
      enabled: true
    rbac:
      create: true
      additionalPermissions:
        - apiGroups: [""]
          resources: ["namespaces"]
          verbs: ["get","watch","list"]
        - apiGroups: ["gateway.networking.k8s.io"]
          resources: ["gateways","httproutes","grpcroutes","tlsroutes"]
          verbs: ["get","watch","list"]
    sources:
      - gateway-httproute
      - gateway-grpcroute
      - gateway-tlsroute
    policy: upsert-only
    registry: noop
    provider: pihole
    env:
      - name: EXTERNAL_DNS_PIHOLE_SERVER
        value: http://pihole-0.pihole.network.svc.cluster.local
      - name: EXTERNAL_DNS_GATEWAY_LABEL_FILTER
        value: gateway-label==internal-gateway
      - name: EXTERNAL_DNS_LABEL_FILTER
        value: route-label==external-dns-internal
      - name: EXTERNAL_DNS_PIHOLE_PASSWORD
        valueFrom:
          secretKeyRef:
            name: pihole-secret
            key: EXTERNAL_DNS_PIHOLE_PASSWORD
```

I'll start by setting `policy: upsert-only`, this ensures that any records already defined won't be removed. I'll change this later when I know it works correctly.

External-DNS picks up resources based on annotations. I'll add this annotation to my internal gateway: `external-dns.alpha.kubernetes.io/target: internal.local.cjsolsen.com`. With this annotation defined External-DNS will create an A record pointing at my internal gateway.

I've defined some filter labels in the `env` values in order to limit the scope of this instance of external-dns. I've set a gateway filter label that has to be set for a gateway to be picked up. Similar for routes, they'll need a label to be picked up. This way I know that only internal resources are picked up by this instance. I'll have to deploy another instance for my external services and point that to my cloudflare account. I'll likely set this up in the future.