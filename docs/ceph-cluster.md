# Ceph

One can get some insights into the general health of the Ceph cluster through the normal kubernetes interface, like getting the cluster health:

```zsh
kubectl get cephcluster -n rook-ceph
```

Most of the time Rook will handle everything and health warnings will eventually be resolved. But something this is not the case. When this happens, likely after a crash of some kind, we have to interact with the Ceph cluster directly.
Luckily, Rook gives an easy way to do just that! We can interact with the Ceph cluster through the `Rook Ceph tools` pod. To find the pod name list all pods in the `rook-ceph` namespace:

```zsh
kubectl get po -n rook-ceph
```

Next `exec` into the pod:

```zsh
kubectl exec -n rook-ceph rook-ceph-tools-<serial> -it -- bash
```

From here we can execute `ceph commands`. We can get the current status

```zsh
ceph status
```

We can list all crashes

```zsh
ceph crash ls
```

Or list new crashes only

```zsh
ceph crash ls-new
```

To get more info on a specific crash

```zsh
ceph crash info <crashid>
```

And to archive a crash

```zsh
ceph crash archive <crashid>
```