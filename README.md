# The Black Berets - Security Tools Repository

A comprehensive security toolkit for Alpine Linux with Nix package management, Kali Linux tools, LocalAI integration, and AI-assisted penetration testing capabilities.

## Quick Start

```bash
# One-command installation
doas ./install.sh

# Or download and run
wget -qO- https://theblackberets.github.io/install.sh | doas sh
```

## Repository Structure

- `install.sh` - Main installation script (Nix + just)
- `cleanup.sh` - System cleanup script (removes UI/desktop components)
- `justfile` - All commands and workflows
- `flake.nix` - Nix flake configuration (Kali tools + just)
- `mcp-kali-server.py` - MCP server for AI assistant integration

## Installation

### System Requirements

- Alpine Linux (or compatible Linux distribution)
- Root privileges (doas or sudo)
- Internet connection (for initial setup)

### Install Script

The `install.sh` script sets up:

1. **System Dependencies**: bash, curl, xz, git, ca-certificates, shadow, sudo
2. **Nix Package Manager**: Multi-user mode installation
3. **just Command Runner**: Installed globally via Nix flake
4. **Environment Configuration**: System profile setup, wrapper scripts

```bash
# Run installer
doas ./install.sh

# Verify installation
nix --version
just --version
just --list
```

### Idempotent Installation

The installer is **safe to rerun** - it checks for existing installations and only installs what's missing. It also automatically updates flake inputs and reinstalls packages when `flake.nix` is detected, ensuring latest changes are applied.

## Flake.nix Management

### Automatic Updates

The repository uses Nix flakes for package management. Any updates to `flake.nix` are automatically applied:

- **During installation**: `install.sh` automatically updates flake inputs and reinstalls packages
- **Manual update**: Run `just update-from-flake` to update all packages from latest flake.nix

### Update Commands

```bash
# Update all packages from latest flake.nix
just update-from-flake

# Update just from flake.nix (automatic during install)
# Update kali-tools from flake.nix (automatic during install-kali-tools)
```

### Flake Packages

- `.#just` - just command runner
- `.#kali-tools` - Complete Kali Linux security tools suite

## Core Commands

### Installation Commands

```bash
just install              # Download and run install.sh
just install-kali-tools   # Install Kali tools via Nix flake
just install-mcp-server   # Install MCP server for AI assistants
just update-from-flake    # Update all packages from latest flake.nix
```

### System Management

```bash
doas ./cleanup.sh         # Remove UI/desktop components and clean system
just --list               # List all available commands
```

## Kali Linux Security Tools

### Installation

```bash
just install-kali-tools
```

Automatically updates flake inputs and installs/updates from latest `flake.nix`.

### Available Tools

**Network Scanning:**
- `nmap`, `masscan`, `zmap` - Port scanners
- `wireshark`, `tcpdump` - Packet analyzers

**Web Security:**
- `sqlmap` - SQL injection testing
- `nikto`, `dirb`, `gobuster`, `wfuzz` - Web scanners
- `burpsuite`, `zap` - Web security platforms

**Password Cracking:**
- `john`, `hashcat`, `hydra` - Password tools

**Wireless:**
- `aircrack-ng`, `reaver`, `bully` - WiFi security tools

**Exploitation:**
- `metasploit`, `exploitdb` - Exploitation frameworks

**Forensics:**
- `binwalk`, `volatility3`, `sleuthkit` - Forensics tools

**Reverse Engineering:**
- `ghidra`, `radare2`, `gdb` - RE frameworks

**Other:**
- `ettercap`, `crackmapexec`, `bloodhound`, `kerbrute` - Additional security tools

### Usage

```bash
# Tools are available in PATH after installation
nmap -sS target.com
sqlmap -u "http://target.com/page?id=1"
john --wordlist=wordlist.txt hashfile.txt

# Enter development shell with all tools
nix develop
```

## LocalAI + Llama 3 8B Setup

### Quick Setup

```bash
# Full setup (llama.cpp + LocalAI + config)
just setup

# Download model (manual - see below)
just download-llama3-8b

# Run LocalAI server
just run
```

### Setup Commands

```bash
just install-llamacpp          # Install/update llama.cpp
just install-localai          # Install LocalAI binary
just setup-localai-config     # Create LocalAI configuration
just setup                    # Full setup (all above)
```

### Model Commands

```bash
just download-llama3-8b [MODEL_DIR]              # Download Llama 3 8B (manual)
just convert-model MODEL_PATH MODEL_OUTPUT        # Convert to GGUF
just quantize-model MODEL_INPUT MODEL_OUTPUT     # Quantize model
```

### Run Commands

```bash
just run [MODEL_DIR] [CONFIG_DIR] [PORT]          # Run LocalAI server
just run-localai [MODEL_DIR] [CONFIG_DIR] [PORT] # Run directly
just test-api [PORT]                             # Test API endpoint
```

### Model Download

Download Llama 3 8B manually:

```bash
# Using Hugging Face CLI
pip install huggingface-cli
huggingface-cli download bartowski/Llama-3-8B-Instruct-GGUF \
  llama-3-8b-instruct-q4_k_m.gguf --local-dir ./models

# Or place GGUF file at: ./models/llama-3-8b-instruct-q4_k_m.gguf
```

### Configuration

LocalAI config: `./localai-config/config.yaml`

- `threads`: CPU threads (default: 4)
- `context_size`: Context window (default: 4096)
- `temperature`: Model temperature (default: 0.7)

## AI-Assisted Security Commands

### Analysis Commands

```bash
just analyze-nmap TARGET [PORT]           # Nmap scan + AI analysis
just analyze-sqlmap URL [PORT]           # SQL injection test + AI
just analyze-hash HASH_FILE [PORT]       # Hash analysis + AI
just security-report SCAN_TYPE DATA [PORT] # Generate security report
```

### AI Assistance

```bash
just ask-security-tool TOOL QUESTION [PORT]  # Get tool usage guidance
just security-checklist TARGET [PORT]        # Generate testing checklist
just pentest-ai TARGET [PORT]               # AI-guided pentest workflow
```

### Usage Example

```bash
# Terminal 1: Start LocalAI
just run

# Terminal 2: Run AI-assisted scans
just analyze-nmap example.com
just pentest-ai example.com
just ask-security-tool nmap "How do I perform a stealth scan?"
```

## WiFi Password Cracking

### Usage

```bash
# Basic usage (requires root)
doas just crack-wifi INTERFACE BSSID WORDLIST

# Quick crack with default wordlist
doas just crack-wifi-quick INTERFACE BSSID

# With AI analysis (if LocalAI running)
doas just crack-wifi INTERFACE BSSID WORDLIST PORT=8080
```

### Workflow

```bash
# 1. Scan for networks
doas airodump-ng wlan0

# 2. Find target BSSID
doas airodump-ng wlan0 | grep "NetworkName"

# 3. Crack password
doas just crack-wifi wlan0 AA:BB:CC:DD:EE:FF wordlist.txt
```

### What It Does

1. Puts interface in monitor mode
2. Captures WPA/WPA2 handshake
3. Sends deauth packets to force reconnection
4. Cracks password with wordlist
5. Optional: AI analysis of password strength

**Legal Warning**: Only use on networks you own or have explicit permission to test.

## MCP Server (AI Assistant Integration)

### Installation

```bash
just install-mcp-server
```

### Configuration

Add to your AI assistant MCP settings (Cursor/Claude Desktop):

```json
{
  "mcpServers": {
    "kali-tools": {
      "command": "python3",
      "args": ["/path/to/mcp-kali-server.py"]
    }
  }
}
```

### Available MCP Tools

- `nmap_scan` - Network scanning
- `sqlmap_scan` - SQL injection testing
- `gobuster_scan` - Directory brute-forcing
- `analyze_with_localai` - AI analysis of results
- `hash_identify` - Hash type identification
- `john_crack` - Password cracking
- `wifi_scan` - WiFi network scanning
- `aircrack_crack` - WiFi password cracking

### Usage

Once configured, ask your AI assistant:

```
"Scan example.com with nmap and analyze results with LocalAI"
"Test http://example.com for SQL injection vulnerabilities"
"Perform directory brute-force on http://example.com"
```

### Run Server

```bash
just run-mcp-server
# Or manually
python3 mcp-kali-server.py
```

## System Cleanup

### Cleanup Script

```bash
doas ./cleanup.sh
```

Removes:
- UI/Desktop packages and dependencies
- Service files (lightdm, sddm, gdm, etc.)
- User accounts (configurable list)
- Temporary files and caches
- UI-related directories and configs

### Configuration

Edit `cleanup.sh` to customize:
- `USERS_TO_DELETE` - Users to remove
- `PACKAGES_TO_REMOVE` - Packages to uninstall
- `SERVICES_TO_DISABLE` - Services to stop/remove

## Complete Workflow Example

```bash
# 1. Install system
doas ./install.sh

# 2. Install Kali tools
just install-kali-tools

# 3. Setup LocalAI
just setup
just download-llama3-8b  # Manual download required

# 4. Start LocalAI (Terminal 1)
just run

# 5. Run AI-assisted security tests (Terminal 2)
just analyze-nmap target.com
just pentest-ai target.com
just security-checklist target.com

# 6. Update from latest flake.nix
just update-from-flake
```

## Requirements

- **OS**: Alpine Linux (or compatible)
- **Package Manager**: Nix (installed via install.sh)
- **Command Runner**: just (installed via install.sh)
- **Build Tools**: make, gcc, git (for llama.cpp)
- **Memory**: 8GB+ RAM recommended for Llama 3 8B
- **Root**: Required for WiFi cracking, some network tools

## File Locations

- **Default justfile**: `/usr/local/share/theblackberets/justfile`
- **Nix profile**: `/nix/var/nix/profiles/default/`
- **LocalAI config**: `./localai-config/config.yaml`
- **Models directory**: `./models/`
- **MCP server**: `./mcp-kali-server.py`

## Troubleshooting

### Nix not found after installation

```bash
source /etc/profile
# Or restart shell
```

### just command not found

```bash
# Check if wrapper exists
ls -la /usr/local/bin/just

# Source Nix profile
source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
```

### Flake updates not applying

```bash
# Force update
just update-from-flake

# Or manually
nix flake update
nix profile install .#just --reinstall
nix profile install .#kali-tools --reinstall
```

### LocalAI not starting

```bash
# Check if model exists
ls -la ./models/*.gguf

# Check config
cat ./localai-config/config.yaml

# Verify port not in use
lsof -i :8080
```

## License

See LICENSE file for details.

## Legal Notice

**Only use these tools on systems you own or have explicit written permission to test.** Unauthorized access to computer systems is illegal. The authors are not responsible for misuse of these tools.
