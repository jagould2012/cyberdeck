# Synchronet BBS

Based on: https://wiki.synchro.net/howto:raspbian_install

## Files Included

- `Dockerfile` - Dockerfile for ARM64 Synchronet BBS with DOSEMU2 support
- `docker-compose.yml` - Docker Compose configuration
- `entrypoint.sh` - Startup script that injects environment variables
- `install.sh` - Installation script
- `README.md` - This file

## Base Image

We are currently using an x86_64 build due to a bug in the old version of SpyderMonkey (1.8.5) that Synchronet uses. Tracking [bug](https://gitlab.synchro.net/main/sbbs/-/issues/685) to hopefully go back to ARM64 build.

## Quick Start

```bash
# Run the installer
chmod +x install.sh
./install.sh

# The installer will:
# 1. Build the Docker image
# 2. Extract default config files
# 3. Launch scfg for initial configuration
# 4. Sanitize passwords from config files
# 5. Start the container
```

## Environment Variables

The following environment variables can be configured (e.g., in Portainer):

| Variable | Description | Default |
|----------|-------------|---------|
| `SYSOP_PASSWORD` | Sysop/admin password | `changeme` |
| `BBS_NAME` | Name of your BBS | `My BBS` |

### How It Works

1. The `install.sh` script removes passwords from config files after running scfg, replacing them with `SET_VIA_ENV`
2. Config files are safe to commit to git with placeholder values
3. At container startup, `entrypoint.sh`:
   - Copies `main.ini` to `/tmp/main.ini`
   - Injects the real password from `SYSOP_PASSWORD` environment variable
   - Uses a bind mount to overlay the modified file over the original
   - The host volume remains untouched with the placeholder value
4. Set the actual password in Portainer or your deployment environment

> **Note:** The container requires `SYS_ADMIN` capability for the bind mount. This is already configured in `docker-compose.yml`.

### Setting in Portainer

1. Go to your stack/container settings
2. Add environment variables:
   ```
   SYSOP_PASSWORD=your_secure_password
   BBS_NAME=Your Awesome BBS
   ```
3. Redeploy the container

### Setting via .env file (local development)

Create a `.env` file (add to .gitignore!):
```bash
SYSOP_PASSWORD=your_secure_password
BBS_NAME=Your Awesome BBS
```

---

## Directory Structure

The official Synchronet installation creates this directory structure:
```
/sbbs/
├── ctrl/     # Configuration files (copied, not symlinked - runtime writable)
├── data/     # User data, messages, etc. (runtime writable)
├── docs/     # Documentation (symlink to repo)
├── exec/     # Executables AND JavaScript runtime files
├── mods/     # Custom modifications
├── node1-4/  # Node directories
├── repo/     # The git repository
├── text/     # Menu files, ANSI art, themes (symlink to repo)
├── web/      # Legacy web interface (symlink to repo)
├── webv4/    # Modern web interface (symlink to repo)
└── xtrn/     # External programs/doors (symlink to repo)
```

## Dockerfile

1. Clones the full repository to `/sbbs/repo`
2. Builds using `make RELEASE=1 NOCAP=1 install` (NOCAP=1 for Docker)
3. Creates symlinks for read-only directories (text, xtrn, web, docs, webv4)
4. Copies ctrl/ (needs to be writable for config changes)
5. Ensures JavaScript files from repo/exec are available
6. Sets proper environment variables including LD_LIBRARY_PATH
7. Sets TERM=ansi-bbs for proper terminal handling
8. Compiles the ansi-bbs terminfo entry
9. Uses entrypoint.sh to inject environment variables at startup

## Building

```bash
./install.sh
```

## Running With Persistent Data

```bash
docker compose up -d
```

## Reconfiguring

```bash
docker exec -it SynchronetBBS /sbbs/exec/scfg
```

## Other Setting

* Set default shell to Oblivion/2

`main.ini`
```
[newuser]
    command_shell=OBV-2
```

* Disable IPV6

`sbbs.ini`
```
[Global]
Interface=0.0.0.0
```

---

### Configuring DOS Doors

## Auto Install

Under Doors > Operator > Auto-install New External Programs to configure other doors (Lord, Tradewars).

## Manual Configuration

1. In `sbbs.ini`, ensure `UseDOSemu=true` is set in the `[bbs]` section (the Dockerfile does this automatically)
2. Configure doors in SCFG under External Programs
3. DOS doors use these drive mappings:
   - D: = /sbbs/node1 (or current node)
   - E: = /sbbs/xtrn
   - F: = /sbbs/ctrl
   - G: = /sbbs/data
   - H: = /sbbs/exec

For more details, see: https://wiki.synchro.net/howto:raspbian_install

---

## Key Directories Explained

| Directory | Purpose | Mount as Volume? |
|-----------|---------|------------------|
| ctrl/ | Config files (sbbs.ini, etc.) | Yes - persists config |
| data/ | User data, messages, files | Yes - persists data |
| text/ | Menus, ANSI art, themes | Optional - if customizing |
| xtrn/ | Doors/external programs | Optional - if adding custom doors |
| mods/ | Custom JavaScript mods | Optional - for customizations |
| exec/ | Binaries + JS runtime | No - part of image |

## Ports

Default port mappings in docker-compose.yml:

| Host Port | Container Port | Service |
|-----------|----------------|---------|
| 10022 | 22 | SSH (Synchronet's built-in, not system SSH) |


Additional ports (uncomment in docker-compose.yml if needed):
| Port | Service |
|------|---------|
| 25 | SMTP |
| 110 | POP3 |
| 119 | NNTP |
| 10023 | 23 | Telnet |
| 10080 | 80 | HTTP Web Interface |
| 10443 | 443 | HTTPS |
| 10513 | 513 | RLogin |
| 10021 | 21 | FTP |

---

## Connecting with SyncTERM

SyncTERM is the recommended terminal for connecting to BBS systems. It properly displays ANSI art and handles door games correctly.

### Download SyncTERM

| Platform | Download |
|----------|----------|
| **Windows** | https://sourceforge.net/projects/syncterm/files/latest/download |
| **macOS** | https://syncterm.bbsdev.net/ (look for macOS build) |
| **Linux** | `sudo apt install syncterm` or download from https://syncterm.bbsdev.net/ |

### Connect to Your BBS

1. Open SyncTERM
2. Press **D** for Dialing Directory, then **E** to edit/add entry
3. Create a new entry:
   - **Name:** My BBS
   - **Address:** `localhost:10022` (or your server's IP)
   - **Connection Type:** SSH
   - **Screen Mode:** 80x25
4. Press **Escape** to save, select your entry and press **Enter**

**Quick connect:** Type the address directly: `localhost:10023`

### Tips
- Press **Alt+Enter** for fullscreen
- Use **80x25** screen mode for door games
- SyncTERM supports ANSI music!

---

## Alternative Terminals

| Terminal | Platform | URL |
|----------|----------|-----|
| **SyncTERM** | Win/Mac/Linux | https://syncterm.bbsdev.net/ |
| **NetRunner** | Windows | https://www.mysticbbs.com/downloads.html |
| **EtherTerm** | Win/Mac/Linux | https://github.com/M-griffin/EtherTerm |
| **Qodem** | Linux | http://qodem.sourceforge.net/ |

---

## Troubleshooting

### "DOS programs not supported" error
- Ensure `UseDOSemu=true` in `/sbbs/ctrl/sbbs.ini` under `[bbs]`
- DOSEMU2 must be installed for DOS doors

### Missing themes/menus
- Check that `/sbbs/text` is properly symlinked to `/sbbs/repo/text`
- Run `ls -la /sbbs/text/` to verify contents

### Doors not showing
- Check that `/sbbs/xtrn` is properly symlinked to `/sbbs/repo/xtrn`
- Configure doors in SCFG → External Programs

### Libraries not found
- Ensure `LD_LIBRARY_PATH` includes `/sbbs/exec`
- Check that `.so` files exist in `/sbbs/exec/`

### Container keeps restarting
- Run scfg to generate initial configuration: `./install.sh`
- Check logs: `docker logs SynchronetBBS`

### SSH key errors
- The entrypoint script handles SSH key generation
- If issues persist: `docker exec SynchronetBBS rm -f /sbbs/ctrl/cryptlib.key` then restart

---

## Security Notes

- **Never commit real passwords to git** - The install script sanitizes passwords automatically
- **Use environment variables** for sensitive data (SYSOP_PASSWORD)
- **The .gitignore** excludes sensitive files like `*.key`, `*.pem`, and data directories
- **Set strong passwords** in your production environment (Portainer, etc.)

---

## References

- Synchronet Wiki: http://wiki.synchro.net
- Raspberry Pi Install: https://wiki.synchro.net/howto:raspbian_install
- UNIX Installation: http://wiki.synchro.net/install:nix
- Prerequisites: http://wiki.synchro.net/install:nix:prerequisites

---
