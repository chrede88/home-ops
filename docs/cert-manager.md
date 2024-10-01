# Cert-manager
I use Cert-manager to generate TLS certificates for me. This is a must have feature in my opinion. Luckily for me, Cert-manager works with the new Gateway API in a really nice way. I just need to add a label to a Gateway and Cert-manager will take care of the rest 👍

## Install
Cert-manager needs the Gateway CRDs, which I already installed with Cilium. So as long as I just set Cert-manager to depend on the install of Cilium, I should be fine in the future.

Cert-manager can be installed using their official Helm chart.

Let me first define the Flux resources:

```yaml
# ./cluster/kubernetes/flux-resources/helm/cert-manager.yaml
---
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: cert-manager
  namespace: flux-system
spec:
  interval: 2h
  url: https://charts.jetstack.io
```

```yaml
# ./cluster/kubernetes/cert-manager/kustomization.yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  # Pre Flux-Kustomizations
  - ./namespace.yaml
  - ./slack-token.yaml
  - ./notifications.yaml
  # Flux-Kustomizations
  - ./cert-manager/ks.yaml
```

```yaml
# ./cluster/kubernetes/cert-manager/cert-manager/ks.yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: cert-manager
  namespace: flux-system
spec:
  targetNamespace: cert-manager
  commonMetadata:
    labels:
      app.kubernetes.io/name: cert-manager
  dependsOn:
    - name: cilium-crd
  path: ./cluster/kubernetes/cert-manager/cert-manager/app
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
  name: cert-manager-issuer
  namespace: flux-system
spec:
  targetNamespace: cert-manager
  commonMetadata:
    labels:
      app.kubernetes.io/name: cert-manager-issuer
  dependsOn:
    - name: cert-manager
  path: ./cluster/kubernetes/cert-manager/cert-manager/issuer
  sourceRef:
    kind: GitRepository
    name: flux-system
  wait: false
  interval: 30m
  retryInterval: 1m
  timeout: 5m
```

With that out of the way, let's create the Helm release.

```yaml
# ./cluster/kubernetes/cert-manager/cert-manager/app/helmrelease.yaml
---
apiVersion: helm.toolkit.fluxcd.io/v2beta2
kind: HelmRelease
metadata:
  name: cert-manager
spec:
  interval: 30m
  chart:
    spec:
      chart: cert-manager
      version: v1.15.3
      sourceRef:
        kind: HelmRepository
        name: cert-manager
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
    installCRDs: true
    replicaCount: 1
    dns01RecursiveNameservers: 1.1.1.1:53,1.0.0.1:53
    dns01RecursiveNameserversOnly: true
    podDnsPolicy: None
    podDnsConfig:
      nameservers:
        - 1.1.1.1
        - 1.0.0.1
   config:
      apiVersion: controller.config.cert-manager.io/v1alpha1
      kind: ControllerConfiguration
      enableGatewayAPI: true
```
I'm hardcoding the DNS here, as other people have had issues with cert-manager not resolving DNS names, when not setting the DNS resolvers in the chart.

Lastly, I need to setup a `ClusterIssuer`:

```yaml
# ./cluster/kubernetes/cert-manager/cert-manager/issuer/letsencrypt-production.yaml
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-production
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: christian@cjsolsen.com
    privateKeySecretRef:
      name: letsencrypt-production
    solvers:
      - selector:
          dnsZones:
            - "cjsolsen.com"
        dns01:
          cloudflare:
            email: christian@cjsolsen.com
            apiTokenSecretRef:
              name: cloudflare-api-token-secret
              key: api-token
```
My domain is hosted by Cloudflare, so that's where the certificates should be verified. I'll provide my Cloudflare API token through a secret.

I've used this setup before, I know it works. If this is not the case, setup another ClusterIssuer that uses the staging environment of Lets Encrypt. This way you won't hit the rate limit, if something isn't working correctly. Once everything is good, swtich to the production issuer. Here is an example of a test issuer:

```yaml
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: christian@cjsolsen.com
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
      - selector:
          dnsZones:
            - "cjsolsen.com"
        dns01:
          cloudflare:
            email: christian@cjsolsen.com
            apiTokenSecretRef:
              name: cloudflare-api-token-secret
              key: api-token
```
Notice that the `spec.acme.server` field points to the staging server.

## Getting certificates
If Cert-manager should get a certificate the following conditions must be met:

1) The defined gateway must reference the defined cluster issuer
2) The listener `hostname` must not be empty.
3) `tls.mode` must be set to `Terminate`.
4) `tls.certificateRef.name` must not be empty.
5) `tls.certificateRef.kind` must be set to `Secret` (if set).
6) `tls.certificateRef.group` must be set to `core` (if set).
7) `tls.certificateRef.namespace` must be the same namespace as the Gateway (if set).

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: example
  namespace: default
  annotations:
    cert-manager.io/cluster-issuer: foo # <- 1.
spec:
  gatewayClassName: foo
  addresses:
    - value: requested-IP-from-Cilium
  listeners:
    - name: example
      hostname: example.com # <- 2.
      port: 443
      protocol: HTTPS
      allowedRoutes:
        namespaces:
          from: All
      tls:
        mode: Terminate # <- 3.
        certificateRefs:
          - name: example-com-tls # <- 4.
            kind: Secret # <- 5.
            group: core # <- 6.
            namespace: default # <- 7.
```

If all 7 conditions are met Cert-manager will get a certificate for the specificed hostname. If one (or more) conditions are not met, Cert-manager will ignore the listener.

### Note (March 5th, 2024)
It seems I can only get the Gateway to accept my `tls` setting if `kind`, `group` & `namespace` is not set.

Right now (v1.15.1) the `addresses` field in the Gateway manifest is completely ignored by Cilium. They're working on a fix.