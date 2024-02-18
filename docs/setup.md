# Setting up

## Local dev machine
The first thing to do before starting the install of Talos Linux and Kubernetes is to make sure my local dev machine has all the components needed installed. I'm using a Macbook Pro, so I'll use `brew` where I can.
The two main components I need are a commandline interface and a text editor. I use [Warp](https://www.warp.dev) and [VS Code](https://code.visualstudio.com). In order to talk to Talos and Kubernetes I need to install the two binearies.

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

### fluxcd
I'm plaing on using fluxcd so I might as well set this up now.

```zsh
brew install fluxcd/tap/flux
```

and check that all is good.

```zsh
flux --version
```

## Talos configuration
The Talos configuration files can be setup using talosctl. I'm pretty sure all the generated configuration files should not be made public, so I will remember to add the config files to my `.gitignore`.

First generate the cluster secrets:

```zsh
talosctl gen secrets -o secrets.yaml
```

Next I'll generate the configuration files using the freshly created secrets. The default configuration needs to be tweaked a bit, this can be done using patches. I'll need four patches:

As I only have three nodes I need to be schedule workloads on the control-plane nodes.
```yaml
# allow-workloads-controlplane.yaml
cluster:
  allowSchedulingOnControlPlanes: true
```

All other patches depends on the network interface and install disk names. I can ask talosctl to provide me with this info for each node. First the the network interface. We need to pass the `--insucure` flag because we haven't actually installed anything yet.

```zsh
talosctl get links -n 10.10.30.x --insecure
```
The network interface is called `eth0`.

```zsh
talosctl get disks -n 10.10.30.x --insecure
```
The install disk I want to use (500GB SATA SSD) is called `/dev/sda`.

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

Talos can instruct Kubernetes to setup a VIP between the control-plane nodes, so I don't have to use an external loadbalancer.
```yaml
# vip.yaml
machine:
  network:
    interfaces:
      - interface: eth0
        vip:
          ip: 10.10.30.10
```

And finally I'll set the install disk and ask Talos to wipe it before installing.

```yaml
# install-disk.yaml
machine:
  install:
    disk: /dev/sda
    wipe: true
```

We can now generate the configuration files using the fice patches.

```zsh
talosctl gen config asgard https://10.10.30.10:6443 \
--with-secrets secrets.yaml \
--kubernetes-version 1.29.1 \
--config-patch @patches/dhcp.yaml \
--config-patch @patches/install-disk.yaml \
--config-patch @patches/allow-workloads-controlplane.yaml \
--config-patch-control-plane @patches/vip.yaml
```
One could ask why I'm seperating out the `dhcp` and `vip` patches, since all my nodes are control-plane it shouldn't make a difference. I do that simply because it then makes it easier to setup an additional worker node later if needed.

The configuration files have now been generated:smile::tada:
Three files have been generated:
- controlplane.yaml
- worker.yaml
- talosconfig

I'll only need the `controlplane.yaml` as I don't have any worker nodes. We have to come back to the `talosconfig` later.

It's time to add the configuration to the nodes, one at a time.

```zsh
talosctl apply-config -f controlplane.yaml -n 10.10.30.2 --insecure
talosctl apply-config -f controlplane.yaml -n 10.10.30.3 --insecure
talosctl apply-config -f controlplane.yaml -n 10.10.30.4 --insecure
```
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
It is now time to bootstrap kubernetes :+1:

This is super simple with Talos:

```zsh
talosctl bootstrap -n 10.10.30.2
```
Only send this command to **one** node. After a bit the `kubeconfig` file can be retreived.

```zsh
talosctl kubeconfig
```

Done! 