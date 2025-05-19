<div align="center">
  <img src="./docs/assets/talos.svg" alt="Talos Linux logo" width="150" height="150">
  <img src="./docs/assets/k8s.png" alt="Kubernetes logo" width="150" height="150">
</div>

<div align=center>

### My Home-ops Repository <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/26a1/512.gif" alt="⚡" width="16" height="16">

_... powered by Talos Linux and Kubernetes + bla bla_

</div>

<div align="center">
  <img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.cjsolsen.com%2Ftalos_version&style=for-the-badge&logo=talos&logoColor=fff&label=Talos&labelColor=302d41&color=cba6f7" alt="Talos version">
  <img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.cjsolsen.com%2Fkubernetes_version&style=for-the-badge&logo=kubernetes&logoColor=fff&label=Kubernetes&labelColor=302d41&color=cba6f7" alt="Kubernetes version">
  <img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.cjsolsen.com%2Fflux_version&style=for-the-badge&logo=flux&logoColor=fff&label=Fluxcd&labelColor=302d41&color=cba6f7" alt="Fluxcd version">
  <img src="https://img.shields.io/github/issues-pr/chrede88/home-ops?logo=github&color=f2cdcd&logoColor=fff&style=for-the-badge&labelColor=302d41" alt="Open Pull Requests">
</div>

<div align="center">
  <img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.cjsolsen.com%2Fcluster_age_days&style=for-the-badge&label=Age&labelColor=302d41" alt="Cluster Age">
  <img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.cjsolsen.com%2Fcluster_uptime_days&style=for-the-badge&label=Up&labelColor=302d41" alt="Cluster Up Time">
  <img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.cjsolsen.com%2Fcluster_node_count&style=for-the-badge&label=Nodes&labelColor=302d41" alt="Cluster Nodes">
  <img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.cjsolsen.com%2Fcluster_pod_count&style=for-the-badge&label=Pods&labelColor=302d41" alt="Cluster Pods">
  <img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.cjsolsen.com%2Fcluster_cpu_usage&style=for-the-badge&label=Cpu&labelColor=302d41" alt="Cluster CPU">
  <img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.cjsolsen.com%2Fcluster_memory_usage&style=for-the-badge&label=Memory&labelColor=302d41" alt="Cluster Memory">
  <img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.cjsolsen.com%2Fceph_health_status&style=for-the-badge&logo=ceph&label=Ceph&labelColor=302d41" alt="Ceph Cluster Health">
</div>

---

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f680/512.gif" alt="🚀" width="20" height="20"> Introduction

This repository holds all information about my homelab and kubernetes cluster. I'm doing my best to adhere to the principles of infrastructure as code (IaC) and GitOps.

---

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f340/512.gif" alt="🍀" width="20" height="20"> Kubernetes

My Kubernetes cluster is deployed with [Talos Linux](https://www.talos.dev), a Linux distribution build spefically for running Kubernetes. I run a three bare-metal node cluster on Intel 12th gen NUC's and using [Rook](https://github.com/rock/rock) for cluster persistence block, object, and file storage.

### GitOps

[Flux](https://github.com/fluxcd/flux2) watches the cluster resources in the [kubernetes](./cluster/kubernetes/) folder (see [Directories](#directories)) and makes changes to the cluster based on the state of the Git repository.

Flux is pointed at the two top level Flux kustomizations ([ks.yaml](./cluster/kubernetes/flux/main/ks.yaml)) which points at the [kubernetes/apps](./cluster/kubernetes/apps) folder and some other general common components. Flux will recursively search the `kubernetes/apps` folder until it finds the most top level `kustomization.yaml` per directory and then apply all the resources listed in it. That aforementioned `kustomization.yaml` will generally only define a few resource and one or many Flux kustomizations. Those Flux kustomizations will control the deployment of the actual resources related to each application.

[Renovate](https://github.com/renovatebot/renovate) watches my **entire** repository looking for dependency updates, when they are found a PR is automatically created. When PRs are merged Flux applies the changes to my cluster.

### Directories

The layout of the repository is as follows:

```sh
📁 .github              # Github related files
📁 docs                 # My running documentation
📁 network              # My internal network setup
📁 cluster
├── 📁 kubernetes       # Kubernetes cluster definitions
│   ├── 📁 apps         # application manifests
│   └── 📁 flux         # flux system configuration
└── 📁 talos            # Talos configuration stuff
```

### Docs

I keep running [docs](./docs/README.md) where I try to document my journey. Hopefully others will find them helpful.

---

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/2699_fe0f/512.gif" alt="⚙" width="20" height="20"> Hardware

| Device                | Num | OS Disk Size   | Data Disk Size | Ram  | OS                  | Function       |
| --------------------- | --- | -------------- | -------------- | ---- | ------------------- | -------------- |
| Intel NUC 12th i5     | 3   | 500GB SATA SSD | 2TB NVMe SSD   | 64GB | Talos               | Kubernetes     |
| Rasberry Pi 4         | 1   | 64GB SD card   | -              | 4GB  | Debian GNU/Linux 12 |  |
| Unifi Gateway Fiber     | 1   | -              | -              | -    | -                   | Router         |
| Unifi Cloudkey Gen 2+ | 1   | -              | -              | -    | -                   | Unifi OS       |
| Unifi Switch Flex 2.5G 8 PoE    | 1   | -              | -              | -    | -                   | PoE 2.5Gb Switch |
| Unifi U6+ AP          | 1   | -              | -              | -    | -                   | Wifi           |

---

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f64f/512.gif" alt="🙏" width="20" height="20"> Thanks

Thanks to all the people who donate their time to the [Home Operations](https://discord.gg/home-operations) Discord community. Be sure to check out [kubesearch.dev](https://kubesearch.dev/) for ideas on how to deploy applications or get ideas on what you could deploy.