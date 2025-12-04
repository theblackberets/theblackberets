# The Black Berets - Declarative System Configuration
# This is now a proper Nix module that can be imported by flake.nix
# All configuration is in one place, accessible via Nix

{ lib, ... }:

{
  # System packages to install via Nix
  packages = {
    # Core tools
    just = true;  # Command runner
    
    # Kali Linux security tools suite (installed by default)
    kali-tools = true;  # Essential security tools
    
    # Optional: Full Kali tools suite (set to false to use lighter version)
    kali-tools-full = false;
  };
  
  # System paths and directories
  paths = {
    # Base directory for The Black Berets files
    baseDir = "/usr/local/share/theblackberets";
    
    # Default justfile location
    defaultJustfile = "/usr/local/share/theblackberets/justfile";
    
    # Nix profile locations (auto-detected, but can override)
    nixProfile = "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh";
    nixProfileAlt = "/etc/profile.d/nix.sh";
    
    # System bin directories
    systemBin = "/usr/local/bin";
    userBin = "/usr/bin";
    
    # PATH additions (packages from flake.nix are automatically in PATH)
    pathAdditions = [];
  };
  
  # AI/LocalAI configuration (installed by default)
  ai = {
    # LocalAI setup
    localAI = {
      enabled = true;  # Install LocalAI by default
      installLlamaCpp = true;  # Install llama.cpp by default
      setupConfig = true;  # Setup LocalAI config by default
      
      # LocalAI server settings
      defaultPort = 8080;
      bindAddress = "0.0.0.0";
      
      # Directory configuration
      modelDir = "./models";
      configDir = "./localai-config";
      imagesDir = "./localai-config/images";
      
      # LocalAI config.yaml settings
      config = {
        threads = 4;
        contextSize = 4096;
        f16 = true;
        debug = true;
        modelName = "llama-3-8b";
        backend = "llama-cpp";
        modelFile = "llama-3-8b-instruct-q4_k_m.gguf";
        temperature = 0.7;
        topP = 0.9;
        topK = 40;
        stopSequences = [ "<|eot_id|>" "<|end_of_text|>" ];
      };
      
      # Model download configuration (zero-config: downloads automatically)
      downloadModel = {
        enabled = true;  # Download model automatically during install
        modelUrl = "https://huggingface.co/bartowski/Llama-3-8B-Instruct-GGUF/resolve/main/llama-3-8b-instruct-q4_k_m.gguf";
        modelName = "llama-3-8b-instruct-q4_k_m.gguf";
        downloadInBackground = true;  # Download in background (doesn't block install)
        verifyChecksum = false;  # Skip checksum verification (faster)
      };
    };
  };
  
  # Environment variables
  environment = {
    # LocalAI environment variables
    LOCAL_AI = "http://localhost:8080";
    LOCALAI_PORT = "8080";
    LOCALAI_MODEL_DIR = "./models";
    LOCALAI_CONFIG_DIR = "./localai-config";
    
    # Nix environment
    NIX_PATH = "";
    NIX_PROFILES = "";
    
    # Custom environment variables
    custom = {};
  };
  
  # Auto-update configuration
  autoUpdate = {
    enabled = true;
    checkInterval = 300;  # Check every 5 minutes (in seconds)
    gitRepository = "https://github.com/theblackberets/theblackberets.github.io.git";
    gitBranch = "main";
    flakePath = "./flake.nix";
    configurationPath = "./configuration.nix";
    repoDir = "/usr/local/share/theblackberets";
    logFile = "/var/log/nix-auto-update.log";
    pidFile = "/var/run/nix-auto-update.pid";
  };
  
  # MCP Server configuration
  mcp = {
    enabled = true;  # Install and start MCP server by default
    autoStart = true;  # Start automatically after install
    scriptPath = "/usr/local/share/theblackberets/mcp-kali-server.py";
    binaryPath = "/usr/local/bin/mcp-kali-server";
  };
  
  # System services
  services = {
    # Nix daemon (required for Nix to work)
    nix-daemon = {
      enabled = true;
      autoStart = true;
      serviceFile = "/etc/init.d/nix-daemon";
    };
    
    # Auto-update service (watches for changes and applies them)
    nix-auto-update = {
      enabled = true;
      autoStart = true;
      serviceFile = "/etc/init.d/nix-auto-update";
      dependsOn = [ "nix-daemon" ];
    };
    
    # MCP server (runs in background)
    mcp-server = {
      enabled = true;
      autoStart = true;
      scriptPath = "/usr/local/share/theblackberets/mcp-kali-server.py";
    };
  };
  
  # System configuration
  system = {
    # Nix configuration
    nix = {
      enableFlakes = true;
      experimentalFeatures = [ "nix-command" "flakes" ];
      autoOptimiseStore = true;
      maxJobs = "auto";  # "auto" or number
      buildCores = 0;  # 0 = use all available
    };
    
    # Chromebook optimizations (auto-detected)
    chromebook = {
      optimizeBuilds = true;
      maxBuildJobs = 2;  # Limited for Chromebook hardware
      buildMemoryMB = 2048;  # Max memory for builds
    };
  };
  
  # Logging and monitoring
  logging = {
    enabled = true;
    logDir = "/var/log";
    logLevel = "info";  # debug, info, warning, error
    rotateLogs = true;
    maxLogSize = "10M";
    keepLogs = 7;  # days
  };
}
