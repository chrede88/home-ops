## Kubernetes

My kubernetes manifests are organized into two main folders:
1) apps
2) flux

The `apps` folder contains all the actual manifests for all the different apps I'm running in my cluster. The subfolder structure is organized per namespace. I try to organize apps into namespaces that makes sense. While some namespaces only have a single deployment, e.g. `rook-ceph` or `cert-manager`. Most namespaces group similar apps.

The `flux` folder contains three folders. The `main` folder contains the top level flux kustomizations that point to the manifests in `apps` and to the `resources` folder where I keep my oci resources. The `components` folder contains manifests that are deployed in more than one namespace. Keeping them here lets me define them only once and reference them where I need them.