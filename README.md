<div align="center">
  <img src="./docs/assets/talos.svg" alt="Talos Linux logo" width="150" height="150">
  <img src="./docs/assets/k8s.png" alt="Kubernetes logo" width="150" height="150">
</div>

<div align=center>

### My Home-ops Repository :zap:

_... powered by Talos Linux and Kubernetes_

</div>

<div align="center">
  <img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.cjsolsen.com%2Fquery%3Fformat%3Dendpoint%26metric%3Dtalos_version&style=for-the-badge&logo=talos&logoColor=fff&label=Talos&labelColor=302d41&color=cba6f7" alt="Talos version">
  <img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.cjsolsen.com%2Fquery%3Fformat%3Dendpoint%26metric%3Dkubernetes_version&style=for-the-badge&logo=kubernetes&logoColor=fff&label=Kubernetes&labelColor=302d41&color=cba6f7" alt="Kubernetes version">
  <img src="https://img.shields.io/badge/Fluxcd-v2.2.3-cba6f7?logo=flux&logoColor=fff&style=for-the-badge&labelColor=302D41" alt="Fluxcd version">
  <img src="https://img.shields.io/github/issues-pr/chrede88/home-ops?logo=github&color=f2cdcd&logoColor=fff&style=for-the-badge&labelColor=302d41" alt="Open Pull Requests">
</div>

<div align="center">
  <img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.cjsolsen.com%2Fquery%3Fformat%3Dendpoint%26metric%3Dcluster_uptime_days&style=for-the-badge&label=Up&labelColor=302d41" alt="Cluster Up Time">
  <img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.cjsolsen.com%2Fquery%3Fformat%3Dendpoint%26metric%3Dcluster_node_count&style=for-the-badge&label=Nodes&labelColor=302d41" alt="Cluster Nodes">
  <img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.cjsolsen.com%2Fquery%3Fformat%3Dendpoint%26metric%3Dcluster_pod_count&style=for-the-badge&label=Pods&labelColor=302d41" alt="Cluster Pods">
  <img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.cjsolsen.com%2Fquery%3Fformat%3Dendpoint%26metric%3Dcluster_cpu_usage&style=for-the-badge&label=Cpu&labelColor=302d41" alt="Cluster CPU">
  <img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.cjsolsen.com%2Fquery%3Fformat%3Dendpoint%26metric%3Dcluster_memory_usage&style=for-the-badge&label=Memory&labelColor=302d41" alt="Cluster Memory">
  <img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.cjsolsen.com%2Fquery%3Fformat%3Dendpoint%26metric%3Dceph_health_status&style=for-the-badge&logo=ceph&label=Ceph&labelColor=302d41" alt="Ceph Cluster Health">
</div>

---

This repo hold all the manifests for my kubernetes cluster and acts as the source of truth. I use Flux to keep my cluster state up-to-date with this repo. I also use Renovate to automatically open PR's when new versions of the applications I have in my cluster becomes avaliable.

### Docs

I keep running docs where I try to document my journey. Hopefully others will find them helpful.

### Directories

The layout of the repo is as follows:

```sh
📁 .github              # Github related files
📁 docs                 # My running documentation
📁 network              # My internal network setup 
📁 cluster
├─📁 kubernetes         # Kubernetes cluster definitions
└─📁 talos              # Talos configuration stuff
```