# One time
Ensure that we have enough resources (note: I don't think we need that much, but just to be sure)

```sh
podman machine set --cpus 6 --memory 8096
```

# How this works with kind
Basically we create a kind machine which binds on localhost:8443 on the host and then converts that into NodePort 31443, which has a service listening on this NodePort.
Additionally since kcp only works with hostnames, we also set the hostalias in the pod.

Then to also be able to use hostnames, we modify /etc/host on the local machine to have "kcp.dev.local" to point to localhost.

# Regular Setup
All commands should be executed from the demo folder of this repository

```sh
./1_kcp_setup/kind-setup.sh
```

This then gives you two kubeconfigs:
```sh
# kubeconfig to access the kind cluster where kcp is running
export KUBECONFIG=kcp-kind.kubeconfig

# admin kubeconfig of kcp
export KUBECONFIG=kcp.kubeconfig
```
