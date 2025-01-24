# Cloudnative PostgreSQL

I'm going to deploy the Cloudnative-pg operator and for now one PostgreSQL cluster for Gatus. Currently one can't declarively define mulitple databases in a cloudnative-pg cluster. This is a little stupid in my oppinion, but according to the project managers, this is not the idea of cloudnative-pg. They're pushing a model where each microservice (app) has its own cluster. I'm going to follow their example, unless it creates too much overhead. For now, it's not an issue as I only need a single database.

## Flux resources
Let's first define the Flux resources I need. The first thing is a helm repository:

```yaml
# ./cluster/kubernets/flux/resources/helm/cloudnative-pg.yaml
---
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: cloudnative-pg
  namespace: flux-system
spec:
  interval: 2h
  url: https://cloudnative-pg.github.io/charts
```

And next the kustomizations.

```yaml
# ./cluster/kubernetes/apps/database/cloudnative-pg/ks.yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: &app cloudnative-pg
  namespace: flux-system
spec:
  targetNamespace: database
  commonMetadata:
    labels:
      app.kubernetes.io/name: *app
  dependsOn:
    - name: rook-ceph-cluster
  path: ./cluster/kubernetes/database/cloudnative-pg/app
  prune: false # never deleted
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
  name: &app cloudnative-pg-clusters
  namespace: database
spec:
  targetNamespace: database
  commonMetadata:
    labels:
      app.kubernetes.io/name: *app
  dependsOn:
    - name: cloudnative-pg
  path: ./cluster/kubernetes/database/cloudnative-pg/clusters
  prune: false # never deleted
  sourceRef:
    kind: GitRepository
    name: flux-system
  wait: true
  interval: 30m
  retryInterval: 1m
  timeout: 5m
  decryption:
    provider: sops
    secretRef:
      name: sops-age
```
The first kustomization is the operator. The second defines all clusters (for now only one) and it of cource depends on the operator.

## Operator
The operator is defined using a Helm release.

```yaml
# ./cluster/kubernetes/apps/database/cloudnative-pg/app/helmrelease.yaml
---
apiVersion: helm.toolkit.fluxcd.io/v2beta2
kind: HelmRelease
metadata:
  name: cloudnative-pg
spec:
  interval: 30m
  chart:
    spec:
      chart: cloudnative-pg
      version: 0.20.2
      sourceRef:
        kind: HelmRepository
        name: cloudnative-pg
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
    crds:
      create: true
    monitoring:
      podMonitorEnabled: false # <- change when Prometheus is running
      grafanaDashboard:
        create: false # <- change when Prometheus is running
```
The monitoring is turned off for now, as I still haven't deployed Prometheus.

## Clusters

As I already mentioned, I'll only deploy a single cluster now. But with the operator, it's very simple to define more in the future.

```yaml
# ./cluster/kubernetes/apps/database/cloudnative-pg/clusters/gatus-cluster.yaml
---
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: gatus-cluster
  namespace: database
spec:
  instances: 3
  imageName: ghcr.io/cloudnative-pg/postgresql:16.2-10
  bootstrap:
    initdb:
      database: gatus
      owner: gatus
      secret:
        name: gatus-user-secret
  primaryUpdateStrategy: unsupervised
  enableSuperuserAccess: true
  superuserSecret:
    name: cloudnative-pg-secret
  resources:
    requests:
      cpu: 100m
      memory: 500Mi
    limits:
      cpu: 500m
      memory: 1Gi
  postgresql:
    parameters:
      shared_buffers: 128MB
      timezone: "Europe/Zurich"
  storage:
    size: 5Gi
    storageClass: ceph-block
```

The `initdb` field is where the database is defined. The user credentials are defined in a `secret`. I've also enabled the super-user, just in case I need it. The super-user username is hardcoded to `postgres`, this took a me some time to figure out.
I don't really know if the resource requests and limits makes sense, I'll keep an eye on it and adjust if needed.