# My home-ops journey

I'll try to document the full setup process from the very begining. I do this mainly for my own sake, so I can go back to find what I did easily. But also for others who might stumble on this while searching the big web for answers.

## Plan
My plan is to run a three node Kubernetes cluster on bare metal servers. I used to run kuberntes on Proxmox VMs running k3s. I've nothing bad to say about k3s, it was fairly simple to setup and there are many good tutorials out there. But I got somewhat feed up with having to manage many idividual machines, plus the hypervisor itself. People, including myself, use Ansible (or something similar) to automate all this, but I still wanted something easier to manage.
When first heard about Talos Linux, I was completely sold from the get go. Having an operating system that you treat just like you would any workloads in Kubernetes just sounded amazing. Keeping the state in a .yaml document means it's always clear what's runnig and what version. Talos Linux is also different in that you talk to it through an API (and only through the API), there is no SSH etc. This certainly makes it simpler and less vulnerable, but it might also be a curse. Only time will tell!

## Hardware
I went with three server nodes to give my a HA control-plane/etcd, which to be completely honest is probably complete overkill. I'm mostly doing this because I find it interesting and want to learn. From that perspective one control-plane node should be just fine, but I guess I'm like most people who has a hobby: The bare minimum is never good enough😉

### Servers
Each server is identical so I'll only list the specs once.
- System: Intel NUC 12WSHi5
- CPU: Intel Core i5 1240-P (12c/16t)
- RAM: 2x Vengeance DDR4 3200MHz 32GB
- Storage: Samsung 870 EVO 500GB 2.5" SATA SSD
- Storage: Samsung 980 PRO 2TB M.2 NVME SSD

### Network
I updated my network equipment in the begining of April 2024. All I had before was a Unifi Dream Router from Ubiquiti. The UDR has a 1Gb/s 4-port switch, which was just enough for my three kubernetes nodes and my backup pihole running on a RPi 4. I've been planing on upgrading to 2.5Gb/s for a while now, and when I saw that Ubiquiti released the Unifi Gateway Max I picked one up. It has a single 2.5Gb/s WAN port plus a 4-port 2.5Gb/s switch.

Here follows a list of network equipment that I currently have deployed:

1) Unifi Gateway Max (UXG)
2) Unifi Cloudkey Gen 2+
3) Unifi Switch Ultra
4) Unifi U6+ Access Point


## Files
This is a list of the documentation I've put together so far (in order):

1. Everything to do with getting Talos and Kubernetes up and running: [setup.md](./setup.md)
2. Flux:
    1. Setting up Flux: [fluxcd.md](./fluxcd.md)
    2. Migrating to the Flux Operator: [flux-operator.md](./flux-operator.md)
3. Reconfiguring Cilium: [cilium.md](./cilium.md)
4. Installing Cert-manager: [cert-manager.md](./cert-manager.md)
5. Installing Rook & Ceph: [rook-ceph.md](./rook-ceph.md)
6. Ingress: [ingress.md](./ingress.md)
7. Renovate: [renovate.md](./renovate.md)
8. Cloudnative PostgreSQL: [cloudnative-pg.md](./cloudnative-pg.md)
9. Prometheus and Grafana: [prometheus.md](./prometheus.md)
10. External-dns: [external-dns.md](./external-dns.md)

### Old config
I'm conteniusly changing my cluster. Some docs are therefore not relevant anymore, but I keep them around in case they can help others. You can find these in the `old` folder. So far it contains the following:
1. Installing Pi-hole: [pihole.md](./old/pihole.md)
2. External-dns for Pihole: [external-dns-pihole.md](./old/external-dns-pihole.md)

### Interacting with a Ceph cluster
I'm keeping a short list of general commands that are good to know when interacting with a Ceph cluster. See more in [ceph-cluster.md](./ceph-cluster.md).

### Updating cluster
Keeping the cluster up-to-date is important. Both Talos Linux and Kubernetes itself should be kept up-to-date. See more in [update.md](./update.md).

### Shut down a node
Sometimes shutting down a node is required. See [shutdown-node.md](./shutdown-node.md).

### Destroying the cluster
Sometimes it's just easier to completely burn down the cluster🔥
See [destroy-cluster.md](./destroy-cluster.md) for more info.