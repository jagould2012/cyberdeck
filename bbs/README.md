# ENiGMA½ BBS with DOS Door Games

A Docker-based ENiGMA½ BBS setup with DOS door game support via dosemu2.

## First-Time Setup

### Step 1: Build the Container
```bash
docker compose build
```

> **Note:** The Dockerfile includes a patch to fix the ARM64 segfault [issue](https://github.com/NuSkooler/enigma-bbs/issues/620) discovered during testing. This fix loads `sharp` before `sqlite3` to prevent a native module conflict on ARM64 Linux systems.

### Step 2: Run Initial Configuration

The first time you run ENiGMA½, you need to run it interactively to complete the setup wizard:
```bash
docker run -it --rm \
  -v $(pwd)/config:/enigma-bbs/config \
  -v $(pwd)/db:/enigma-bbs/db \
  -v $(pwd)/logs:/enigma-bbs/logs \
  -v $(pwd)/filebase:/enigma-bbs/filebase \
  -v $(pwd)/art:/enigma-bbs/art \
  -v $(pwd)/mods:/enigma-bbs/mods \
  -v $(pwd)/mail:/enigma-bbs/mail \
  -v $(pwd)/doors:/enigma-bbs/doors \
  bbs-enigma-bbs \
  node oputil.js config new
```

When prompted "Create a new configuration? (y/N)", type **y** and press Enter.

Follow the prompts to configure:
- BBS name
- Sysop (your) name  
- Message conferences and areas
- Other settings

This creates your config files in the `./config` volume.

### Step 3: Start the BBS

After initial setup, start normally:
```bash
docker compose up -d
```

### Step 4: Create Your SysOp Account

1. Connect to your BBS using SyncTERM (see below)
2. At the welcome screen, select **"Apply"** (not "Login")
3. Fill out the new user application
4. **The first user created automatically becomes the SysOp** with full admin privileges

> **Important:** Create your admin account before anyone else connects!

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
   - **Address:** `localhost:8888` (or your server's IP)
   - **Connection Type:** Telnet
   - **Screen Mode:** 80x25
4. Press **Escape** to save, select your entry and press **Enter**

**Quick connect:** Type the address directly: `localhost:8888`

### Tips
- Press **Alt+Enter** for fullscreen
- Use **80x25** screen mode for door games
- SyncTERM supports ANSI music!


## Adding Door Games

### Hosting Door Games

Configuring Dosemu, QEMU, etc to run dos based doors on ARM64 Linux turned into a couple of long nights with no success. However, Synchronet BBS has ported many classic doors (Lord, Tradewars) to Javascript. It can be used as a standalone game server with Enigma in front using rlogin.

The game server Dockerfile is included to build Synchronet for ARM64.

To customize the configuration:

```
docker compose up -d gameserver
docker exec -it GameServer /sbbs/exec/scfg
```

Recommended config:

* External Programs → Online Programs (Doors) - LORD and others should already be there
* System → Toggle Options:
	* Set "Allow Login by User Number" = Yes
* Networks → RLogin (or in sbbs.ini):
	* Enable RLogin server
	* Set to allow passwordless login from trusted hosts
* System → New User Options:
	* Auto-create users from RLogin

### Configure Doors in ENiGMA

Add door definitions to your menu file (e.g., `config/menus/<bbsname>-doors.hjson`):

```
cat > ~/bbs/config/menus/cyberdeck-doors.hjson << 'EOF'
{
	menus: {
		doorsMainMenu: {
            desc: Doors Menu
            art: DOORMNU
            prompt: menuCommand
            config: {
                interrupt: realtime
            }
            submit: [
                {
                    value: { command: "G" }
                    action: @menu:fullLogoffSequence
                }
                {
                    value: { command: "Q" }
                    action: @systemMethod:prevMenu
                }
                {
                    value: { command: "L" }
                    action: @menu:doorLORD
                }
                {
                    value: { command: "T" }
                    action: @menu:doorTradeWars
                }
            ]
        }

        doorLORD: {
            desc: Legend of the Red Dragon
            module: abracadabra
            config: {
                name: LORD
                dropFileType: DOOR
                cmd: /usr/local/bin/lord.sh
                args: [
                    "{node}"
                ]
                nodeMax: 1
                tooManyArt: DOORMANY
                io: stdio
            }
        }

        doorTradeWars: {
            desc: Trade Wars 2002
            module: abracadabra
            config: {
                name: Trade Wars 2002
                dropFileType: DOOR
                cmd: /usr/local/bin/tw2002.sh
                args: [
                    "{node}"
                ]
                nodeMax: 1
                tooManyArt: DOORMANY
                io: stdio
            }
        }
	}
}
EOF

```

### Add a Door Menu

Create a menu for users to select door games:

```hjson
doorMenu: {
    desc: Door Games
    art: DOORMENU
    form: {
        0: {
            mci: {
                VM1: {
                    items: [
                        { text: "Legend of the Red Dragon", data: "lord" }
                        { text: "Trade Wars 2002", data: "tw2002" }
                    ]
                }
            }
            submit: {
                *: [
                    {
                        value: { "1": "lord" }
                        action: @menu:doorLord
                    }
                    {
                        value: { "1": "tw2002" }
                        action: @menu:doorTradeWars
                    }
                ]
            }
        }
    }
}
```

---

## Alternative Terminals

| Terminal | Platform | URL |
|----------|----------|-----|
| **SyncTERM** | Win/Mac/Linux | https://syncterm.bbsdev.net/ |
| **NetRunner** | Windows | https://www.mysticbbs.com/downloads.html |
| **EtherTerm** | Win/Mac/Linux | https://github.com/M-griffin/EtherTerm |
| **Qodem** | Linux | http://qodem.sourceforge.net/ |

Basic telnet (no ANSI graphics):
```bash
telnet localhost 8888
```

---

## Volumes & Ports

### Mounted Volumes
| Volume | Purpose |
|--------|---------|
| `./config` | BBS configuration files |
| `./db` | Database files |
| `./logs` | Log files |
| `./filebase` | File area storage |
| `./art` | ANSI art files |
| `./mods` | Custom modules |
| `./mail` | Message networks |
| `./doors` | Door game files |

### Ports
| Port | Protocol | Purpose |
|------|----------|---------|
| 8888 | Telnet | Default BBS access |

Add more ports in `docker-compose.yml` for SSH or other protocols.

---

## Troubleshooting

### Container keeps exiting with code 130
Run interactively first to complete setup:
```bash
docker compose run -it enigma-bbs
```

### Container exits with code 139 (Segfault)
This is the sharp/sqlite3 conflict on ARM64. The Dockerfile should already include the fix, but if running natively (not in Docker), apply manually:
```bash
sed -i '2a\\n// WORKAROUND: Load sharp before sqlite3 to prevent ARM64 segfault\ntry { require('\''sharp'\''); } catch(e) {}\n' main.js
```

### Can't connect to BBS
- Verify container is running: `docker compose ps`
- Check logs: `docker compose logs -f`
- Ensure port 8888 is not blocked by firewall

### ANSI graphics look wrong
- Use SyncTERM or another BBS terminal (not regular telnet)
- Set screen mode to 80x25
- Ensure terminal character set is CP437

### Door display issues
- Ensure your terminal supports CP437 character set
- Use 80x25 screen mode
- SyncTERM handles DOS door output best

---

## Useful Commands

```bash
# View logs
docker compose logs -f

# Enter container shell
docker compose exec enigma-bbs bash

# Restart BBS
docker compose restart

# Stop BBS
docker compose down

# Rebuild after changes
docker compose build && docker compose up -d

# Run oputil (user management, etc.)
docker compose exec enigma-bbs ./oputil.js user list
docker compose exec enigma-bbs ./oputil.js user pw <username>
```

---

## Resources

- **ENiGMA½ Documentation:** https://nuskooler.github.io/enigma-bbs/
- **ENiGMA½ GitHub:** https://github.com/NuSkooler/enigma-bbs
- **DOS Game Archives:** https://www.bbsarchive.org/
- **BBS Documentary:** https://www.bbsdocumentary.com/