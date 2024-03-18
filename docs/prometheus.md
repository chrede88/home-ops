# Prometheus & Grafana
Prometheus is the defacto leader when it comes to observability. Almost all services that are meant to run in Kubernetes publishes an endpoint tailored to Prometheus. Coupling Prometheus with Grafana for visualization is close to a perfect solution.

I'll install Prometheus using the `kube-prometheus-stack` helm chart. This is a super nice helm chart that bundles everything up into one. I'm not a big fan of all the standard dashbaords that this helm chart installes in Grafana, so I'll actually installed Grafana using a seperate helm chart. This give me better control over what dashbaords are installed.

## Flux resources
As always, I need bunch of Flux resources. I'll install Prometheus and Grafana in a seperate namespace called `observability`. The `node-exporters` that the scapes data from the nodes running Kubernetes needs to run in a privileged state, so in an attempt to not give too many services extra privileges I'll seperate these services in their own namespace.

Before I get to the namespace specific resources, I first have to add the two new helm repositories to my cluster, so flux can find them.

```yaml
# ./cluster/kuberntes/flux-resources/helm/prometheus-community.yaml
---
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: prometheus-community
  namespace: flux-system
spec:
  interval: 2h
  url: https://prometheus-community.github.io/helm-charts
```

```yaml
# ./cluster/kuberntes/flux-resources/helm/grafana.yaml
---
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: grafana
  namespace: flux-system
spec:
  interval: 2h
  url: https://grafana.github.io/helm-charts
```

Next all the new stuff to setup a new namespace and the two helm charts.

```yaml
# ./cluster/kuberntes/observability/kustomization.yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  # Pre Flux-Kustomizations
  - ./namespace.yaml
  - ./slack-token.yaml
  - ./notifications.yaml
  # Flux-Kustomizations
  - ./kube-prometheus-stack/ks.yaml
  - ./grafana/ks.yaml
```
This is completely standard, so I won't put all the manifests here. The namespace is a little special.

```yaml
# ./cluster/kuberntes/observability/namespace.yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: observability
  annotations:
    kustomize.toolkit.fluxcd.io/prune: disabled
  labels:
    pod-security.kubernetes.io/enforce: privileged
    internal-gateway-access: "true"
```
The first label gives everything running in this namespace extra privileges. The second is needed for cross namespace ingress.

As I'm installing two seperate helm charts, I've two seperate kustomizations:

```yaml
# ./cluster/kuberntes/observability/kube-prometheus-stack/ks.yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: kube-prometheus-stack
  namespace: flux-system
spec:
  targetNamespace: observability
  commonMetadata:
    labels:
      app.kubernetes.io/name: kube-prometheus-stack
  dependsOn:
    - name: rook-ceph-cluster
  path: ./cluster/kubernetes/observability/kube-prometheus-stack/app
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
  wait: false
  interval: 30m
  retryInterval: 1m
  timeout: 15m
```

```yaml
# ./cluster/kuberntes/observability/grafana/ks.yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: grafana
  namespace: flux-system
spec:
  targetNamespace: observability
  commonMetadata:
    labels:
      app.kubernetes.io/name: grafana
  dependsOn:
    - name: kube-prometheus-stack
  path: ./cluster/kubernetes/observability/grafana/app
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
  wait: false
  interval: 30m
  retryInterval: 1m
  timeout: 15m
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: grafana-ingress
  namespace: flux-system
spec:
  targetNamespace: observability
  commonMetadata:
    labels:
      app.kubernetes.io/name: grafana-ingress
  dependsOn:
    - name: grafana
  path: ./cluster/kubernetes/observability/grafana/ingress
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
  wait: false
  interval: 30m
  retryInterval: 1m
  timeout: 5m
```
The last kustomization is the ingress resources for grafana.

### Helm charts
Next up are the helm charts. They're both quite long!

```yaml
# ./cluster/kuberntes/observability/kube-prometheus-stack/app/helmrelease.yaml
---
apiVersion: helm.toolkit.fluxcd.io/v2beta2
kind: HelmRelease
metadata:
  name: kube-prometheus-stack
spec:
  interval: 30m
  timeout: 15m
  chart:
    spec:
      chart: kube-prometheus-stack
      version: 57.0.3
      sourceRef:
        kind: HelmRepository
        name: prometheus-community
        namespace: flux-system
  install:
    crds: CreateReplace
    remediation:
      retries: 3
  upgrade:
    cleanupOnFail: true
    crds: CreateReplace
    remediation:
      strategy: rollback
      retries: 3
  values:
    crds:
      enabled: true
    cleanPrometheusOperatorObjectNames: true
    # grafana
    grafana:
      enabled: false
    # alertmanager
    alertmanager:
      enabled: true
      alertmanagerSpec:
        retention: 24h
        storage:
          volumeClaimTemplate:
            spec:
              storageClassName: ceph-block
              resources:
                requests:
                  storage: 1Gi
    # prometheus
    prometheus:
      enabled: true
      prometheusSpec:
        replicas: 1
        scrapeInterval: 1m # <- match to Grafana helm chart ??
        retention: 2d
        retentionsize: 18Gi
        podMonitorSelectorNilUsesHelmValues: false
        probeSelectorNilUsesHelmValues: false
        ruleSelectorNilUsesHelmValues: false
        serviceMonitorSelectorNilUsesHelmValues: false
        storageSpec:
          volumeClaimTemplate:
            spec:
              storageClassName: ceph-block
              resources:
                requests:
                  storage: 20Gi
    # kubelet
    kubelet:
      enabled: true
    # kubeApiServer
    kubeApiServer:
      enabled: true
    # coreDNS
    coreDns:
      enabled: true
    # kubeControllerManager
    kubeControllerManager:
      enabled: true
      endpoints: &controlplane
        - 10.10.30.2
        - 10.10.30.3
        - 10.10.30.4
    # kubeEtcd
    kubeEtcd:
      enabled: true
      endpoints: *controlplane
    # kubeScheduler
    kubeScheduler:
      enabled: true
      endpoints: *controlplane
    # kubeProxy
    kubeProxy:
      enabled: false
    # kubeStateMatrics
    kubeStateMetrics:
      enabled: true
    kube-state-metrics:
      fullnameOverride: kube-state-metrics
    # nodeExpoter
    nodeExporter:
      enabled: true
    prometheus-node-exporter:
      fullnameOverride: node-exporter
```
I've disabled `grafana` in this chart as I want to install it seperately. Otherwise I've added two PVC's so both Prometheus and Alertmanager can persists some data.
Another not-so-obvious setting is that I've disabled `kubeProxy`. This is trivial as I'm not runnig `kubeProxy`. `Cilium` does all the proxing in my cluster.

Most of the grafana chart is setting up dashboards, so they're loaded when it spins up. There are three important sections:
1) datasources
2) dataproviders
3) dashboards

I only have one data provider: Prometheus :100:
The one part I didn't know how to set before I actually deployed Prometheus was the URL to the service where grafana can get the data from. With my settings the service is called `kube-prometheus-stack-prometheus`. I set the URL to the FQDN for this service (port 9090).

The `dataproviders` took me a bit to figure out. It really silly in the end. All it does is to seperate the dashboards into groups. The dashboards in each group is then displayed together in grafana. I think this due to the fact you can setup many dataproviders from within grafana if you want to gather data from somewhere outside the cluster. In the end, each defined dashbaord must belong to a dataprovider. I ended settting up a few different ones.

Lastly, the dashboards. These are pretty self explanatory. A lot of people have created dashboards that one can just use. This is awesome, as this can be a real timesync to set up. All published dashboards can be found here: [Grafana Dashboards](https://grafana.com/grafana/dashboards). Each dashboard has a `id`, this is important.

I'm using some dashboards that aren't published on the grafana website. These can be loaded by pointing to the url where the dashboard json manifest is storaged.

```yaml
# ./cluster/kuberntes/observability/grafana/app/helmrelease.yaml
---
apiVersion: helm.toolkit.fluxcd.io/v2beta2
kind: HelmRelease
metadata:
  name: grafana
spec:
  interval: 30m
  chart:
    spec:
      chart: grafana
      version: 7.3.7
      sourceRef:
        kind: HelmRepository
        name: grafana
        namespace: flux-system
  install:
    remediation:
      retries: 3
  upgrade:
    cleanupOnFail: true
    remediation:
      strategy: rollback
      retries: 3
  dependsOn:
    - name: kube-prometheus-stack
      namespace: observability
  values:
    replicas: 1
    grafana.ini:
      analytics:
        check_for_updates: false
        check_for_plugin_updates: false
        reporting_enabled: false
      news:
        news_feed_enabled: false
    datasources:
      datasources.yaml:
        apiVersion: 1
        datasources:
        - name: Prometheus
          type: prometheus
          url: http://kube-prometheus-stack-prometheus.observability.svc.cluster.local:9090
          access: proxy
          isDefault: true
    dashboardProviders:
      dashboardproviders.yaml:
        apiVersion: 1
        providers:
          - name: default
            orgId: 1
            folder: ""
            type: file
            disableDeletion: false
            editable: true
            options:
              path: /var/lib/grafana/dashboards/default
          - name: kubernetes
            orgId: 1
            folder: Kubernetes
            type: file
            disableDeletion: false
            editable: true
            options:
              path: /var/lib/grafana/dashboards/kubernetes
          - name: ceph
            orgId: 1
            folder: Ceph
            type: file
            disableDeletion: false
            editable: true
            options:
              path: /var/lib/grafana/dashboards/ceph
          - name: cilium
            orgId: 1
            folder: Cilium
            type: file
            disableDeletion: false
            editable: true
            options:
              path: /var/lib/grafana/dashboards/cilium
          - name: cloudnative-pg
            orgId: 1
            folder: Cloudnative-pg
            type: file
            disableDeletion: false
            editable: true
            options:
              path: /var/lib/grafana/dashboards/cloudnative-pg
          - name: flux
            orgId: 1
            folder: Flux
            type: file
            disableDeletion: false
            editable: true
            options:
              path: /var/lib/grafana/dashboards/flux
    dashboards:
      default:
        node-exporter-full:
          gnetId: 1860
          revision: 36
          datasource: Prometheus
        cert-manager:
          url: https://raw.githubusercontent.com/monitoring-mixins/website/master/assets/cert-manager/dashboards/cert-manager.json
          datasource: Prometheus
      ceph:
        ceph-cluster:
          gnetId: 2842
          revision: 17
          datasource: Prometheus
        ceph-osd:
          gnetId: 5336
          revision: 9
          datasource: Prometheus
        ceph-pools:
          gnetId: 5342
          revision: 9
          datasource: Prometheus
      flux:
        flux-cluster:
          url: https://raw.githubusercontent.com/fluxcd/flux2-monitoring-example/main/monitoring/configs/dashboards/cluster.json
          datasource: Prometheus
        flux-control-plane:
          url: https://raw.githubusercontent.com/fluxcd/flux2-monitoring-example/main/monitoring/configs/dashboards/control-plane.json
          datasource: Prometheus
      kubernetes:
        kubernetes-api-server:
          gnetId: 15761
          revision: 16
          datasource: Prometheus
        kubernetes-coredns:
          gnetId: 15762
          revision: 17
          datasource: Prometheus
        kubernetes-global:
          gnetId: 15757
          revision: 37
          datasource: Prometheus
        kubernetes-namespaces:
          gnetId: 15758
          revision: 34
          datasource: Prometheus
        kubernetes-nodes:
          gnetId: 15759
          revision: 29
          datasource: Prometheus
        kubernetes-pods:
          gNetId: 15760
          revision: 21
          datasource: Prometheus
        kubernetes-volumes:
          gnetId: 11454
          revision: 14
          datasource: Prometheus
      cilium:
        cilium-operator:
          url: https://raw.githubusercontent.com/cilium/cilium/main/install/kubernetes/cilium/files/cilium-operator/dashboards/cilium-operator-dashboard.json
          datasource: Prometheus
        cilium-agent:
          url: https://raw.githubusercontent.com/cilium/cilium/main/install/kubernetes/cilium/files/cilium-agent/dashboards/cilium-dashboard.json
          datasource: Prometheus
        hubble:
          url: https://raw.githubusercontent.com/cilium/cilium/main/install/kubernetes/cilium/files/hubble/dashboards/hubble-dashboard.json
          datasource: Prometheus
        hubble-network-overview:
          url: https://raw.githubusercontent.com/cilium/cilium/main/install/kubernetes/cilium/files/hubble/dashboards/hubble-network-overview-namespace.json
          datasource: Prometheus
        hubble-l7-http:
          url: https://raw.githubusercontent.com/cilium/cilium/main/install/kubernetes/cilium/files/hubble/dashboards/hubble-l7-http-metrics-by-workload.json
          datasource: Prometheus
      cloudnative-pg:
        cloudnative-pg:
          gnetId: 20417
          revision: 1
          datasource: Prometheus
```

### Ingress
Lastly I need to setup ingress to grafana. For this I need to add a listener to the `internal` gateway.

```yaml
# ./cluster/kubernetes/network/ingress/internal/gateway.yaml
...
# catch traffic for the grafana dashboard
    - name: grafana
      hostname: grafana.local.cjsolsen.com
      protocol: HTTPS
      port: 443
      allowedRoutes:
        namespaces:
          from: Selector
          selector:
            matchLabels:
              internal-gateway-access: "true"
      tls:
        mode: Terminate
        certificateRefs:
          - name: grafana-cjsolsen-com
```

And add `httproute` to the `observability` namespace.

```yaml
# ./cluster/kuberntes/observability/grafana/ingress/grafana-http-route.yaml
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: grafana
  namespace: observability
spec:
  parentRefs:
    - name: internal-gateway
      namespace: network
      sectionName: grafana
  rules:
    - matches:
      - path:
          type: PathPrefix
          value: /
      backendRefs:
        - name: grafana
          port: 80
```

## Enabling metrics for Prometheus
I also need to eanble Prometheus on the services I already deployed so the metrics from these can be scraped.

### Cloudnative-pg
I need to change a single value in the helm chart.
```yaml
monitoring:
  podMonitorEnabled: true # <- change to true
```
There is also an option to deploy a dashboard for grafana. But I already have one, so I don't need that.

And then in each pg `cluster` definition I need to set another flag.

```yaml
# ./cluster/kubernetes/database/cloudnative-pg/clusters/gatus-cluster.yaml
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
  monitoring:
    enablePodMonitor: true # <- This one!
```

### Cilium
I need to add a bit of yaml to the helm chart values:

```yaml
# ./cluster/kubernetes/kube-system/cilium/app/helmrelease.yaml
prometheus:
  enabled: true
  serviceMonitor:
    enabled: true
operator:
  prometheus:
    enabled: true
    serviceMonitor:
      enabled: true
```