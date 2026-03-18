#!/usr/bin/env fish

# Provider (provider-kind.kubeconfig)
abbr -a d1 "k get pods -n crossplane-system"
abbr -a d2 "k neat get compositions.apiextensions.crossplane.io mysql-database-simple -o yaml | cat -l yaml"
abbr -a d3 "cat -l yaml 3_live-demo/published-resource.yaml"
abbr -a d4 "k apply -f 3_live-demo/published-resource.yaml"

# Consumer (consumer-kcp.kubeconfig)
abbr -a d5 "cat -l yaml 3_live-demo/apibinding.yaml"
abbr -a d6 "k apply -f 3_live-demo/apibinding.yaml"
abbr -a d7 "k api-resources | grep database"
abbr -a d8 "cat -l yaml 3_live-demo/team-a-db.yaml"
abbr -a d9 "k apply -f 3_live-demo/team-a-db.yaml"
abbr -a d10 "k get secret"

# Provider (provider-kind.kubeconfig)
abbr -a d11 "k get mysqldatabases.database.mycorp.io"
abbr -a d12 "k get secrets | grep credentials"
