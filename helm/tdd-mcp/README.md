# TDD-MCP Helm Chart

This Helm chart deploys the TDD-MCP FastAPI server to your Kubernetes cluster with NodePort access on port 63777.

**Note**: By default, Kubernetes restricts NodePorts to 30000-32767. This chart is configured to use port 63777, which requires:
- Extending the NodePort range in your cluster, OR
- Using `kubectl port-forward` to access the service on port 63777

## Prerequisites

- Kubernetes cluster (1.19+)
- Helm 3.0+
- Docker image built and available to your cluster

## Building the Docker Image

Before installing the chart, build the Docker image:

```bash
docker build -t tdd-mcp:latest .
```

If you're using a remote Kubernetes cluster, you'll need to push the image to a container registry:

```bash
# Tag the image for your registry
docker tag tdd-mcp:latest your-registry/tdd-mcp:latest

# Push to registry
docker push your-registry/tdd-mcp:latest
```

Then update `values.yaml` to use your registry:

```yaml
image:
  repository: your-registry/tdd-mcp
  tag: "latest"
```

## Installation

The chart will automatically create and deploy to the `test-driven-development` namespace.

### Install the chart

```bash
helm install tdd-mcp ./helm/tdd-mcp
```

This will:
1. Create the `test-driven-development` namespace (if it doesn't exist)
2. Deploy the TDD-MCP server to that namespace
3. Attempt to expose it via NodePort 63777

### Install with custom values

```bash
helm install tdd-mcp ./helm/tdd-mcp -f custom-values.yaml
```

### Install with inline overrides

```bash
helm install tdd-mcp ./helm/tdd-mcp \
  --set image.repository=your-registry/tdd-mcp \
  --set image.tag=v1.0.0
```

### Install to a different namespace

If you want to use a different namespace:

```bash
helm install tdd-mcp ./helm/tdd-mcp \
  --set namespace.name=my-custom-namespace
```

## Accessing the Service

### Option 1: Extended NodePort Range (Requires Cluster Configuration)

If you've configured your cluster to allow NodePort 63777:

```bash
# Get the node IP
kubectl get nodes -o wide

# Access the service via NodePort 63777
curl http://<NODE_IP>:63777/health

# Or check the service in the namespace
kubectl get svc -n test-driven-development
```

For MCP client configuration, use:
```
http://<NODE_IP>:63777
```

See `configure-nodeport-range.sh` for instructions on extending your cluster's NodePort range.

### Option 2: Port Forwarding (Recommended for Docker Desktop)

Use kubectl port-forward to access the service on port 63777:

```bash
# Forward port 63777
kubectl port-forward -n test-driven-development svc/tdd-mcp 63777:63777

# Access at localhost
curl http://localhost:63777/health
```

For MCP client configuration with port-forwarding, use:
```
http://localhost:63777
```

**Note**: Keep the port-forward command running in a separate terminal.

## Configuration

The following table lists the configurable parameters of the TDD-MCP chart and their default values.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `namespace.name` | Namespace to deploy to | `test-driven-development` |
| `namespace.create` | Create the namespace if it doesn't exist | `true` |
| `replicaCount` | Number of replicas | `1` |
| `image.repository` | Image repository | `tdd-mcp` |
| `image.tag` | Image tag | `latest` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `service.type` | Service type | `NodePort` |
| `service.port` | Service port (internal) | `63777` |
| `service.nodePort` | NodePort to expose (external) | `63777` |
| `service.targetPort` | Container port | `63777` |
| `resources` | CPU/Memory resource requests/limits | `{}` |
| `nodeSelector` | Node labels for pod assignment | `{}` |
| `tolerations` | Tolerations for pod assignment | `[]` |
| `affinity` | Affinity rules for pod assignment | `{}` |

## Upgrading

```bash
helm upgrade tdd-mcp ./helm/tdd-mcp
```

## Uninstalling

```bash
helm uninstall tdd-mcp

# Optionally, delete the namespace
kubectl delete namespace test-driven-development
```

## Health Checks

The deployment includes liveness and readiness probes that check the `/health` endpoint:

- **Liveness Probe**: Ensures the container is running
- **Readiness Probe**: Ensures the container is ready to accept traffic

## Troubleshooting

### Check pod status
```bash
kubectl get pods -n test-driven-development -l app.kubernetes.io/name=tdd-mcp
```

### View pod logs
```bash
kubectl logs -n test-driven-development -l app.kubernetes.io/name=tdd-mcp
```

### Describe the service
```bash
kubectl describe service tdd-mcp -n test-driven-development
```

### Check if NodePort is accessible
```bash
# From within the cluster (using internal service port)
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -n test-driven-development -- \
  curl http://tdd-mcp:63777/health

# From outside the cluster (using NodePort - if range is extended)
curl http://<NODE_IP>:63777/health

# Or use port-forwarding
kubectl port-forward -n test-driven-development svc/tdd-mcp 63777:63777 &
curl http://localhost:63777/health
```

## Advanced Configuration

### Using a ConfigMap

To mount configuration files:

```yaml
configMap:
  enabled: true
  data:
    config.yaml: |
      key: value
```

### Setting Environment Variables

```yaml
env:
  - name: LOG_LEVEL
    value: "debug"
  - name: CUSTOM_VAR
    value: "custom_value"
```

### Resource Limits

```yaml
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi
```
