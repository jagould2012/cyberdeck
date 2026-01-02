# SDRAngel ARM64 Debian Package Builder

Builds SDRAngel as a `.deb` package for Raspberry Pi (arm64/aarch64) using Docker on Apple Silicon Mac.

## Why?

SDRAngel doesn't provide prebuilt arm64 packages. Building from source on a Raspberry Pi takes 1-2+ hours. This Docker build runs on your Mac (much faster) and produces a `.deb` that installs in seconds.

## Prerequisites

- Apple Silicon Mac (M1/M2/M3)
- Docker Desktop installed and running
- ~10GB free disk space

## Usage

```bash
./build.sh
```

This will:
1. Build the Docker image (~30-60 minutes first time)
2. Compile SDRAngel and all dependencies
3. Package everything into a `.deb` file
4. Copy the `.deb` to `../ansible/files/sdrangel_arm64.deb`

## Output

- `output/sdrangel_<version>_arm64.deb` - The built package
- `../ansible/files/sdrangel_arm64.deb` - Copy for Ansible deployment

## Manual Installation

If you want to install manually without Ansible:

```bash
scp output/sdrangel_*.deb user@raspberry-pi:~/
ssh user@raspberry-pi 'sudo apt install -f ./sdrangel_*.deb'
```

## With Ansible

After building, deploy to all hosts:

```bash
cd ../ansible
ansible-playbook site.yml -K
```

## What's Included

The package includes SDRAngel and these bundled libraries:
- cm256cc (forward error correction)
- mbelib (voice codec)
- serialDV (DV serial interface)
- dsdcc (digital speech decoder)
- codec2 (voice codec)
- sgp4 (satellite tracking)
- libsigmf (signal metadata)

## Supported SDR Hardware

- RTL-SDR
- HackRF
- Airspy / Airspy HF+
- LimeSDR
- BladeRF
- PlutoSDR
- USRP (via SoapySDR)

## Rebuilding

To rebuild after SDRAngel updates:

```bash
# Remove old image to force fresh build
docker rmi sdrangel-builder

# Build again
./build.sh
```

## Troubleshooting

### Build fails with memory error
Docker Desktop may need more memory. Go to Docker Desktop → Settings → Resources and increase memory to 8GB+.

### Build takes too long
First build downloads and compiles everything (~30-60 min). Subsequent builds with cache are faster.

### Package won't install on Pi
Ensure the Pi is running Debian Bookworm (12) arm64. Check dependencies:
```bash
sudo apt update
sudo apt install -f
```