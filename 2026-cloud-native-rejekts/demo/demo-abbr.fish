#!/usr/bin/env fish

# Provider (provider-kind.kubeconfig)
abbr -a d1 "k get pods -n crossplane-system"
abbr -a d2 "k get crd | grep mysql"
abbr -a d3 "k neat get xrd -o yaml | cat -l yaml"
abbr -a d4 "k neat get compositions.apiextensions.crossplane.io mysql-database-simple -o yaml | cat -l yaml"
abbr -a d5 "cat -l yaml 3_live-demo/published-resource.yaml"
abbr -a d6 "k apply -f 3_live-demo/published-resource.yaml"

# Consumer (consumer-kcp.kubeconfig)
abbr -a d7 "cat -l yaml 3_live-demo/apibinding.yaml"
abbr -a d8 "k apply -f 3_live-demo/apibinding.yaml"
abbr -a d9 "k api-resources | grep database"
abbr -a d10 "cat -l yaml 3_live-demo/team-a-db.yaml"
abbr -a d11 "k apply -f 3_live-demo/team-a-db.yaml"
abbr -a d12 "k get secret"

# Provider (provider-kind.kubeconfig)
abbr -a d13 "k get mysqldatabases.database.mycorp.io"
abbr -a d14 "k get secrets | grep credentials"
abbr -a d15 "k get managed"
