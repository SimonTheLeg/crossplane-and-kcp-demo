# kcp <> crossplane demo

This Readme describes the demo which is part of the presentation. It includes all steps and commands for you to try for yourself.

## How this works with kind

We create two kind clusters:

1. For the kcp cluster, we create a kind machine which binds on localhost:8443 on the host and then converts that into NodePort 31443, which has the kcp service listening on this NodePort.
Additionally since kcp only works with hostnames, we also set the hostalias in the pod. Effectively we can now reach the kcp pod via kcp.dev.local on our host machine.
2. For the provider cluster, we setup a CoreDNS rewrite so that kcp.dev.local gets resolved with the IP given by host.docker.internal. By doing this Pods from inside the provider cluster can reach the kcp pod via the docker host network, but still will use the dev.kcp.local hostname when making requests.

Then to also be able to use hostnames on the host, we modify /etc/host on the local machine to have "kcp.dev.local" to point to 127.0.0.1.

## Preparing VM

If you are on any non-Linux system, make sure that your container VM has enough resources (note: I don't think we need that much, but just to be sure). For example in podman:

```sh
podman machine set --cpus 6 --memory 8096
```

## Setup - Preparation for live demo

All commands should be executed from the demo folder of this repository.

You can use the provided setup script:

```sh
./setup
```

## Teardown

After you are finished with the demo, you can use the provided teardown script:

```sh
./teardown
```

## Live Demo Runbook

(note: we are using [kubectl neat](https://github.com/itaysk/kubectl-neat) here, to make the output a little easier for the audience to digest. If you don't want to use the plugin, simply run "k get" instead of "k neat get" )

Firstly explain the tmux setup and different roles:

--- Provider ---

1. Go to provider tab
2. Show that crossplane and the mysql provider is already installed and running:

    ```sh
    k get pods -n crossplane-system
    ```

3. Show the crossplane composition, specifically show:
    - it registers a type `database.mycorp.io/v1`
    - it creates a `mysql.sql.crossplane.io/v1alpha1` object
    - it creates a secret, which we want to sync back to the consumer later

    ```sh
    k neat get compositions.apiextensions.crossplane.io mysql-database-simple -o yaml | cat -l yaml
    ```

4. Show the published resource, specifically show:
    - the renaming and that we need it, because the object on the provider cluster is global and we need to ensure that there are no naming collisions
    - that we needed to use a little trick on the connector due to a bug in sync-agent. But in the future this should be possible using .ClusterName
    - explain that we need this label so the sync-agent can find the secret in the provider cluster and does not sync all secrets over

    ```sh
    cat -l yaml 3_live-demo/published-resource.yaml
    ```

5. Apply the published resource:

    ```sh
    # in the right pane
    k apply -f 3_live-demo/published-resource.yaml
    ```

--- Consumer ---

1. Show the api-binding and recap that we need this to make the `database.mycorp.io/v1` api available in the consumer workspace

    - highlight the reference path
    - explain that in the heat of the moment we forgot to restrict permissions

    ```sh
    cat -l yaml 3_live-demo/apibinding.yaml
    ```

    ```sh
    k apply -f 3_live-demo/apibinding.yaml
    ```

2. Show that the `database.mycorp.io/v1` api is now available in the consumer workspace

    ```sh
    k api-resources | grep database
    ```

3. Show the database xr and apply it

    ```sh
    cat -l yaml 3_live-demo/team-a-db.yaml
    k apply -f 3_live-demo/team-a-db.yaml
    ```

4. Show that the secret was synched successfully

    ```sh
    k get secret
    ```

--- Provider ---

1. Show that the secret and all resources were successfully created in the provider workspace. Highlight that we need this unique name, so we don't have any naming collisions later on

    ```sh
    k get mysqldatabases.database.mycorp.io
    k get secrets | grep credentials
    ```
