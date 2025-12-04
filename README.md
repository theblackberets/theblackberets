# The Black Berets - Zero-Config Hacking Tool

**Zero-config security toolkit for Alpine Linux. Install once, hack immediately.**

## Architecture Summary

**Justfile-First Design:**
- **`justfile`** = Single source of truth for all operations (install, configure, start, stop, status, test, cleanup)
- **`configuration.nix`** = Declarative configuration (defines all packages, LocalAI, MCP, environment settings)
- **`lib/`** = Shared libraries (config, validation, idempotency, logging)
- **`config-to-json.nix`** = Type-safe config parser (converts Nix config to JSON)
- **`flake.nix`** = Nix package definitions (Kali tools)

**Flow:** `doas just install` → `just configure` → `justdo start` → Hack

## Quick Start

```bash
# Install everything (one command)
curl -fsSL https://theblackberets.github.io/install.sh | doas bash

# After installation:
justdo start             # Start LocalAI
justdo test              # Test environment
justdo analyze-nmap target.com  # Hack
```

## Installation

**Zero-config installation (one command):**
```bash
curl -fsSL https://theblackberets.github.io/install.sh | bash
```

Or with root privileges:
```bash
curl -fsSL https://theblackberets.github.io/install.sh | doas bash
```

**What happens:**
1. ✅ **Pre-flight checks** - Validates system, network, disk space
2. ✅ **Downloads all files** - Justfile, libraries, configs, modules
3. ✅ **Installs modules** - Nix, just, Kali tools, LocalAI, MCP (with per-module testing)
4. ✅ **Post-install verification** - Comprehensive test to ensure everything works

**Installs automatically:**
- ✅ Nix package manager
- ✅ just/justdo commands
- ✅ Kali tools (from flake.nix)
- ✅ LocalAI + llama.cpp
- ✅ MCP server
- ✅ Environment configured

**Robust Installation:**
- Pre-flight checks catch issues before installation
- Nix daemon properly started and verified before use
- Each module tested immediately after installation
- Kali tools installation properly fails on errors (no silent failures)
- Post-install verification ensures everything works
- Clear error messages if anything fails
- Feature-specific cleanup before general cleanup

**Configuration:**
```bash
doas just configure      # Apply configuration.nix (downloads model if enabled)
```

## Usage (Justfile-First)

**Primary interface: `justdo` commands**

### Service Management
```bash
justdo start             # Start all services (LocalAI, MCP)
justdo stop              # Stop all services
justdo start-localai     # Start LocalAI server (default port from configuration.nix, default: 8080)
justdo stop-localai      # Stop LocalAI server
justdo start-mcp         # Start MCP server
justdo stop-mcp          # Stop MCP server
justdo status            # Check status of all services
```

**Smart Start Logic:**
- Detects if services are already running (checks port and process)
- LocalAI: Only starts if not already running (idempotent)
- MCP: Throws error if already running (prevents duplicate instances)
- Chat interface: Automatically checks for MCP server and attempts to start it if missing
- Verifies process is actually the expected service
- Provides clear status messages

### Testing
```bash
justdo test              # Comprehensive environment test
```

### Model Management
```bash
justdo download-model    # Download model (uses ./models by default)
```

**All commands work by default** - No parameters required. Sensible defaults for ports, directories, and all settings.

## Cleanup

**Remove everything:**
```bash
doas just cleanup
```

**Cleanup Process:**
1. **Feature-specific cleanup** - Each feature cleans up its own resources:
   - `cleanup-localai` - Stops LocalAI, removes binary and configs
   - `cleanup-mcp` - Stops MCP server, removes scripts
   - `cleanup-kali` - Removes Kali tools from Nix profile
   - `cleanup-nix` - Stops daemon, removes Nix store
   - `cleanup-just` - Removes justdo wrapper and files
2. **General cleanup** - Removes shared configs, temp files, and system files

**Removes:** Nix, just, Kali tools, LocalAI, MCP, configs, all files

## File Structure

**Feature-Based Organization:**
- **`install.sh`** - Robust installer with pre-checks, per-module tests, and verification
- **`justfile`** - Main orchestrator (imports all feature justfiles, provides high-level commands)
- **`lib/`** - Shared libraries (bootstrap.sh loads all libraries, config, validation, idempotent, logging, test)
- **`config/`** - Configuration files (configuration.nix, config-to-json.nix)

**Feature Modules (self-contained):**
- **`nix/`** - Nix package manager (justfile with install-nix, optimize-nix, cleanup-nix, test-nix)
- **`just/`** - just/justdo command runner (justfile with install-just, setup-environment, cleanup-just, test-just)
- **`kali/`** - Kali tools (justfile with install-kali-tools, cleanup-kali, test-kali, flake.nix)
- **`localai/`** - LocalAI server (justfile with install-localai, start-localai, stop-localai, cleanup-localai, test-localai, chat.py)
- **`mcp/`** - MCP server (justfile with install-mcp, start-mcp, stop-mcp, cleanup-mcp, test-mcp, mcp-kali-server.py)
- **`models-management/`** - Model management (justfile with download-model, test-models)
- **`services/`** - Service management (justfile with service recipes)
- **`test/`** - Testing utilities (justfile with test-all, comprehensive tests)

**Note:** `models/` directory is gitignored (for downloaded model files), but `models-management/` contains the justfile (tracked in git)

**Each module contains:**
- `justfile` - Module-specific recipes (install, start, stop, test, cleanup)
- `test.sh` - Module-specific tests (run after installation)
- Module-specific files (scripts, configs, etc.)

**Main justfile provides:**
- High-level orchestration: `chat`, `install`, `status`, `start`, `stop`, `test`, `cleanup`
- Delegates to feature-specific recipes for granular control

## Architecture

**Feature-Based Modular Design:**
- Each feature is self-contained in its own directory
- Shared libraries in `lib/` directory for consistency
- Type-safe config via Nix evaluation (no fragile parsing)
- Modular - each feature has single responsibility
- Idempotent - safe to rerun any command
- Robust - comprehensive error handling and validation

**Robust Installation:**
- **Pre-flight checks** - Validates system before installation
- **Per-module testing** - Each module tested immediately after installation
- **Post-install verification** - Comprehensive test ensures everything works
- **Clear error messages** - Know exactly what failed and why

**Configuration Access:**
- Uses Nix evaluation (`config/config-to-json.nix`) instead of bash parsing
- Type-safe JSON access via `lib/config.sh`
- Centralized library loading via `lib/bootstrap.sh`
- Falls back to sensible defaults if config not found
- All commands work without configuration

**Library Loading:**
- `lib/bootstrap.sh` - Centralized loader for all libraries
- Automatically finds and loads libraries from multiple locations
- Works from any directory (project root, feature directories, system install)

## Philosophy

**Zero-Config**: `doas just install` → Everything works  
**Justfile-First**: `just` and `justdo` commands → Primary interface  
**Lean & Mean**: Optimized code → Every line counts  

See `PHILOSOPHY.md` for details.

## Manual Testing

**Docker-based testing:**
```bash
./manual-test.sh
```

Inside container:
```bash
cd /root/project && justdo test      # Run comprehensive tests
cd /root/project && justdo status    # Check status
cd /root/project && doas just cleanup # Cleanup everything
```

## Legal

**Only use on systems you own or have explicit permission to test.**
