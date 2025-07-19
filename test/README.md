# Test Directory Structure

This directory contains test fixtures, integration tests, and unit tests for kdiff.

## Directory Layout

```
test/
├── fixtures/           # Kubernetes manifest test files
├── integration/        # Integration tests for full kdiff workflow
├── unit/              # Unit tests for individual functions
└── README.md          # This file
```

## Test Fixtures

The `fixtures/` directory contains sample Kubernetes manifests for testing:

- **deployment.yaml** - Standard nginx deployment with resources, affinity
- **deployment-modified.yaml** - Modified version (different replicas, image, resources)
- **service.yaml** - ClusterIP service with annotations
- **pod.yaml** - Pod with volumes, env vars, node selector
- **configmap.yaml** - ConfigMap with nginx config and app properties

### Key Test Scenarios

These fixtures support testing:

1. **Kind filtering** - Mix of Deployment, Service, Pod, ConfigMap
2. **Scope filtering** - Test `.spec`, `.metadata.labels`, etc.
3. **Noise removal** - All include `last-applied-configuration` annotations
4. **Status filtering** - All include `.status` sections to test removal
5. **Diff comparison** - `deployment.yaml` vs `deployment-modified.yaml` for changes

### Usage Examples

```bash
# Test kind filtering (should show only deployments)
kdiff --kind=Deployment -- diff test/fixtures/deployment.yaml test/fixtures/service.yaml

# Test scope filtering (spec only)
kdiff --scope=.spec -- diff test/fixtures/deployment.yaml test/fixtures/deployment-modified.yaml

# Test noise removal
kdiff --yq 'del(.metadata.annotations."kubectl.kubernetes.io/last-applied-configuration")' -- diff test/fixtures/pod.yaml test/fixtures/pod.yaml
```