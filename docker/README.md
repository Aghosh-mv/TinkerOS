# TinkerOS Docker Images

## Images

| Image | Description | Use Case |
|-------|-------------|----------|
| `ghcr.io/tinkeros/tinkeros/base` | Minimal base | CI, minimal containers |
| `ghcr.io/tinkeros/tinkeros/dev` | Full dev environment | Daily development |
| `ghcr.io/tinkeros/tinkeros/ci` | CI environment | GitHub Actions, GitLab CI |
| `ghcr.io/tinkeros/tinkeros/iso-builder` | ISO builder | Building release ISOs |

## Quick Start

### Development
```bash
# Start development container
docker compose -f docker/docker-compose.yml up -d dev
docker exec -it tinkeros-dev bash

# Or run directly
docker run -it --rm \
  -v $(pwd):/workspace \
  -v ~/.gitconfig:/home/tinkerer/.gitconfig:ro \
  -v ~/.ssh:/home/tinkerer/.ssh:ro \
  -v /var/run/docker.sock:/var/run/docker.sock \
  ghcr.io/tinkeros/tinkeros/dev:latest
```

### CI Pipeline
```bash
# Run CI locally
docker run -it --rm \
  -v $(pwd):/workspace \
  -v /var/run/docker.sock:/var/run/docker.sock \
  ghcr.io/tinkeros/tinkeros/ci:latest \
  /bin/bash -c "cd /workspace && ./build/tinker-build.py --profile standard"
```

### Build ISO
```bash
# Build ISO in container
docker run -it --rm --privileged \
  -v $(pwd):/workspace \
  -v iso-output:/output \
  ghcr.io/tinkeros/tinkeros/iso-builder:latest \
  /bin/bash -c "cd /workspace && python3 build/tinker-build.py --profile standard"
```

### Test ISO with QEMU
```bash
# Test boot
docker run -it --rm --privileged \
  -v iso-output:/iso \
  ubuntu:24.04 \
  qemu-system-x86_64 -cdrom /iso/TinkerOS-standard-*.iso -m 2G -enable-kvm -display none
```

## Building Images

```bash
# Build all images
docker compose -f docker/docker-compose.yml build

# Build specific image
docker compose -f docker/docker-compose.yml build dev

# Push to registry
docker compose -f docker/docker-compose.yml push
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `TERM` | `xterm-256color` | Terminal type |
| `DOCKER_HOST` | `unix:///var/run/docker.sock` | Docker daemon |
| `CI` | `true` | CI mode |
| `GITHUB_ACTIONS` | `true` | GitHub Actions |

## Volumes

| Volume | Mount Point | Purpose |
|--------|-------------|---------|
| `../` | `/workspace` | Source code |
| `~/.gitconfig` | `~/.gitconfig` | Git config |
| `~/.ssh` | `~/.ssh` | SSH keys |
| `/var/run/docker.sock` | `/var/run/docker.sock` | Docker socket |
| `iso-output` | `/output` | ISO artifacts |

## Security

- Containers run as non-root user (`tinkerer`/`builder`)
- Docker socket mounted for Docker-in-Docker
- `--cap-add` only for debugging
- `--security-opt seccomp=unconfined` for kernel debugging
