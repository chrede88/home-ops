# My home-ops journey

I'll try to document the full setup process from the very begining. I do this mainly for my own sake, so I can go back to find what I did easily. But also for others who might stumble on this while searching the big web for answers.

## Plan
My plan is to run a three node Kubernetes cluster on bare metal servers. I used to run kuberntes on Proxmox VMs running k3s. I've nothing bad to say about k3s, it was fairly simple to setup and there are many good tutorials out there. But I got somewhat feed up with having to manage many idividual machines, plus the hypervisor itself. People, including myself, use Ansible (or something similar) to automate all this, but I still wanted something easier to manage.
When first heard about Talos Linux, I was completely sold from the get go. Having an operating system that you treat just like you would any workloads in Kubernetes just sounded amazing. Keeping the state in a .yaml document means it always clear what's runnig and what version. Talos Linux is also different in that you talk to it through an API (and only through the API), there is no SSH etc. This certainly makes it simpler and less vulnerable, but it might also be a curse. Only time will tell! 

## Hardware
I went with three server nodes to give my a HA control-plane/etcd, which to be completely honest is probably completely overkill. I'm mostly doing this because I find it interesting and want to learn. From that perspective one control-plane node should be just fine, but I guess I'm like most people who has a hobby: The bare minimum is never good enough:wink:

### Servers
Each server is identical so I'll only list the specs once.
- System: Intel NUC 12WSHi5
- CPU: Intel Core i5 1240-P (12c/16t)
- RAM: 2x Vengeance DDR4 3200MHz 32GB
- Storage: Samsung 870 EVO 500GB 2.5" SATA SSD
- Storage: Samsung 980 PRO 2TB M.2 NVME SSD

### Network
The network setup is very minimal as it is just a Ubiqiuti UDR. The router has a build-in 4 port GB/s switch, which for now is just enough. This is probably to first area I'll expand at some point.

## Files
This is a list of the documentation I've put together so far (in order):

1) Everything to do with getting Talos and Kubernetes up and running: [setup.md](./setup.md)
2) Setting up Flux: [fluxcd.md](./fluxcd.md)
3) Reconfiguring Cilium: [cilium.md](./cilium.md)
4) Installing Cert-manager: [cert-manager.md](./cert-manager.md)
5) Installing Rook & Ceph: [rook-ceph.md](./rook-ceph.md)
6) Installing Pihole: [pihole.md](./pihole.md)

### Destroying the cluster
Sometimes it's just easier to completely burn down the cluster:fire:
See [destroy-cluster.md](./destroy-cluster.md) for more info.