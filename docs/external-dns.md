# External DNS

***Cluster Changes***
I've moved my local dns to my Unifi controller. If you're looking for how external-dns works with pihole, go [here](./old/external-dns-pihoe.md).

External DNS is great little service that automates the creation of dns records. I'll point External DNS to my unifi controller and from there extenal-dns will do the rest.

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
  name: &name external-dns-internal
spec:
  interval: 30m
  chart:
    spec:
      chart: external-dns
      version: 1.15.2
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
    fullnameOverride: *name
    logLevel: &logLevel debug
    serviceMonitor:
      enabled: true
    rbac:
      create: true
      additionalPermissions:
        - apiGroups: ['']
          resources: ['namespaces']
          verbs: ['get', 'watch', 'list']
        - apiGroups: ['gateway.networking.k8s.io']
          resources: ['gateways', 'httproutes']
          verbs: ['get', 'watch', 'list']
    sources:
      - gateway-httproute
    policy: sync
    provider:
      name: webhook
      webhook:
        image:
          repository: ghcr.io/kashalls/external-dns-unifi-webhook
          tag: v0.4.1
        env:
          - name: UNIFI_HOST
            value: https://10.10.0.252
          - name: UNIFI_EXTERNAL_CONTROLLER
            value: 'false'
          - name: UNIFI_API_KEY
            valueFrom:
              secretKeyRef:
                name: external-dns-unifi-secret
                key: api-key
          - name: LOG_LEVEL
            value: *logLevel
        livenessProbe:
          httpGet:
            path: /healthz
            port: http-webhook
          initialDelaySeconds: 10
          timeoutSeconds: 5
        readinessProbe:
          httpGet:
            path: /readyz
            port: http-webhook
          initialDelaySeconds: 10
          timeoutSeconds: 5
    env:
      - name: EXTERNAL_DNS_GATEWAY_LABEL_FILTER
        value: gateway-label==internal-gateway
      - name: EXTERNAL_DNS_LABEL_FILTER
        value: route-label==external-dns-internal
```

If you already have some dns records defined, start by setting `policy: upsert-only`, this ensures that any records already defined won't be removed. Then change this to `sync` later when everything it works correctly.

The Unifi provider uses an externally defined wenhook, which will run as an additional container. The important thing here is the `UNIFI_API_KEY`, that has to be added to a secret. See the [Github repo](https://github.com/kashalls/external-dns-unifi-webhook) for more info on the webhook container.

External-DNS picks up resources based on annotations. I'll add this annotation to my internal gateway: `external-dns.alpha.kubernetes.io/target: <IPtoGatwway>`. With this annotation defined External-DNS will create an A record pointing at my internal gateway for each of the http-routes attached to the gateway.

I've defined some filter labels in the `env` values in order to limit the scope of this instance of external-dns. I've set a gateway filter label that has to be set for a gateway to be picked up. Similar for routes, they'll need a label to be picked up. This way I know that only internal resources are picked up by this instance. I'll have to deploy another instance for my external services and point that to my cloudflare account. I'll likely set this up in the future.