# Convert configuration.nix to JSON for type-safe config access
# Usage: nix eval --json -f config-to-json.nix

let
  config = import ./configuration.nix { lib = import <nixpkgs/lib>; };
in
builtins.toJSON config

