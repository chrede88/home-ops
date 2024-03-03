# Pihole
I'll be using Pihole for my network DNS. In order to not loose DNS if the cluster goes down, I plan to run a backup pihole server on a seperate RPi. To keep all the pihole servers in sync, I'll deploy OrbitalSync to sync all to be master configuration.

For now, I'll focus on getting it up and runnig in the cluster first.

## Install
I'll install pihole using standard yaml manifests, as there are not an offiical Helm chart. I'll install pihole using a statefulset, rather than a normal deployment. Using a statefulset means the pods will have fixed names, which I need for OrbitalSync to work.

### Flux resources
I'll first define the Flux resources I need.

First pihole itself:

```yaml
# ./cluster/kuberntes/network/pihole/ks.yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: pihole
  namespace: flux-system
spec:
  targetNamespace: network
  commonMetadata:
    labels:
      app.kubernetes.io/name: pihole
  dependsOn:
    - name: rock-ceph-cluster
  path: ./cluster/kubernetes/netwotk/pihole/app
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

And OrbitalSync next:

```yaml
# ./cluster/kuberntes/network/orbitalsync/ks.yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: orbitalsync
  namespace: flux-system
spec:
  targetNamespace: network
  commonMetadata:
    labels:
      app.kubernetes.io/name: orbitalsync
  dependsOn:
    - name: pihole
  path: ./cluster/kubernetes/netwotk/orbitalsync/app
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

### Pihole

Here are the yaml manifests for pihole itself:

```yaml
# ./cluster/kuberntes/network/pihole/app/statefulset-pihole.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: pihole
  namespace: network
spec:
  selector:
    matchLabels:
      app: pihole
  serviceName: pihole
  replicas: 3
  template:
    metadata:
      labels:
        app: pihole
    spec:
      containers:
        - name: pihole
          image: pihole/pihole:2024.02.2
          envFrom:
            - configMapRef:
                name: pihole-configmap
            - secretRef:
                name: pihole-password
          ports:
            - name: svc-80-tcp-web
              containerPort: 80
              protocol: TCP
            - name: svc-53-udp-dns
              containerPort: 53
              protocol: UDP
            - name: svc-53-tcp-dns
              containerPort: 53
              protocol: TCP
          livenessProbe:
            httpGet:
              port: svc-80-tcp-web
            initialDelaySeconds: 60
            periodSeconds: 10
          readinessProbe:
            httpGet:
              port: svc-80-tcp-web
            initialDelaySeconds: 60
            periodSeconds: 10
            failureThreshold: 10
          volumeMounts:
            - name: pihole-etc-pihole
              mountPath: /etc/pihole
            - name: pihole-etc-dnsmasq
              mountPath: /etc/dnsmasq.d
  volumeClaimTemplates:
    - metadata:
        name: pihole-etc-pihole
        namespace: network
      spec:
        storageClassName: ceph-block
        volumeMode: Filesystem
        accessModes:
          - "ReadWriteOnce"
        resources:
          requests:
            storage: 3Gi
    - metadata:
        name: pihole-etc-dnsmasq
        namespace: network
      spec:
        storageClassName: ceph-block
        volumeMode: Filesystem
        accessModes:
          - "ReadWriteOnce"
        resources:
          requests:
            storage: 3Gi
```

Next the configmap for pihole:

```yaml
# ./cluster/kuberntes/network/pihole/app/configmap-pihole.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: pihole-configmap
  namespace: network
data:
  TZ: "Europe/Zurich"
  PIHOLE_DNS_: "1.1.1.1;1.0.0.1" # cloudflare and cloudflare backup
```

Next I'll need three types services:
1) A DNS service.
2) A service that OrbitalSync can connect to.
3) Some services for the pihole dashboards.

```yaml
# ./cluster/kuberntes/network/pihole/app/dns-service.yaml
---
kind: Service
apiVersion: v1
metadata:
  name: pihole-dns-udp-svc
  namespace: network
  annotations:
    "io.cilium/lb-ipam-ips": "10.10.0.70"
    "io.cilium/lb-ipam-sharing-key": "pihole-dns-key"
spec:
  selector:
    app: pihole
  type: LoadBalancer
  loadBalancerClass: io.cilium/l2-announcer
  ports:
    - name: svc-53-udp-dns
      port: 53
      targetPort: 53
      protocol: UDP
---
kind: Service
apiVersion: v1
metadata:
  name: pihole-dns-tcp-svc
  namespace: pihole
  annotations:
    "io.cilium/lb-ipam-sharing-key": "pihole-dns-key"
spec:
  selector:
    app: pihole
  type: LoadBalancer
  loadBalancerClass: io.cilium/l2-announcer
  ports:
    - name: svc-53-tcp-dns
      port: 53
      targetPort: 53
      protocol: TCP
```

Here I'm using annotations to request a specefic IP: `"io.cilium/lb-ipam-ips"`.
Because pihole should respond to both UDP and TCP request on port 53, I need to tell Cilium that the two services should have to same IP. This is done using another annotation: `"io.cilium/lb-ipam-sharing-key": "pihole-dns-key"`. If both services have the same key, they'll get the same IP.

```yaml
# ./cluster/kuberntes/network/pihole/app/headless-service.yaml
---
apiVersion: v1
kind: Service
metadata:
  name: pihole
  namespace: network
  labels:
    app: pihole
spec:
  clusterIP: None
  selector:
    app: pihole
```

```yaml
# ./cluster/kuberntes/network/pihole/app/dashboard-service.yaml
---
kind: Service
apiVersion: v1
metadata:
  name: pihole0-web-svc
  namespace: netowrk
spec:
  selector:
    app: pihole
    statefulset.kubernetes.io/pod-name: pihole-0 # main pihole
  type: ClusterIP
  ports:
    - name: svc-80-tcp-web
      port: 80
      targetPort: 80
      protocol: TCP
---
kind: Service
apiVersion: v1
metadata:
  name: pihole1-web-svc
  namespace: netowrk
spec:
  selector:
    app: pihole
    statefulset.kubernetes.io/pod-name: pihole-1 # 2nd pihole
  type: ClusterIP
  ports:
    - name: svc-80-tcp-web
      port: 80
      targetPort: 80
      protocol: TCP
---
kind: Service
apiVersion: v1
metadata:
  name: pihole2-web-svc
  namespace: netowrk
spec:
  selector:
    app: pihole
    statefulset.kubernetes.io/pod-name: pihole-2 # main pihole
  type: ClusterIP
  ports:
    - name: svc-80-tcp-web
      port: 80
      targetPort: 80
      protocol: TCP
```
I'll need to point Ingress to these three services, in order to expose the dashboards.

Lastly, I'll need to define a secret containing the dashboard login password. Both so I can login, but also so OrbitalSync can.

### OrbitalSync

The deployment of OrbitalSync is much easier. I'll only need two yaml manifests.

First the deployment:

```yaml
# ./cluster/kuberntes/network/orbitalsync/app/deployment-orbitalsync.yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: orbital-sync
  namespace: network
spec:
  selector:
    matchLabels:
      app: orbital-sync
  template:
    metadata:
      labels:
        app: orbital-sync
    spec:
      containers:
      - name: orbital-sync
        image: mattwebbio/orbital-sync:1.5.7
        envFrom:
          - configMapRef:
              name: orbital-sync-config
        env:
          - name: TZ
            value: Europe/Zurich
          - name: "PRIMARY_HOST_PASSWORD"
            valueFrom:
              secretKeyRef:
                name: pihole-password
                key: WEBPASSWORD
          - name: "SECONDARY_HOST_1_PASSWORD"
            valueFrom:
              secretKeyRef:
                name: pihole-password
                key: WEBPASSWORD
          - name: "SECONDARY_HOST_2_PASSWORD"
            valueFrom:
              secretKeyRef:
                name: pihole-password
                key: WEBPASSWORD
```

And the configmap:

```yaml
# ./cluster/kuberntes/network/orbitalsync/app/configmap-orbitalsync.yaml
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: orbital-sync-config
  namespace: network
data:
  PRIMARY_HOST_BASE_URL: "http://pihole-0.pihole.pihole.svc.cluster.local"
  SECONDARY_HOST_1_BASE_URL: "http://pihole-1.pihole.pihole.svc.cluster.local"
  SECONDARY_HOST_2_BASE_URL: "http://pihole-2.pihole.pihole.svc.cluster.local"
  INTERVAL_MINUTES: "30"
```

It should be trivial to add the external backup Pihole once it get it up. I will just add `SECONDARY_HOST_3_BASE_URL: http://ip-address-of-pihole` to the configmap. And another entry in the `spec.env` field in the deployment.