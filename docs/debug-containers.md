# Kubernetes & Talos debug containers
Debug containers can be a very useful tool when trying to troubleshoot an issue with a pod or the cluster itself.

There are a some considerations to consider when working with debug containers:
1) For k8s debug containers it's generally better to make a copy of the pod you are trying to debug and then attach a debug container the cloned pod. This way you leave the "real" pod without added extra running containers attached to the pod. After the debugging is done, you can simply delete the cloned pod - very clean.
2) For debugging the host machines I prefer using talos debug containers, not the same can't be done via `k8s node` debug containrs. But it feels better to use a talos tool for a talos issue.

## Talos debug containers
It's very easy to attach a debug container via the talos api.
```sh
talosctl -n <IP> debug docker.io/library/alpine:latest --args /bin/sh
```
This will create a debug container and attach to the specified node. You can now access the host file system via the path `/host`. SSH is not needed!;)
You can of course use a different container image if you want.

## Kubernetes debug containers
As I'm running `k8tz` to automatically update timezone information for all created containers, a little extra care is needed when creating cloned pods for debugging. `k8tz` will inject a initcontainer in all newly created pods, unless the pod is already annotated by `k8tz`. It's therefore crusial to keep annotations from the original pod when creating clone pods for debugging.

```sh
k -n <ns> debug -it <pod> --image=busybox --share-processes --copy-to=<clonePodName> --keep-annotations
```

The `--copy-to` flag specifies that we want to clone the pod and attach to the clone. If the `--keep-annotations` flag is omitted, `k8tz` thinks this is a fresh pod that it needs to inject an initcontainer into. The problem is that the clone pod already have this initcontainer and the manifest will therefore fail because two initcontainers now share the same name. Passing `--keep-initcontainers=false` doesn't fix the issue. I'm not completely sure why, but some of the original initcontainer yaml must still be around even with this flag.

Again, one can use another image.