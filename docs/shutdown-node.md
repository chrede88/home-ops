# Shutdown a Node
Talos has an inbuild function to gracefully shutdown a node.

```zsh
talosctl shutdown -n IP-of-node --wait
```

The `--wait` flag is nice as talosctl will monitor the shutdown process.