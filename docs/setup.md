# Setting up

## Local dev machine
The first thing to do before starting the install of Talos Linux and Kubernetes is to make sure my local dev machine has all the components needed installed. I'm using a Macbook Pro, so I'll use `brew` where I can.
The two main components I need are a commandline interface and a text editor. I use [Alacritty](https://alacritty.org) and [VS Code](https://code.visualstudio.com). In order to talk to Talos and Kubernetes I need to install the two binearies.

### talosctl
```zsh
curl -sL https://talos.dev/install | sh
```

After the bineary is installed, check that it works.

```zsh
talosctl --help
```

### kubectl
```zsh
brew install kubectl
```

Check that all is good.

```zsh
kubectl version --client
```

### Helm

I'm planing on using [Cilium](https://cilium.io) for cluster networking and also replacing Kube-proxy. This mean I'll have to supply a helm manifest to Talos so it can install Cilium on boot. Therefore I'll need Helm and Helmfile.

```zsh
brew install helm
```

### Helmfile

I need Helmfile for the initial setup of Cilium.

```zsh
brew install helmfile
```

### fluxcd
I'm plaing on using [Fluxcd](https://fluxcd.io) so I might as well set this up now.

```zsh
brew install fluxcd/tap/flux
```

and check that all is good.

```zsh
flux --version
```

## Talos configuration
The Talos configuration files can be setup using talosctl. I'm pretty sure all the generated configuration files should not be made public unless you encrypt the sensitive parts. I'll use SOPS with age, but if not then remember to add the config files to `.gitignore`.

### What not to do!
I used `inlineManifests` to install Cilium on boot. This worked nicely, but because all the resources now don't have the correct helm labels Flux can't gracefully take over when Flux bootstraps.
The best way to do install Cilium seems to be to wait for the cluster install to hang because of the missing CNI and then install Cilium manually with Helm.

### Second try

First generate the cluster secrets:

```zsh
talosctl gen secrets -o secrets.yaml
```

Next I'll generate the configuration files using the freshly created secrets. The default configuration needs to be tweaked, this can be done using patches. I'll need seven patches:

As I only have three nodes I need to be schedule workloads on the control-plane nodes.
```yaml
# allow-workloads-controlplane.yaml
cluster:
  allowSchedulingOnControlPlanes: true
```

All other patches depends on the network interface and install disk names. After Talos boots up into memory, it waits for a machine configuration before finishing the install. During this time I can ask Talos to provide me with the disk and network interface names for each node. First the install disk:

```zsh
talosctl disks -n 10.10.30.x --insecure
```
I need the `--insecure` flag because Talos is not fully installed.

The install disk I want to use (500GB SATA SSD) is called `/dev/sda`.

As for the network interface, Talos uses `predictable interface names` which means the network interface may be called something stupid. I want to disable this.

```yaml
# interface-names.yaml
machine:
  install:
    extraKernelArgs:
      - net.ifnames=0
```
This should mean that the NICs on my machines are all called `eth0`.

Using this information I can setup the remaining patches:

I want to use dhcp, as I've already setup three static IP leases.
```yaml
# dhcp.yaml
machine:
  network:
    interfaces:
      - interface: eth0
        dhcp: true
```

Talos can instruct Kubernetes to setup a VIP (virtual IP) between the control-plane nodes, so I don't have to use an external loadbalancer.
```yaml
# vip.yaml
machine:
  network:
    interfaces:
      - interface: eth0
        vip:
          ip: 10.10.30.30
```

I'll set the install disk and ask Talos to wipe it before installing.

```yaml
# install-disk.yaml
machine:
  install:
    disk: /dev/sda
    wipe: true
```

Disable CNI, I'll manually install Cilium at the right time. Cilium also needs to run the proxy, so I'll also disable `Kube-proxy`.

```yaml
# disable-cni-proxy.yaml
cluster:
  network:
    cni:
      name: none
  proxy:
    disabled: true
```

We can now generate the configuration files using the seven patches. I'm using names from the old Nordic mythology, so I'll call my cluster Asgard.

```zsh
talosctl gen config asgard https://10.10.30.30:6443 \
--with-secrets secrets.yaml \
--kubernetes-version 1.29.2 \
--config-patch @patches/dhcp.yaml \
--config-patch @patches/install-disk.yaml \
--config-patch @patches/allow-workloads-controlplane.yaml \
--config-patch @patches/interface-names.yaml \
--config-patch-control-plane @patches/vip.yaml \
--config-patch-control-plane @patches/disable-cni-proxy.yaml
```
One could ask why I'm seperating out the `dhcp` and `vip` patches, since all my nodes are control-plane it shouldn't make a difference. I do that simply because it then makes it easier to setup an additional worker node later if needed.

The configuration files have now been generated😄🎉
Three files have been generated:
- controlplane.yaml
- worker.yaml
- talosconfig

I'll only need the `controlplane.yaml` as I don't have any worker nodes. I'll come back to the `talosconfig` later.

We need to add one more patch! Each node need a hostname. We can create 3 new controlplane configs, one for each node using the following command:

```zsh
talosctl machineconfig patch controlplane.yaml --patch @patches/odin-hostname.yaml -o controlplane-odin.yaml
```

where the patch is:

```yaml
# odin-hostname.yaml
machine:
  network:
    hostname: odin
```

The other two nodes should get a similar patch, with another hostname. I'll use `thor` and `baldr`.

It's time to add the configuration to the nodes, one at a time.

```zsh
talosctl apply-config -f controlplane-odin.yaml -n 10.10.30.2 --insecure
talosctl apply-config -f controlplane-thor.yaml -n 10.10.30.3 --insecure
talosctl apply-config -f controlplane-baldr.yaml -n 10.10.30.4 --insecure
```
This should be last time I need to use the `--insecure` flag.

To setup the talosconfig I need to change the endpoint. It's currently set to localhost.

```zsh
talosctl --talosconfig=talosconfig \
config endpoint 10.10.30.2 10.10.30.3 10.10.30.4
```

Once that is done, merge it into the default config stored at `~/.talos/config`.

```zsh
talosctl config merge talosconfig
```

## Kubernetes Bootstrap
It is now time to bootstrap Kubernetes 👍

This is super simple with Talos:

```zsh
talosctl bootstrap -n 10.10.30.2
```
Only send this command to **one** node. After a bit the `kubeconfig` file can be retreived.

```zsh
talosctl kubeconfig -n 10.10.30.2
```

The install will hang because of the missing CNI. This is the point where I'll install Cilium using Helm. See the [Talos docs](https://www.talos.dev/v1.6/kubernetes-guides/network/deploying-cilium/#method-1-helm-install) for more info.

I'll use `Helmfile` to install Cilium. This way I can provide one values file for both the initial install as well as to flux when bootstrapping the my cluster.

This is the helmfile I'll use:

```yaml
# helmfile.yaml
repositories:
  - name: cilium
    url: https://helm.cilium.io

releases:
  - name: cilium
    namespace: kube-system
    chart: cilium/cilium
    version: 1.15.1
    values: ["../../kubernetes/kube-system/cilium/app/helm-values.yaml"]
    wait: true
```

When it's time to install Cilium, I'll execute:

```zsh
helmfile apply
```

The boot process should now finish!🎉
