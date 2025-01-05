# Updating Cluster
Both Talos Linux and Kubernetes can be updated using the Talos CLI tool. This process is very simple and easy to do.

## Talos Linux
Because I'm running Ceph extra care needs to be taken to make sure the Ceph cluster stays healthy between node upgrades.
Before starting the upgrade check that the Ceph cluster is healthy:

```zsh
kubectl get cephclusters -n rook-ceph
```

If the Ceph cluster is healthy, we can procide to upgrading the first node.

```zsh
talosctl upgrade -n 10.10.30.2 -i ghcr.io/siderolabs/installer:vX.Y.Z
```

If you're using an image from the [Talos Image Factory](https://factory.talos.dev), then you should absolutely **not** use the standatd image when upgrading! The upgrade image url looks somerthing like this: `factory.talos.dev/installer/<longSerialNum>:vX.Y.Z`

Before moving on to the next node, make sure the Ceph cluster is back in a healthy state. Run this right after starting the node upgrade:

```zsh
kubectl -n rook-ceph wait --timeout=1800s --for=jsonpath='{.status.ceph.health}=HEALTH_OK' cephclusters rook-ceph
```

This command won't retrun until the Ceph cluster status changes back to `HEALTH_OK`. At this point it's okay to move forward with the update and start updating the next node. Again, wait until the Ceph cluster is back in a healthy state.

### SystemExtensions & KernelArgs
I'm currently including the following systemextensions:
- siderolabs/i915
- siderolabs/intel-ice-firmware
- siderolabs/intel-ucode
- siderolabs/mei
- siderolabs/thunderbolt
- siderolabs/util-linux-tools

And the following kernel args:
- intel_iommu=on
- iommu=pt
- mitigations=off
- net.ifnames=0

Current image schematic ID: factory.talos.dev/installer/30cf8203c9e4a8011a752c34a3ffb1b183cf65510c8ff98cc0c08fd16380e4b3:v1.9.1

## Kubernetes
Upgrading Kubernetes is very easy with Talos Linux. The talosctl cli has an uatomated upgrade command build-in.
If you have just upgraded Talos Linux, make sure the Ceph cluster is in a good state before upgrading Kubernetes.

Let's first take a snapshot of the `etcd` database, just in case something goes horribly wrong.

```zsh
talosctl -n 10.10.30.2 etcd snapshot etcd-yyyymmdd.backup
```

Now I'm ready to run the upgrade!

```zsh
talosctl -n 10.10.30.2 upgrade-k8s --to X.Y.Z
```

You can check what will be upgrades by passing the flag `--dry-run`.
