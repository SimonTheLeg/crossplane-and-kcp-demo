# Crossplane Demo Setup

This folder contains example Crossplane YAML manifests for demonstrating how to create custom resources, compositions, and deploy applications using Crossplane.

## Prerequisites

- A running kind cluster
- kubectl configured to access your cluster

## Setup Instructions

### 1. Install Crossplane

First, install Crossplane in your kind cluster:

```bash
# Add the Crossplane Helm repository
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm repo update

# Install Crossplane
kubectl create namespace crossplane-system
helm install crossplane crossplane-stable/crossplane \
  --namespace crossplane-system
```

Wait for Crossplane to be ready:

```bash
kubectl wait --for=condition=ready pod -l app=crossplane --namespace crossplane-system --timeout=120s
```

### 2. Apply Manifests Step by Step

Apply the manifests in the following order:

#### Step 1: Install the Go Templating Function
```bash
kubectl apply -f 00-function-go-templating.yaml
```

Wait for the function to be ready:
```bash
kubectl wait --for=condition=healthy function.pkg.crossplane.io/function-go-templating --timeout=120s
```

#### Step 2: Create the Composite Resource Definition (XRD)
```bash
kubectl apply -f 01-xrd-app.yaml
```

Verify the XRD is established:
```bash
kubectl get xrd apps.example.crossplane.io
```

#### Step 3: Create the Composition
```bash
kubectl apply -f 02-composition.yaml
```

Verify the composition is ready:
```bash
kubectl get composition app-templated-yaml
```

#### Step 4: Create an App Instance
```bash
kubectl apply -f 03-xr-nginx.yaml
```

### 3. Verify the Setup

Check that your App resource was created:
```bash
kubectl get app my-app -n default
```

Check the generated Kubernetes resources:
```bash
# Check deployment
kubectl get deployment -l example.crossplane.io/app=my-app

# Check service
kubectl get service -l example.crossplane.io/app=my-app

# Check pods
kubectl get pods -l example.crossplane.io/app=my-app
```

Check the status of the App resource:
```bash
kubectl describe app my-app -n default
```

## What This Demo Shows

1. **Function Installation**: How to install and use Crossplane functions for advanced composition logic
2. **Custom Resource Definition**: Defining a custom `App` resource with schema validation
3. **Composition with Go Templating**: Using Go templates to dynamically generate Kubernetes resources
4. **Resource Management**: How Crossplane manages the lifecycle of composed resources

## Cleanup

To clean up the demo:

```bash
# Delete the app instance
kubectl delete -f 03-xr-nginx.yaml

# Delete the composition and XRD
kubectl delete -f 02-composition.yaml
kubectl delete -f 01-xrd-app.yaml
kubectl delete -f 00-function-go-templating.yaml

# Uninstall Crossplane (optional)
helm uninstall crossplane --namespace crossplane-system
kubectl delete namespace crossplane-system
```

## Files Description

- **00-function-go-templating.yaml**: Installs the Go templating function for advanced composition logic
- **01-xrd-app.yaml**: Defines the `App` composite resource definition with schema
- **02-composition.yaml**: Creates a composition that generates Deployment and Service resources using Go templates
- **03-xr-nginx.yaml**: Example App instance that creates an nginx application