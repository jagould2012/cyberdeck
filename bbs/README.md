# ENiGMA½ BBS with DOS Door Games

## First-Time Setup

### Step 1: Build the Container
```bash
docker compose build
```

### Step 2: Run Initial Configuration

The first time you run ENiGMA½, you need to run it interactively to complete the setup wizard:
```bash
docker compose run -it --rm enigma-bbs ./oputil.js config new
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

---

## Directory Structure
```
bbs/
├── Dockerfile
├── docker-compose.yml
├── dosemu/
│   ├── dosemu.conf
│   └── autoexec.bat
├── scripts/
│   ├── lord.sh
│   └── tw2002.sh
└── doors/
    ├── lord/        <- Put LORD game files here
    ├── tw2002/      <- Put TradeWars 2002 files here
    └── dropfiles/
```

## Adding Door Games

1. Download door games:
   - LORD: https://www.gameport.com/bbs/lord.html
   - TradeWars: https://www.eisonline.com/downloads/

2. Extract to `doors/lord/` and `doors/tw2002/`

3. Rebuild: `docker compose build`

## ENiGMA Menu Config

Add to your `config/<bbsname>-doors.hjson`:
```hjson
doorLord: {
    desc: Legend of the Red Dragon
    module: abracadabra
    config: {
        name: LORD
        dropFileType: DOOR
        cmd: /enigma-bbs/doors/lord.sh
        args: [ "{node}" ]
        nodeMax: 10
        io: stdio
    }
}

doorTradeWars: {
    desc: TradeWars 2002
    module: abracadabra
    config: {
        name: TW2002
        dropFileType: DOOR
        cmd: /enigma-bbs/doors/tw2002.sh
        args: [ "{node}" ]
        nodeMax: 10
        io: stdio
    }
}
```

---

## Alternative Terminals

- **NetRunner** - https://www.mysticbbs.com/downloads.html
- **EtherTerm** - https://github.com/M-griffin/EtherTerm
- **Qodem** - http://qodem.sourceforge.net/

Basic telnet (no ANSI graphics):
```bash
telnet localhost 8888
```

---

## Troubleshooting

### Container keeps exiting with code 130
Run interactively first to complete setup:
```bash
docker compose run -it enigma-bbs
```

### Can't connect to BBS
- Verify container is running: `docker compose ps`
- Check logs: `docker compose logs -f`
- Ensure port 8888 is not blocked

### ANSI graphics look wrong
- Use SyncTERM or another BBS terminal
- Set screen mode to 80x25

### Door games not working
- Verify game files are in `doors/` subdirectory
- Rebuild after adding files: `docker compose build`
- Check logs: `docker compose logs -f`