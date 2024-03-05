# Ingress
I'm using the relatively new Gateway API which is meant to be the new standard Ingress API in Kubernetes. In the future the Gateway API will also support Service Mesh (east-west routing). Cilium has implimented the Gateway API, which is also one of the reasons I choose to use Cilium.

## Structure
The Gatewey API defines a few objects:
1) GatewayClass
2) Gateway
3) Route

The GatewayClass is supplied by Cilium for me. In general this obejct is supplied by whoever set up the cluster, e.g. the cloud provider. Cilium provides a GatewayClass called `cilium`.

The Gateway object sets up listeners that match incomming traffic and this is the object that would get an external ip address. Based on rules, traffic is relayed onto Routes.

There are a few different types of routes. The most common one being the `HTTPRoute`, which I'll (almost) exclusively use.

## Setup
I'll define two Gateways:
1) Internal
2) External

The names are fairly self explanatory. The internal Gateway will handle all local traffic, i.e. anything that matches `*.local.cjsolsen.com`. These services are not exposed outside my network and the DNS names will not resolve "out in the wild".
The external Gateway will only handle external traffic comming into my network. I'm runnig two public facing static websites, which for now is the only traffic this Gateway will handle.

I like having exact TLS/SSL certs (not wildcard), which means I'll have to define a `listener` for each service, instead of having a "catch all" listener and splittig the traffic with routes. So be it!

### Internal Gateway
The following manifest defines the internal Gateway:

```yaml
# ./cluster/kubernetes/network/ingress/internal/gateway.yaml
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: internal-gateway
  namespace: network
  annotations:
    cert-manager.io/issuer: letsencrypt-production
spec:
  gatewayClassName: cilium
  addresses:
    - value: 10.10.30.80
  listeners:
    # catch all local http -> https
    - name: http-redirect
      hostname: "*.local.cjsolsen.com"
      protocol: HTTP
      port: 80
      allowedRoutes:
        namespaces:
          from: Same
    # catch traffic for pihole dashboard
    - name: pihole-dashboard
      hostname: pihole.local.cjsolsen.com
      protocol: HTTPS
      port: 443
      allowedRoutes:
        namespaces:
          from: Same
      tls:
        mode: Terminate
        certificateRefs:
          - name: pihole-cjsolsen-com
            kind: Secret
            group: core
    # more https listeners ...
```
The `tls` section has to conform to the requirements set out by [cert-manager](./cert-manager.md#getting-certificates).

The first listener is a `http` "catch all" that will catch any local http traffic and forward it to a `HTTPRoute` that'll redirect it to `https`.

```yaml
# ./cluster/kubernetes/network/ingress/internal/http-redirect.yaml
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: http-https-redirect
  namespace: network
spec:
  parentRefs:
  - name: internal-gateway
    sectionName: http-redirect
  rules:
  - filters:
    - type: RequestRedirect
      requestRedirect:
        scheme: https
        statusCode: 301
```
The `parentRefs` determins which gateway the route is attached to and the `sectionName` defines the listener.
This route sends back a redirect request and status code 301, which will force the request to be retransmitted to the standard https port (443).

From here, all listeners below the http redirect listener, will catch traffic bound for specific services/applications.

The `HTTPRoute` for `pihole` is defined as follows:

```yaml
# ./cluster/kubernetes/network/ingress/internal/pihole-hhtp-route.yaml
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: pihole-dashboard
  namespace: network
spec:
  parentRefs:
    - name: internal-gateway
      sectionName: pihole-dashboard
  rules:
    - matches:
      - path:
        type: PathPrefix
        value: /
      filters:
        - type: RequestRedirect
          requestRedirect:
            path:
              type: ReplaceFullPath
              replaceFullPath: /admin
            statusCode: 302
      backendRefs:
        - name: svc-53-udp-dns
          port: 53
```

This route matches any path prefix and redirects it to `/admin`, which is the dashbord URL. The `backendRefs` define which service to route the traffic to.