<div align="center">
  <img src="./docs/assets/talos.svg" alt="Talos Linux logo" width="150" height="150">
  <img src="./docs/assets/k8s.png" alt="Kubernetes logo" width="150" height="150">
</div>

<div align=center>

### My Home-ops Repository :zap:

_... powered by Talos Linux and Kubernetes_

</div>

<div align="center">
  <img src="https://img.shields.io/badge/Talos-v1.6.7-C9CBFF?logo=talos&logoColor=fff&style=for-the-badge&labelColor=302D41" alt="Talos version">
  <img src="https://img.shields.io/badge/Kubernetes-v1.29.3-B5E8E0?logo=kubernetes&logoColor=fff&style=for-the-badge&labelColor=302D41" alt="Kubernetes version">
  <img src="https://img.shields.io/badge/Fluxcd-v2.2.3-DDB6F2?logo=flux&logoColor=fff&style=for-the-badge&labelColor=302D41" alt="Fluxcd version">
  <img src="https://img.shields.io/github/issues-pr/chrede88/home-ops?logo=github&color=F2CDCD&logoColor=fff&style=for-the-badge&labelColor=302D41" alt="Open Pull Requests">
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