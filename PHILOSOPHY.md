# The Black Berets - Core Philosophy

## Summary

**Justfile-First Architecture:**
- **`justfile`** = Main orchestrator (imports all feature justfiles, provides high-level commands)
- **Feature justfiles** = Module-specific recipes (nix/justfile, kali/justfile, localai/justfile, etc.)
- **`configuration.nix`** = Declarative configuration (defines everything: packages, LocalAI, MCP, environment)
- **`lib/`** = Shared libraries (bootstrap.sh loads all, config, validation, idempotency, logging, test)
- **`config/config-to-json.nix`** = Type-safe config parser (converts Nix config to JSON)
- **`kali/flake.nix`** = Nix package definitions (Kali tools)

**Workflow:** `curl -fsSL https://theblackberets.github.io/install.sh | doas bash` → `justdo start` → Hack

## Zero-Config, Justfile-First, Lean & Mean

### The Promise

**On a new computer: One command → Start hacking immediately.**

```bash
curl -fsSL https://theblackberets.github.io/install.sh | doas bash
# ✅ Pre-flight checks passed
# ✅ All files downloaded
# ✅ Modules installed and tested
# ✅ Post-install verification passed
# Installation complete!

justdo start             # Start LocalAI in background - works by default
justdo test              # Test environment - works by default
justdo analyze-nmap target.com  # Hack - works by default
```

**No configuration. No manual setup. No "read the docs first."**

**Robust Installation:**
- Pre-flight checks validate system before starting
- Each module tested immediately after installation
- Kali tools installation properly fails on errors (no silent failures)
- Post-install verification ensures everything works
- Clear error messages if anything fails

**All commands work by default** - No parameters required. Every `justdo` command has sensible defaults and works immediately without any configuration.

## Three Pillars

### 1. Zero-Config

**`curl -fsSL https://theblackberets.github.io/install.sh | doas bash` installs everything:**
- Pre-flight checks (system, network, disk space)
- Downloads all files (justfile, libraries, configs, modules)
- Installs modules with per-module testing:
  - Nix + just/justdo
  - Kali tools (from flake.nix)
  - LocalAI + llama.cpp
  - MCP server
- Post-install verification
- Environment configured automatically

**Robust Installation Process:**
1. **Pre-flight checks** - Validates system before starting
2. **Download phase** - Gets all required files (feature directories, libraries, configs)
3. **Installation phase** - Installs each module with immediate testing:
   - Nix installed → daemon started and verified → optimize-nix
   - just/justdo installed → environment setup → feature directories copied
   - Kali tools installed → Nix daemon verified → flake.nix found → profile add
   - LocalAI installed → binary downloaded → config created
   - MCP server installed → script copied to multiple locations
4. **Verification phase** - Comprehensive test ensures everything works

**`doas just configure` applies configuration:**
- Reads from `configuration.nix`
- Generates LocalAI config.yaml
- Downloads model if enabled
- Sets up all services

**What "Zero-Config" Means:**
- No configuration files to edit before use
- Sensible defaults for everything
- Works immediately after installation
- Auto-applied configuration during install
- Background services start automatically
- No manual intervention required
- **All `justdo` commands work by default** - No parameters needed
- Commands automatically use sensible defaults (ports, directories, etc.)
- Optional configuration via `configuration.nix` if you want to customize

**Configuration is Optional:**
- `configuration.nix` has sensible defaults
- Edit only if you want to customize
- Most users never need to touch it
- Commands work without configuration

### 2. Justfile-First

**`just` and `justdo` are PRIMARY interface for everything:**
- `doas just install` - Install everything
- `doas just configure` - Apply configuration
- `doas just cleanup` - Remove everything
- `justdo start` - Start LocalAI in background
- `justdo stop` - Stop LocalAI
- `justdo status` - Check service status
- `justdo test` - Comprehensive environment test
- `justdo start-mcp` - Start MCP server
- `justdo download-model` - Download model

**All Commands Work By Default:**
- **No parameters required** - All commands have sensible defaults
- `justdo download-model` - Works, uses `./models` by default
- `justdo start` - Works, uses port 8080 and default directories
- `justdo test` - Works, reads from configuration.nix if available
- `justdo status` - Works, checks all services
- **Zero-config defaults** - Every command works immediately without configuration
- **Optional parameters** - Can override defaults if needed, but not required
- **Configuration-aware** - Automatically reads from `configuration.nix` if available

**Why Justfile-First:**
- Single source of truth for all operations
- Consistent interface (just/justdo)
- Easy to discover commands (`just --list`)
- Self-documenting (recipes show what they do)
- Modular design (shared libraries)
- Type-safe config access (Nix evaluation)

**Architecture Benefits:**
- Feature-based modular design (each feature self-contained in its own directory)
- Main justfile orchestrates high-level commands (chat, install, start, stop, test, cleanup)
- Feature justfiles handle module-specific operations (install-*, start-*, stop-*, cleanup-*, test-*)
- Shared libraries for consistency (`lib/bootstrap.sh` loads all libraries)
- Type-safe config via Nix evaluation
- Idempotent operations (safe to rerun)
- Robust error handling and validation
- Per-module testing for fast feedback
- Pre-flight checks catch issues early
- Nix daemon properly managed (started, verified, optimized)
- Feature-specific cleanup before general cleanup

**Background Processes:**
- Services run automatically in background
- No manual process management needed
- Lightweight and efficient
- Can be controlled via `justdo` commands

### 3. Lean & Mean

**Code principles:**
- Every line must earn its place
- Shared libraries (no duplication)
- Type-safe config (Nix evaluation, no fragile parsing)
- Early exits (fail fast)
- Optimized operations
- Modular design

**What "Lean & Mean" Means:**
- **Minimal dependencies**: Only essential tools
- **Efficient code**: Optimized algorithms and patterns
- **Fast execution**: Caching, early exits, batch operations
- **No bloat**: Every feature has a purpose
- **Shared code**: DRY principle enforced via `lib/`
- **Resource efficient**: Lightweight services
- **Type-safe**: Nix evaluation instead of bash parsing

**Code Quality Standards:**
- Shared libraries for common operations (`lib/`)
- Type-safe config access (Nix → JSON → jq)
- Caching to avoid redundant work
- Early exits for common failure cases
- Batch operations when possible
- No code duplication
- Comprehensive error handling

**Performance Optimizations:**
- Config parser caches parsed values
- Nix evaluation cached (file hash check)
- File operations minimized
- Network calls optimized
- Background processes lightweight
- Resource cleanup automatic

**Architecture Benefits:**
- Modular design (shared libraries)
- Type-safe config (no fragile parsing)
- Consistent error handling
- Idempotent operations
- Easy to test and maintain

## Configuration-Driven (Zero-Config Defaults)

**`configuration.nix` has sensible defaults:**
- Kali tools: `enabled = true`
- LocalAI: `enabled = true`
- MCP server: `enabled = true`
- All paths configured automatically
- All ports have sensible defaults (8080)

**No editing needed. Works out of the box.**

**When to Edit Configuration:**
- Change LocalAI port (default: 8080, set in `configuration.nix` as `ai.localAI.defaultPort`)
- Disable certain tools
- Customize paths
- Adjust service settings
- Modify model download settings

**Configuration Features:**
- Single source of truth (`configuration.nix`)
- Declarative (NixOS-style)
- Type-safe access (Nix evaluation → JSON)
- Auto-applied during `just configure`
- Version controlled
- Optional (commands work without it)

**Config Access Pattern:**
```bash
# Source libraries
. lib/config.sh

# Get config value (uses Nix evaluation, falls back to defaults)
PORT=$(get_config "ai.localAI.defaultPort" "8080")
MODEL_DIR=$(get_config "ai.localAI.modelDir" "./models")
```

## Complete Cleanup

**`doas just cleanup` removes EVERYTHING:**

**Two-Phase Cleanup Process:**
1. **Feature-specific cleanup** - Each feature cleans up its own resources:
   - `cleanup-localai` → Stops LocalAI, removes binary, configs, models
   - `cleanup-mcp` → Stops MCP server, removes scripts and symlinks
   - `cleanup-kali` → Removes Kali tools from Nix profile
   - `cleanup-nix` → Stops daemon, removes Nix store, users, configs
   - `cleanup-just` → Removes justdo wrapper, bash completion, environment files
2. **General cleanup** - Removes shared resources:
   - Config files and directories
   - Temporary files and caches
   - Remaining processes
   - System-wide files

**After cleanup, system is clean.**

**What Gets Removed:**
- Nix package manager (store, profiles, users, daemon)
- just/justdo commands (all binaries, symlinks, wrappers)
- Kali tools (via Nix profile cleanup)
- LocalAI + llama.cpp (binaries, configs, models, logs)
- MCP server (scripts, symlinks, from all locations)
- Configuration files (all system configs, profile.d scripts)
- Environment variables (all traces)
- Service files (auto-update, etc.)
- Temporary files and caches
- Bash completion scripts
- Feature directories from system install location

**Idempotent Cleanup:**
- Safe to run multiple times
- Feature-specific cleanup runs first (handles module-specific resources)
- General cleanup runs after (handles shared resources)
- Checks before removing
- Handles partial installations gracefully
- No errors if already clean
- Works even if some components aren't installed

## Usage Flow

### New Computer

```bash
# 1. Install (one command, zero config)
curl -fsSL https://theblackberets.github.io/install.sh | doas bash
# ✅ Pre-flight checks passed
# ✅ All files downloaded
# ✅ Nix installed and tested
# ✅ just installed and tested
# ✅ Kali tools installed and tested
# ✅ LocalAI installed and tested
# ✅ MCP installed and tested
# ✅ Post-install verification passed
# ✅ Everything installed and verified

# 2. Configure (applies configuration.nix, downloads model if enabled)
doas just configure
# ✅ Configuration applied

# 3. Start services
justdo start              # Start LocalAI in background
justdo start-mcp          # Start MCP server

# 4. Test environment (optional - already tested during install)
justdo test               # Comprehensive test

# 5. Use (CLI-first)
justdo analyze-nmap target.com  # Hack
```

### Existing Installation

```bash
# Check status
justdo status             # Check all services

# Start services if needed
justdo start              # Start LocalAI in background
justdo start-mcp          # Start MCP server

# Use commands
justdo analyze-nmap target.com
```

### Cleanup

```bash
# Remove everything
doas just cleanup
# ✅ Everything removed, system clean
```

## Background Services

**Lightweight services run automatically:**
- MCP server → Runs in background automatically
- Nix daemon → Required for Nix
- LocalAI → Started via `justdo start`

**Process Management:**
- Services can be controlled via `justdo` commands
- Lightweight and efficient
- No manual intervention needed
- Status checked via `justdo status`

**Service Commands:**
- `justdo start` - Start all services (LocalAI, MCP) - smart detection, only starts if not running
- `justdo stop` - Stop all services
- `justdo start-localai` - Start LocalAI in background (detects if already running)
- `justdo stop-localai` - Stop LocalAI
- `justdo start-mcp` - Start MCP server in background (finds script in multiple locations, throws error if already running)
- `justdo stop-mcp` - Stop MCP server
- `justdo status` - Check status of all services

**Smart Service Management:**
- Services detect if already running (port check + process verification)
- LocalAI: Only starts if not already running (idempotent)
- MCP: Throws error if already running (prevents duplicate instances)
- Chat interface: Automatically checks for MCP server and attempts to start it if missing
- Clear error messages if scripts/files not found
- MCP script found in multiple locations (feature directories, system install)

## Testing

**Robust Testing Approach:**

**1. Pre-Flight Checks (Before Installation):**
- Root permissions
- Operating system compatibility
- Network connectivity
- Disk space availability
- Required commands (curl/wget)

**2. Per-Module Testing (During Installation):**
- Each module tested immediately after installation
- Module-specific test files (`nix/test.sh`, `localai/test.sh`, etc.)
- Fast feedback - know immediately if a module failed
- Clear error messages

**3. Post-Install Verification:**
```bash
justdo test
```

**Comprehensive environment test:**
- Core tools (Nix, just, justdo)
- Configuration files
- LocalAI setup (binary, config, model)
- MCP server
- Kali tools
- Services status
- Environment variables

**Module Test Structure:**
- Each feature module has its own `test.sh`
- Tests run automatically after module installation
- Uses shared test utilities from `lib/test.sh`
- Provides clear pass/fail/warning status

**Manual Testing:**
```bash
./manual-test.sh          # Docker-based testing
```

## Security & Legal

**Legal Use Only:**
- Only test systems you own
- Only test with explicit permission
- Unauthorized access is illegal
- Authors not responsible for misuse

**Security Best Practices:**
- Use in isolated environments
- Follow responsible disclosure
- Respect privacy and data
- Document all testing activities
- Report vulnerabilities responsibly

## Development Philosophy

**Code Standards:**
- `set -euo pipefail` in all scripts
- Shared libraries (`lib/`) for consistency
- Type-safe config access (Nix evaluation)
- Proper error handling (die, log_error, etc.)
- Resource cleanup (traps)
- Input validation (validate_port, validate_path, etc.)
- Idempotent operations (is_installed, is_port_in_use, etc.)

**Architecture Principles:**
- Justfile-first (all operations via recipes)
- Modular design (shared libraries)
- Type-safe config (Nix → JSON → jq)
- DRY principle (no code duplication)
- Fail fast (early validation)
- Clear error messages (actionable)

**Testing Approach:**
- Test on clean systems
- Verify zero-config installation
- Check cleanup removes everything
- Validate all commands work
- Ensure background services start
- Test idempotency (safe to rerun)

**Documentation:**
- Lean and mean (like code)
- Focus on usage, not theory
- Examples over explanations
- Quick start over deep dives

## Summary

**Zero-Config**: `curl -fsSL https://theblackberets.github.io/install.sh | doas bash` → Everything works  
**Justfile-First**: `just` and `justdo` commands → Primary interface (all work by default)  
**Lean & Mean**: Optimized code → Every line counts  
**Robust**: Pre-flight checks, per-module testing, post-install verification  
**Complete Cleanup**: `doas just cleanup` → Removes everything  

**On a new computer, you should be hacking in under 5 minutes.**

**Robust Installation:**
- Pre-flight checks validate system
- Per-module testing provides fast feedback
- Post-install verification ensures everything works
- Clear error messages if anything fails

**All `justdo` commands work by default** - No parameters needed. Sensible defaults for everything. Zero configuration required.

**That's it. Lean. Mean. Zero-config. Robust. Justfile-first.**
