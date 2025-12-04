#!/usr/bin/env bash
# Bash completion for justdo command
# Provides tab completion for justdo recipes

_justdo_completion() {
    local cur prev words cword
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    words=("${COMP_WORDS[@]}")

    # Find the default justfile location
    local justfile="/usr/local/share/theblackberets/justfile"
    local justfile_dir="/usr/local/share/theblackberets"
    
    # Check if justfile exists
    if [ ! -f "$justfile" ]; then
        # Try alternative locations
        for path in "./justfile" "$HOME/.justfile" "/usr/local/share/theblackberets/justfile"; do
            if [ -f "$path" ]; then
                justfile="$path"
                justfile_dir="$(dirname "$path")"
                break
            fi
        done
    fi

    # If justfile doesn't exist, no completion
    if [ ! -f "$justfile" ]; then
        return 0
    fi

    # Find just command
    local just_cmd
    if command -v just >/dev/null 2>&1; then
        just_cmd="just"
    elif [ -f /usr/local/bin/just ]; then
        just_cmd="/usr/local/bin/just"
    elif [ -f /usr/bin/just ]; then
        just_cmd="/usr/bin/just"
    else
        return 0
    fi

    # Get list of recipes from justfile
    local recipes
    if [ -f "$justfile" ] && command -v "$just_cmd" >/dev/null 2>&1; then
        # Extract recipe names from 'just --list' output
        # Format can be: "    recipe-name" or "recipe-name" or "recipe-name arg:"
        recipes=$("$just_cmd" --justfile "$justfile" --working-directory "$justfile_dir" --list 2>/dev/null | \
            awk 'NF > 0 && !/^Available/ && !/^Justfile/ && !/^$/ {gsub(/:/, "", $NF); print $NF}' || true)
    fi

    # If we're completing the first argument (recipe name)
    if [ $COMP_CWORD -eq 1 ]; then
        # Filter recipes based on current input
        if [ -n "$recipes" ]; then
            COMPREPLY=($(compgen -W "$recipes" -- "$cur"))
        fi
        return 0
    fi

    # Handle parameter completion for specific recipes
    local recipe="${words[1]}"
    
    case "$recipe" in
        analyze-nmap|pentest-ai|security-checklist)
            # These recipes take a TARGET parameter
            if [ $COMP_CWORD -eq 2 ]; then
                # Complete with common hostname patterns or files
                COMPREPLY=($(compgen -f -- "$cur"))
            fi
            ;;
        analyze-sqlmap)
            # Takes a URL parameter
            if [ $COMP_CWORD -eq 2 ]; then
                # Complete with http:// or https:// URLs
                if [[ "$cur" != http* ]]; then
                    COMPREPLY=($(compgen -W "http:// https://" -- "$cur"))
                else
                    COMPREPLY=($(compgen -f -- "$cur"))
                fi
            fi
            ;;
        crack-wifi)
            # Takes INTERFACE BSSID WORDLIST
            if [ $COMP_CWORD -eq 2 ]; then
                # Complete network interfaces
                local interfaces=$(ip link show 2>/dev/null | grep -E "^[0-9]+:" | awk '{print $2}' | sed 's/:$//' || echo "")
                if [ -n "$interfaces" ]; then
                    COMPREPLY=($(compgen -W "$interfaces" -- "$cur"))
                else
                    COMPREPLY=($(compgen -f -- "$cur"))
                fi
            elif [ $COMP_CWORD -eq 3 ]; then
                # BSSID - no completion, user must type it
                return 0
            elif [ $COMP_CWORD -eq 4 ]; then
                # WORDLIST - complete files
                COMPREPLY=($(compgen -f -- "$cur"))
            fi
            ;;
        download-llama3-8b|run-localai|start|run|chat|stop|status)
            # These recipes may have optional parameters, but we'll just complete files
            if [ $COMP_CWORD -eq 2 ]; then
                COMPREPLY=($(compgen -f -- "$cur"))
            fi
            ;;
        analyze-hash|security-report)
            # Takes a file parameter
            if [ $COMP_CWORD -eq 2 ]; then
                COMPREPLY=($(compgen -f -- "$cur"))
            fi
            ;;
        ask-security-tool)
            # Takes TOOL QUESTION
            if [ $COMP_CWORD -eq 2 ]; then
                # Complete with common security tools
                local tools="nmap sqlmap aircrack-ng john hashcat metasploit burp wireshark"
                COMPREPLY=($(compgen -W "$tools" -- "$cur"))
            fi
            ;;
        *)
            # Default: complete with files
            COMPREPLY=($(compgen -f -- "$cur"))
            ;;
    esac

    return 0
}

# Register completion function
complete -F _justdo_completion justdo

