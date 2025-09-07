# One time

Ensure that we have enough resources (note: I don't think we need that much, but just to be sure)

```sh
podman machine set --cpus 6 --memory 8096
```

# How this works with kind

We create two kind clusters:

1. For the kcp cluster, we create a kind machine which binds on localhost:8443 on the host and then converts that into NodePort 31443, which has the kcp service listening on this NodePort.
Additionally since kcp only works with hostnames, we also set the hostalias in the pod. Effectively we can now reach the kcp pod via kcp.dev.local on our host machine.
2. For the provider cluster, we setup a CoreDNS rewrite so that kcp.dev.local gets resolved with the IP given by host.docker.internal. By doing this Pods from inside the provider cluster can reach the kcp pod via the docker host network, but still will use the dev.kcp.local hostname when making requests.

Then to also be able to use hostnames on the host, we modify /etc/host on the local machine to have "kcp.dev.local" to point to 127.0.0.1.

# Regular Setup

All commands should be executed from the demo folder of this repository

## Setting Up kcp Cluster and kcp

```sh
./1_kcp_setup/kind-setup.sh
```

This then gives you two kubeconfigs:

```sh
# kubeconfig to access the kind cluster where kcp is running
export KUBECONFIG=kcp-kind.kubeconfig

# admin kubeconfig of kcp
export KUBECONFIG=kcp-admin.kubeconfig
```

## Create the Provider workspace and kubeconfig

```sh
export KUBECONFIG=kcp-admin.kubeconfig
k create-workspace provider
# simply create the kubeconfig by appending :provider to the url and replace the name so it looks like a 
yq '.clusters[0].cluster.server += ":provider"' kcp-admin.kubeconfig | sed 's/admin-kcp/provider-kcp/g' > provider-kcp.kubeconfig
```

## Create the Consumer workspace and kubeconfig

```sh
export KUBECONFIG=kcp-admin.kubeconfig
k create-workspace consumer
# simply create the kubeconfig by appending :consumer to the url and replace the name so it looks like a 
yq '.clusters[0].cluster.server += ":consumer"' kcp-admin.kubeconfig | sed 's/admin-kcp/consumer-kcp/g' > consumer-kcp.kubeconfig
```

## Create the providers APIExport

api-syncagent requires you to create at least a blank ApiExport for it to fill it later

```sh
k apply -f 2_provider_setup/kcp/apiexport.yaml
```

## Setting Up Provider Cluster

```sh
export KUBECONFIG="provider-kind.kubeconfig"
kind create cluster --name provider
```

Afterwards edit the CoreDNS configmap to include a rewrite:

```sh
k edit -n kube-system cm coredns
# in there add the following
.:53 {
        rewrite name kcp.dev.local host.docker.internal
}
```

and restart coredns

```sh
k rollout restart -n kube-system deployment/coredns
```

## Install and setup kcp api-syncagent

Setup namespace and kubeconfig secret

```sh
export KUBECONFIG="provider-kcp.kubeconfig"
k create namespace kcp-sync-agent
k create secret generic kcp-kubeconfig -n kcp-sync-agent --from-file=kubeconfig=provider-kcp.kubeconfig
k apply -f 2_provider_setup/api-syncagent/additional-rbac
```

Deploy kcp-api-syncagent

```sh
helm upgrade \
  --install \
  --values ./2_provider_setup/api-syncagent/values.yaml \
  --namespace kcp-sync-agent \
  --create-namespace \
  --version "0.3.1" \
  kcp-api-syncagent kcp/api-syncagent
```

## Install Crossplane

First, install Crossplane in your kind cluster:

```bash
export KUBECONFIG="provider-kind.kubeconfig"
# Add the Crossplane Helm repository
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm repo update

# Install Crossplane
helm install crossplane crossplane-stable/crossplane \
  --namespace crossplane-system \
  --create-namespace
```

## Setup the Database

Deploys a mysql database.

```bash
k apply -f 2_provider_setup/database/
```

## Setup provider-sql

Setup provider-sql through which Crossplane will manage the database.

```bash
k apply -f 2_provider_setup/provider/provider.yaml
k wait --for condition=healthy -f 2_provider_setup/provider/provider.yaml
```

Create the provider config.

```bash
k create secret generic db-conn --from-literal endpoint=mysql.default.svc.cluster.local --from-literal port=3306 --from-literal username=root --from-literal password=password
k apply -f 2_provider_setup/provider/config.yaml
````

## Setup The Crossplane Composite Resource

```bash
export KUBECONFIG="provider-kind.kubeconfig"
k apply -f 2_provider_setup/crossplane/
```


# Live Demo

## Configure the api-syncagent

As the provider, create the published resource to send the example.crossplane.io/apps api to the provider kcp workspace.

```sh
export KUBECONFIG="provider-kind.kubeconfig"
k apply -f 3_live-demo/published-resource.yaml
```

As the consumer, bind the databases APIExport to make the api-available in your workspace and create a database

```sh
export KUBECONFIG="consumer-kcp.kubeconfig"
k apply -f 3_live-demo/apibinding.yaml
k apply -f 3_live-demo/xr-nginx.yaml
```

You can now see that in the provider the pods and secret have been created and that the secret has been synched over to the consumer workspace.
