# Destroy the Talos/Kuberntes cluster
The cluster can be destroyed via the Talos API.

Run `talosctl reset -n <IP.of.node> --glacefull=false --wipe-mode all` on a node.
This should completely reset the node, wipe all disks and shutdown the node.

After this remove it from the Kuberntes cluster.
Run `kubectl delete node <name>`

Do the same for the rest of the nodes. The last node can't be removed from the Kubernetes cluster, but that doesn't matter!