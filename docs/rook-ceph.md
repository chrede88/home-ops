# Ceph & Rook
I'll use the Ceph for Kubernetes storage.

The Rook operator and the Ceph cluster is installed using two Helm Charts:
1) Name: rook-ceph
2) Name: rook-ceph-cluster

The first chart installs the Rook operator and the second sets up the actual Ceph cluster.

## Install

### Flux resources
First I'll create the Flux resources needed for the install.

```yaml
# ./cluster/kubernetes/flux/resources/helm/rook-ceph.yaml
---
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: rook-ceph
  namespace: flux-system
spec:
  interval: 2h
  url: https://charts.rook.io/release
```

```yaml
# ./cluster/kubernetes/apps/rook-ceph/rook-ceph/ks.yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: rook-ceph
  namespace: flux-system
spec:
  targetNamespace: rook-ceph
  commonMetadata:
    labels:
      app.kubernetes.io/name: rook-ceph
  path: ./cluster/kubernetes/rook-ceph/rook-ceph/app
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
  name: rook-ceph-cluster
  namespace: flux-system
spec:
  targetNamespace: rook-ceph
  commonMetadata:
    labels:
      app.kubernetes.io/name: rook-ceph-cluster
  dependsOn:
    - name: rook-ceph
  path: ./cluster/kubernetes/rook-ceph/rook-ceph/cluster
  prune: false # never deleted
  sourceRef:
    kind: GitRepository
    name: flux-system
  wait: true
  interval: 30m
  retryInterval: 1m
  timeout: 5m
```

Notice that the `rook-ceph-cluster` kustomization depends on the `rook-ceph` kustomization.

### Helm charts

First the Rook operator chart:

```yaml
# /cluster/kubernetes/apps/rook-ceph/rook-ceph/app/helmrelease.yaml
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: rook-ceph-operator
spec:
  interval: 30m
  timeout: 15m
  chart:
    spec:
      chart: rook-ceph
      version: v1.13.5
      sourceRef:
        kind: HelmRepository
        name: rook-ceph
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
    csi:
      serviceMonitor:
        enabled: false # <- change when Prometheus is running
    monitoring:
      enabled: false # <- change when Prometheus is running
    resources:
      requests:
        memory: 128Mi
        cpu: 100m
      limits:
        cpu: 200m
        memory: 256Mi
```

Once I've Prometheus runnig I'll enable the `serviceMonitor` and `monitoring` values.

And the Ceph cluster chart:

```yaml
# /cluster/kubernetes/apps/rook-ceph/rook-ceph/cluster/helmrelease.yaml
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: rook-ceph-cluster
spec:
  interval: 30m
  timeout: 15m
  chart:
    spec:
      chart: rook-ceph-cluster
      version: v1.13.5
      sourceRef:
        kind: HelmRepository
        name: rook-ceph
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
  dependsOn:
    - name: rook-ceph-operator
      namespace: rook-ceph
  values:
    monitoring:
      enabled: false # <- change when Prometheus is running
      createPrometheusRules: false # <- change when Prometheus is running
    toolbox:
      enabled: true
    cephClusterSpec:
      mon:
        count: 3
        allowMultiplePerNode: false
      mgr:
        count: 2
        allowMultiplePerNode: false
      dashboard:
        enabled: true
        port: 8080
        ssl: false
      resources:
        mgr:
          requests:
            cpu: 100m
            memory: 512Mi
          limits:
            memory: 1Gi
        mon:
          requests:
            cpu: 100m
            memory: 512Mi
          limits:
            memory: 1Gi
        osd:
          requests:
            cpu: 500m
            memory: 2Gi
          limits:
            memory: 4Gi
        mgr-sidecar:
          requests:
            cpu: 50m
            memory: 128Mi
          limits:
            memory: 256Mi
        crashcollector:
          requests:
            cpu: 100m
            memory: 60Mi
          limits:
            memory: 60Mi
        logcollector:
          requests:
            cpu: 100m
            memory: 100Mi
          limits:
            memory: 1Gi
        cleanup:
          requests:
            cpu: 500m
            memory: 100Mi
          limits:
            memory: 1Gi
        exporter:
          requests:
            cpu: 50m
            memory: 50Mi
          limits:
            memory: 128Mi
      storage:
        useAllNodes: true
        useAllDevices: true
        deviceFilter: nvme0n1
        config:
          osdsPerDevice: "1"
    cephBlockPools:
      - name: ceph-blockpool
        spec:
          failureDomain: host
          replicated:
            size: 3
        storageClass:
          enabled: true
          name: ceph-block
          isDefault: true
          reclaimPolicy: Delete
          allowVolumeExpansion: true
          volumeBindingMode: Immediate
          parameters:
            imageFormat: "2"
            imageFeatures: layering
            csi.storage.k8s.io/provisioner-secret-name: rook-csi-rbd-provisioner
            csi.storage.k8s.io/provisioner-secret-namespace: rook-ceph
            csi.storage.k8s.io/controller-expand-secret-name: rook-csi-rbd-provisioner
            csi.storage.k8s.io/controller-expand-secret-namespace: rook-ceph
            csi.storage.k8s.io/node-stage-secret-name: rook-csi-rbd-node
            csi.storage.k8s.io/node-stage-secret-namespace: rook-ceph
            csi.storage.k8s.io/fstype: ext4
    cephFileSystems:
      - name: ceph-filesystem
        spec:
          metadataPool:
            replicated:
              size: 3
          dataPools:
            - failureDomain: host
              replicated:
                size: 3
              name: data0
          metadataServer:
            activeCount: 1
            activeStandby: true
            resources:
              requests:
                cpu: 100m
                memory: 1Gi
              limits:
                memory: 4Gi
            priorityClassName: system-cluster-critical
        storageClass:
          enabled: true
          isDefault: false
          name: ceph-filesystem
          pool: data0
          reclaimPolicy: Delete
          allowVolumeExpansion: true
          volumeBindingMode: Immediate
          parameters:
            csi.storage.k8s.io/provisioner-secret-name: rook-csi-cephfs-provisioner
            csi.storage.k8s.io/provisioner-secret-namespace: rook-ceph
            csi.storage.k8s.io/controller-expand-secret-name: rook-csi-cephfs-provisioner
            csi.storage.k8s.io/controller-expand-secret-namespace: rook-ceph
            csi.storage.k8s.io/node-stage-secret-name: rook-csi-cephfs-node
            csi.storage.k8s.io/node-stage-secret-namespace: rook-ceph
            csi.storage.k8s.io/fstype: ext4
    cephObjectStores:
      - name: ceph-objectstore
        spec:
          metadataPool:
            failureDomain: host
            replicated:
              size: 3
          dataPool:
            failureDomain: host
            erasureCoded:
              dataChunks: 2
              codingChunks: 1
          preservePoolsOnDelete: true
          gateway:
            port: 80
            resources:
              requests:
                cpu: 100m
                memory: 1Gi
              limits:
                memory: 2Gi
            instances: 1
            priorityClassName: system-cluster-critical
        storageClass:
          enabled: true
          name: ceph-bucket
          reclaimPolicy: Delete
          volumeBindingMode: Immediate
          parameters:
            region: us-east-1
```
Almost all the values defined in this chart are the defaults. I've added them so I can more easily go back and see the setup.
I've set the `dashboard.port` to 8080 instead of the default 8443, mostly because 8443 reminds me of `https` which is disabled (by setting `dashboard.ssl: false`).

Some of the pods need to run in a privileged state. Therefore I need to tell Kubernetes to bypass the normal admission policies for the `rook-ceph` namespace. This can be done by adding a label to the namespace definition:

```yaml
# /cluster/kubernetes/apps/rook-ceph/rook-ceph/namespace.yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: rook-ceph
  annotations:
    kustomize.toolkit.fluxcd.io/prune: disabled
  labels:
    pod-security.kubernetes.io/enforce: privileged
```

Without this, the setup will fail!