# Home-ops
<p align="center">
  <img src="./docs/assets/talos.svg" alt="Talos Linux logo" width="150" height="150">
  <img src="./docs/assets/k8s.png" alt="Kubernetes logo" width="150" height="150">
</p>
<p align="center">
  <img src="https://img.shields.io/badge/Talos-v1.6.5-blue" alt="Talos version">
  <img src="https://img.shields.io/badge/Kubernetes-v1.29.2-blue" alt="Kubernetes version">
</p>

This repo hold all the manifests for my cluster. The cluster is based on Talos Linux and I'm using Fluxcd for GitOps.

### Directories

```sh
📁 .github              # Github related files
📁 docs                 # My running documentation
📁 network              # My internal network setup 
📁 cluster
├─📁 kubernetes         # Kubernetes cluster definitions
└─📁 talos              # Talos configuration stuff
```