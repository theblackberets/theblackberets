{
  description = "The Black Berets environment with Nix and just";

  inputs = {
    # OPTIMIZED: Use stable channel for faster, smaller downloads
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
        
        # Import configuration.nix as a proper Nix module
        # This replaces fragile bash parsing with type-safe Nix evaluation
        config = import ./configuration.nix { lib = pkgs.lib; };
        
        # Model download script (created via Nix, downloads on-demand)
        # Now uses values directly from configuration.nix via Nix evaluation
        llama3-8b-downloader = pkgs.writeShellScriptBin "download-llama3-8b" ''
          #!/usr/bin/env bash
          set -euo pipefail
          
          # Use values from configuration.nix (set via Nix evaluation)
          MODEL_DIR="''${1:-${config.ai.localAI.modelDir}}"
          MODEL_FILE="${config.ai.localAI.downloadModel.modelName}"
          MODEL_URL="${config.ai.localAI.downloadModel.modelUrl}"
          
          mkdir -p "$MODEL_DIR"
          cd "$MODEL_DIR" || exit 1
          
          if [ -f "$MODEL_FILE" ]; then
            echo "Model already exists: $MODEL_FILE"
            exit 0
          fi
          
          echo "Downloading $MODEL_FILE (~5GB)..."
          echo "URL: $MODEL_URL"
          
          # Check disk space
          if command -v df >/dev/null 2>&1; then
            AVAILABLE_MB=$(df -m . 2>/dev/null | tail -n1 | awk '{print $4}' || echo "0")
            if [ "$AVAILABLE_MB" -lt 6144 ] && [ "$AVAILABLE_MB" != "0" ]; then
              echo "WARNING: Low disk space (''${AVAILABLE_MB}MB available, need ~6GB)" >&2
            fi
          fi
          
          # Download with proper error handling
          DOWNLOAD_FAILED=0
          if command -v wget >/dev/null 2>&1; then
            timeout 7200 wget --show-progress --timeout=30 --tries=3 --continue "$MODEL_URL" -O "$MODEL_FILE" || DOWNLOAD_FAILED=1
          elif command -v curl >/dev/null 2>&1; then
            timeout 7200 curl -L --progress-bar --max-time 30 --retry 3 --retry-delay 5 -C - "$MODEL_URL" -o "$MODEL_FILE" || DOWNLOAD_FAILED=1
          else
            echo "ERROR: wget or curl not found" >&2
            exit 1
          fi
          
          if [ "$DOWNLOAD_FAILED" -eq 1 ] || [ ! -f "$MODEL_FILE" ]; then
            echo "ERROR: Download failed" >&2
            exit 1
          fi
          
          echo "✓ Model downloaded successfully: $MODEL_FILE"
        '';
        
      in
      {
        packages = {
          default = pkgs.just;
          just = pkgs.just;
          
          # Model download helper (uses Nix for deterministic download script)
          download-llama3-8b = llama3-8b-downloader;
          
          # Minimal Kali tools (fast install, essential tools only)
          kali-tools-minimal = pkgs.buildEnv {
            name = "kali-tools-minimal";
            paths = with pkgs; [
              # Network scanning (most essential)
              nmap
              netcat-gnu
              
              # Web security (essential)
              sqlmap
            ];
          };
          
          # Kali Linux security tools (OPTIMIZED: Essential tools only for lighter install)
          kali-tools = pkgs.buildEnv {
            name = "kali-tools";
            paths = with pkgs; [
              # Network scanning and analysis (essential)
              nmap
              tcpdump
              netcat-gnu
              
              # Web application security (essential)
              sqlmap
              nikto
              gobuster
              
              # Password cracking (essential)
              john
              hashcat
              
              # Wireless security (essential)
              aircrack-ng
              
              # Exploitation frameworks (lightweight)
              exploitdb
              
              # Forensics (lightweight)
              binwalk
              
              # Reverse engineering (lightweight)
              radare2
              gdb
              strace
              
              # Other security tools (essential)
              ettercap
              crackmapexec
            ];
          };
          
          # Full Kali tools (optional, install separately if needed)
          kali-tools-full = pkgs.buildEnv {
            name = "kali-tools-full";
            paths = with pkgs; [
              # Network scanning and analysis
              nmap
              wireshark
              tcpdump
              netcat-gnu
              masscan
              zmap
              
              # Web application security
              sqlmap
              nikto
              dirb
              gobuster
              wfuzz
              whatweb
              wpscan
              
              # Password cracking
              john
              hashcat
              hydra
              
              # Wireless security
              aircrack-ng
              reaver
              bully
              
              # Exploitation frameworks
              metasploit
              exploitdb
              
              # Forensics and analysis
              binwalk
              volatility3
              sleuthkit
              
              # Reverse engineering
              ghidra
              radare2
              gdb
              strace
              ltrace
              
              # Social engineering
              set
              
              # Vulnerability scanners
              openvas
              lynis
              
              # Other security tools
              burpsuite
              zap
              ettercap
              dnsenum
              enum4linux
              smbclient
              impacket
              crackmapexec
              bloodhound
              kerbrute
            ];
          };
        };

        # Development shell with environment variables and all tools
        # This replaces manual environment setup - just run: nix develop
        devShells.default = pkgs.mkShell {
          buildInputs = [
            pkgs.just
            # Network scanning
            pkgs.nmap
            pkgs.wireshark
            pkgs.tcpdump
            pkgs.netcat-gnu
            # Web security
            pkgs.sqlmap
            pkgs.nikto
            pkgs.gobuster
            # Password tools
            pkgs.john
            pkgs.hashcat
            pkgs.hydra
            # Wireless
            pkgs.aircrack-ng
            # Exploitation
            pkgs.metasploit
            # Forensics
            pkgs.binwalk
            # Reverse engineering
            pkgs.ghidra
            pkgs.radare2
            pkgs.gdb
            # Other
            pkgs.burpsuite
            pkgs.zap
            pkgs.ettercap
            pkgs.crackmapexec
            # Model download helper
            llama3-8b-downloader
          ];
          
          # Environment variables from configuration.nix (declarative!)
          # Now uses values directly from Nix evaluation instead of bash parsing
          shellHook = ''
            # Set LocalAI environment variables (from configuration.nix via Nix)
            export LOCAL_AI="${config.environment.LOCAL_AI}"
            export LOCALAI_PORT="${toString config.environment.LOCALAI_PORT}"
            export LOCALAI_MODEL_DIR="${config.environment.LOCALAI_MODEL_DIR}"
            export LOCALAI_CONFIG_DIR="${config.environment.LOCALAI_CONFIG_DIR}"
            
            # Model download script already in PATH via buildInputs
            
            echo "The Black Berets environment loaded"
            echo "  - Kali tools available"
            echo "  - Model download: download-llama3-8b [MODEL_DIR]"
            echo "  - Environment variables from configuration.nix (via Nix evaluation)"
            echo "  - Port: ${toString config.ai.localAI.defaultPort}"
            echo "  - Model dir: ${config.ai.localAI.modelDir}"
          '';
        };

        # System packages to install globally
        apps = {
          default = {
            type = "app";
            program = "${pkgs.just}/bin/just";
          };
          
          # Model download app (uses Nix derivation)
          download-llama3-8b = {
            type = "app";
            program = "${llama3-8b-downloader}/bin/download-llama3-8b";
          };
        };
        
        # Configuration outputs (NixOS-style)
        # This allows applying configuration.nix declaratively
        nixosConfigurations = {
          default = {
            system = "x86_64-linux";
            modules = [];
          };
        };
      }
    );
}

