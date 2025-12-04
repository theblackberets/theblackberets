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
      in
      {
        packages = {
          default = pkgs.just;
          just = pkgs.just;
          
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

        # Development shell with just and Kali tools
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
          ];
        };

        # System packages to install globally
        apps = {
          default = {
            type = "app";
            program = "${pkgs.just}/bin/just";
          };
        };
      }
    );
}

