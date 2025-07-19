# kdiff - Enhanced kubectl/argocd diff with filtering

kdiff is a command-line tool that enhances the `kubectl diff` and `argocd diff` user experience by providing powerful filtering and preprocessing capabilities for Kubernetes manifests.

## Features

- **Kind filtering**: Show diffs only for specific resource types (Pod, Service, Deployment, etc.)
- **Scope filtering**: Diff only specific sections like `.spec` or `.metadata.labels`
- **Custom yq transformations**: Remove noisy fields, apply arbitrary YAML processing
- **Preserves diff tools**: Works with your existing diff tool (delta, difftastic, etc.)
- **Zero configuration**: Works out of the box as a drop-in replacement

## Installation

```bash
# Clone and install
git clone <repository-url>
cd kdiff-tools
make install  # Installs to ~/.local/bin by default
```

## Usage

### Basic Usage

```bash
# Diff only the resource specs
kdiff --scope=.spec -- kubectl diff -f deployment.yaml

# Show diffs for services and pods only  
kdiff --kind=svc,po -- kubectl diff -k overlays/staging

# Remove noisy annotations before diffing
kdiff --yq='del(.metadata.annotations."kubectl.kubernetes.io/last-applied-configuration")' -- kubectl diff -f .

# Use with argocd
kdiff --kind=Deployment -- argocd diff myapp
```

### Integration with kubectl

Set kdiff as your external diff tool:

```bash
export KUBECTL_EXTERNAL_DIFF="kdiff --scope=.spec"
kubectl diff -f myapp.yaml
```

## How It Works

kdiff operates in two modes to seamlessly integrate with kubectl while preserving your original diff tool:

### Flow: Preserving KUBECTL_EXTERNAL_DIFF

1. **User invocation**: `kdiff --scope=.spec -- kubectl diff -f app.yaml`
2. **kdiff detects** current `KUBECTL_EXTERNAL_DIFF` (e.g., `delta`)  
3. **kdiff sets**: `KUBECTL_EXTERNAL_DIFF="kdiff --compare --scope=.spec --diff-cmd='delta'"`
4. **kdiff executes**: `kubectl diff -f app.yaml`
5. **kubectl calls** kdiff with the internal `--compare` mode
6. **kdiff processes** files according to filters and uses original diff tool (`delta`) from `--diff-cmd`

This approach ensures your fancy diff tool (delta, difftastic, etc.) is preserved throughout the filtering process.

## Command Line Reference

### User-Facing Flags

- `--kind=<kinds>` - Only show diffs for specified resource kinds (e.g., `Pod,Service,po,svc`)
- `--scope=<yq_path>` - Diff only a specific part of resources (e.g., `.spec`, `.metadata.labels`)  
- `--yq=<expression>` - Apply arbitrary yq expression to both manifests
- `--help` - Show help message

### Internal Flags

- `--compare` - Internal mode used by kubectl (not for direct use)
- `--diff-cmd=<command>` - Specify diff tool to use (preserves original KUBECTL_EXTERNAL_DIFF)

## Examples

### Remove Noisy Fields

```bash
# Remove last-applied-configuration and status
kdiff --yq='del(.metadata.annotations."kubectl.kubernetes.io/last-applied-configuration") | del(.status)' -- kubectl diff -f .
```

### Focus on Specific Resources

```bash
# Only show deployment changes
kdiff --kind=deploy -- kubectl diff -k overlays/prod

# Only show service specs  
kdiff --kind=svc --scope=.spec -- kubectl diff -f services/
```

### Kubernetes Abbreviations

kdiff understands common kubectl abbreviations:
- `po`, `pod` → Pod
- `svc`, `service` → Service  
- `deploy`, `deployment` → Deployment
- `cm`, `configmap` → ConfigMap

## Development

```bash
# Run linting
make lint

# Format code
make format

# Run tests (when implemented)
make test
```

## Dependencies

- `bash` (v4+)
- `yq` (v4, Go implementation by Mike Farah)
- `diffutils` (for the `diff` command)
- `mktemp`