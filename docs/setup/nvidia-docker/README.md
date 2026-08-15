# NVIDIA Docker setup

> Optional setup. This is not run by the main installer.

You need `nvidia-container-toolkit` for Docker containers to use an NVIDIA GPU on Arch Linux, including Omarchy.

## Installation

The package is available directly from Arch's Extra repository:

```bash
sudo pacman -S nvidia-container-toolkit
```

## Configuration

After installation, configure Docker to use the NVIDIA runtime:

```bash
sudo nvidia-ctk runtime configure --runtime=docker
```

This command automatically modifies `/etc/docker/daemon.json` to enable the NVIDIA Container Runtime.

Restart Docker for changes to take effect:

```bash
sudo systemctl restart docker
```

## Using GPU in Containers

### Docker Run Command

Use the `--gpus` flag (recommended):

```bash
docker run --gpus all nvidia/cuda:12.1.1-runtime-ubuntu22.04 nvidia-smi
```

Specify specific GPUs:

```bash
docker run --gpus 2 nvidia/cuda:12.1.1-runtime-ubuntu22.04 nvidia-smi
```

### Docker Compose

Add GPU support to your `compose.yaml`:

```yaml
service_name:
  image: ....
  deploy:
    resources:
      reservations:
        devices:
          - driver: nvidia
            count: 1
            capabilities: [gpu]
```
