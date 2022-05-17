# Kubernetes Flake for NixOS with full control

**Status: WIP**

This NixOS Flake provides package and module definitions for Kubernetes related components.

Custom Kubernetes clusters could be defined using this flake with ease.

We're trying to expose low level options for each component so that Kubernetes administrators could have full control by creating high level abstractions.

## Why

Kubernetes is a complex system with many components. For each component, there are many choices.
In practice Kubernetes administrator would have to make technical decisions based on their needs and hardware constraints.

The [default Kubernetes module](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/cluster/kubernetes/default.nix) in NixOS
choose to use [Flannel](https://github.com/flannel-io/flannel) for container networking and [cfssl](https://github.com/cloudflare/cfssl) for certificates management.
It's easy to use when building a new cluster from scatch. But you have to workaround with it when your cluster design doesn't match the default one.

In this flake, we don't make assumptions about the cluster design by just exposing low level options.
Kubernetes administrators could use provided options to build their cluster or replace some components with their own implementation.

## Use Cases

We have gathered some use cases below. Feel free to add your own use case by submitting a pull request or creating an issue.

  * Run different version of kubelet on different node so we could upgrade the cluster gradually
  * Keep kubelet version unchanged when switching NixOS channel 
  * High Availability etcd Cluster
  * Run control plane components using static pods on Master node
  * Use `rotateCertificates` feature in kubelet for node certificates management
  * Replace [containerd](https://github.com/containerd/containerd) with [cri-o](https://github.com/cri-o/cri-o) for CRI
  * Support more CNI plugins

## Supported Components

We're adding components one by one. Stay tuned.

| Component                         | Project                 | Status             |
| --------------------------------- | ----------------------- | ------------------ |
| Kubernetes Core                   | kube-api-server         | ×                  |
|                                   | kube-controller-manager | ×                  |
|                                   | kube-scheduler          | ×                  |
|                                   | kubelet                 | ✓                  |
|                                   | kube-proxy              | ×                  |
|                                   | etcd                    | ×                  |
| Container Runtime Interface (CRI) | containerd              | ✓                  |
|                                   | cri-o                   | ×                  |
| Container Network Interface (CNI) | host-local              | ✓                  |
|                                   | flannel                 | ×                  |
|                                   | cilium                  | ×                  |
|                                   | calico                  | ×                  |
|                                   | kube-router             | ×                  |