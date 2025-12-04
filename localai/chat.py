#!/usr/bin/env python3
"""
The Black Berets - Command Line Chat Interface
Interactive chat interface for LocalAI
"""

import json
import os
import re
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request
from typing import List, Dict, Optional, Tuple

# Configuration constants (defaults from configuration.nix)
# These are fallbacks - actual values read via get_config_value() from config module
DEFAULT_PORT = "8080"  # Matches ai.localAI.defaultPort in configuration.nix
DEFAULT_MODEL = "llama-3-8b"  # Matches ai.localAI.config.modelName in configuration.nix
DEFAULT_TEMPERATURE = 0.7  # Matches ai.localAI.config.temperature in configuration.nix
DEFAULT_LOCALAI_URL = f"http://localhost:{DEFAULT_PORT}"

# Connection constants
CONNECTION_TIMEOUT = 10
REQUEST_TIMEOUT = 60
CONNECTION_RETRIES = 3
RETRY_DELAY = 2

# MCP server constants
MCP_PROCESS_PATTERN = "mcp-kali-server.py"
MCP_CHECK_TIMEOUT = 2
CONFIG_SCRIPT_TIMEOUT = 5

# Model path constants
SYSTEM_MODEL_DIR = "/usr/local/share/theblackberets/models"


class ChatClient:
    """Client for interacting with LocalAI chat API"""
    
    def __init__(self, localai_url: str = DEFAULT_LOCALAI_URL, model: str = DEFAULT_MODEL):
        self.localai_url = localai_url.rstrip('/')
        self.model = model
        self.conversation_history: List[Dict[str, str]] = []
        self.temperature = DEFAULT_TEMPERATURE
        
    def check_connection(self, verbose: bool = False) -> bool:
        """Check if LocalAI is running"""
        try:
            req = urllib.request.Request(
                f"{self.localai_url}/v1/models",
                headers={"Content-Type": "application/json"}
            )
            with urllib.request.urlopen(req, timeout=CONNECTION_TIMEOUT) as response:
                if response.status == 200:
                    if verbose:
                        self._print_available_models(response)
                    return True
                return False
        except Exception:
            return False
    
    def _print_available_models(self, response) -> None:
        """Print available models from response"""
        try:
            data = json.loads(response.read().decode())
            models = data.get("data", [])
            if models:
                print(f"Found {len(models)} model(s) available")
        except Exception:
            pass
    
    def send_message(self, user_message: str) -> Optional[str]:
        """Send a message to LocalAI and get response"""
        self.conversation_history.append({"role": "user", "content": user_message})
        
        payload = {
            "model": self.model,
            "messages": self.conversation_history,
            "temperature": self.temperature,
            "stream": False
        }
        
        try:
            req = urllib.request.Request(
                f"{self.localai_url}/v1/chat/completions",
                data=json.dumps(payload).encode(),
                headers={"Content-Type": "application/json"}
            )
            
            try:
                with urllib.request.urlopen(req, timeout=REQUEST_TIMEOUT) as response:
                    if response.status != 200:
                        try:
                            error_body = response.read().decode()
                            error_details = self._parse_error_body(error_body)
                            if error_details:
                                return f"HTTP {response.status}: {error_details}"
                        except Exception:
                            pass
                        return f"HTTP error {response.status}: Unexpected response from LocalAI"
                    
                    result = json.loads(response.read().decode())
                    
                    if "error" in result:
                        error_info = result.get("error", {})
                        error_msg = error_info.get("message", str(error_info)) if isinstance(error_info, dict) else str(error_info)
                        return f"LocalAI error: {error_msg}"
                    
                    assistant_message = result.get("choices", [{}])[0].get("message", {}).get("content", "")
                    
                    if assistant_message:
                        self.conversation_history.append({"role": "assistant", "content": assistant_message})
                        return assistant_message
                    else:
                        return "No response received from LocalAI"
            except socket.timeout:
                return "Request timed out after 60 seconds. LocalAI may be busy or not responding. Check logs: justdo status"
            except urllib.error.URLError as e:
                return self._handle_connection_error(e)
                    
        except urllib.error.HTTPError as e:
            return self._handle_http_error(e)
        except KeyboardInterrupt:
            raise
        except Exception as e:
            return f"Error: {str(e)}"
    
    def _handle_connection_error(self, e: urllib.error.URLError) -> str:
        """Handle connection errors"""
        error_reason = str(e.reason) if hasattr(e, 'reason') else str(e)
        if isinstance(e.reason, socket.timeout) or "timeout" in error_reason.lower():
            return "Request timed out. LocalAI may be busy or not responding. Check logs: justdo status"
        return f"Connection error: {error_reason}. Make sure LocalAI is running (justdo start)"
    
    def _handle_http_error(self, e: urllib.error.HTTPError) -> str:
        """Handle HTTP errors with detailed messages"""
        error_details = self._parse_error_response(e)
        error_message = f"HTTP error {e.code}"
        
        if error_details:
            error_message += f": {error_details}"
            if "model" in error_details.lower() and ("not found" in error_details.lower() or "missing" in error_details.lower()):
                return f"{error_message}\n\nModel '{self.model}' is not available. Download it with: justdo download-model"
            elif "internal server error" in error_details.lower():
                return f"{error_message}\n\nLocalAI encountered an internal error. This often means:\n" \
                       f"  1. Model file is missing - Download with: justdo download-model\n" \
                       f"  2. Model file is corrupted - Check: ls -lh ./models/\n" \
                       f"  3. LocalAI configuration issue - Check logs: tail -f ./localai-config/localai.log"
        else:
            error_message += f": {str(e)}"
        
        return error_message
    
    def _parse_error_response(self, e: urllib.error.HTTPError) -> Optional[str]:
        """Parse error response body for detailed error message"""
        try:
            if hasattr(e, 'read'):
                error_body = e.read().decode()
                return self._parse_error_body(error_body)
        except Exception:
            pass
        return None
    
    def _parse_error_body(self, error_body: str) -> Optional[str]:
        """Parse error body (JSON or plain text) for error message"""
        if not error_body or not error_body.strip():
            return None
        
        try:
            error_json = json.loads(error_body)
            if isinstance(error_json, dict):
                error_msg = error_json.get('error', {})
                if isinstance(error_msg, dict):
                    return error_msg.get('message', error_msg.get('type', str(error_msg)))
                elif isinstance(error_msg, str):
                    return error_msg
                return error_json.get('message', str(error_json))
            return str(error_json)
        except json.JSONDecodeError:
            return error_body.strip() if error_body.strip() else None
    
    def clear_history(self) -> None:
        """Clear conversation history"""
        self.conversation_history = []
    
    def print_welcome(self) -> None:
        """Print welcome message"""
        print("=" * 60)
        print("The Black Berets - AI Chat Interface")
        print("=" * 60)
        print(f"LocalAI URL: {self.localai_url}")
        print(f"Model: {self.model}")
        print("Type 'quit' or 'exit' to exit, 'clear' to clear history")
        print("=" * 60)
        print()


def get_config_value(key: str, default: str) -> str:
    """Get configuration value from Nix config module or use default"""
    try:
        script_dir = os.path.dirname(os.path.abspath(__file__))
        current_cwd = os.getcwd()  # Preserve current working directory
        # Try multiple locations for config.sh (works from different directory contexts)
        config_scripts = [
            os.path.join(script_dir, "..", "lib", "config.sh"),
            os.path.join(script_dir, "..", "..", "lib", "config.sh"),
            "/usr/local/share/theblackberets/lib/config.sh",
        ]
        
        for config_script in config_scripts:
            if os.path.exists(config_script):
                try:
                    # Run config module from current working directory to preserve context
                    # This ensures relative paths in config are resolved correctly
                    result = subprocess.run(
                        ["bash", "-c", f"cd '{current_cwd}' && . {config_script} && get_config '{key}' '{default}'"],
                        capture_output=True,
                        text=True,
                        timeout=CONFIG_SCRIPT_TIMEOUT,
                        cwd=current_cwd  # Explicitly set working directory
                    )
                    if result.returncode == 0 and result.stdout.strip():
                        return result.stdout.strip()
                except Exception:
                    continue
    except Exception:
        pass
    
    return default


def check_localai_connection(client: ChatClient) -> bool:
    """Check LocalAI connection with retries"""
    print("Checking LocalAI connection...")
    
    for attempt in range(CONNECTION_RETRIES):
        if client.check_connection(verbose=(attempt == CONNECTION_RETRIES - 1)):
            print("Connected to LocalAI!")
            print()
            return True
        if attempt < CONNECTION_RETRIES - 1:
            print(f"Retrying connection ({attempt + 1}/{CONNECTION_RETRIES})...")
            time.sleep(RETRY_DELAY)
    
    print(f"WARNING: Cannot connect to LocalAI at {client.localai_url}")
    print("Make sure LocalAI is running: justdo start")
    print("You can still try to chat, but it may fail if LocalAI is not running.")
    print()
    
    return prompt_continue("Continue anyway? (y/n): ")


def prompt_continue(message: str) -> bool:
    """Prompt user to continue and return True if yes"""
    try:
        response = input(message).strip().lower()
        if response != 'y':
            print("Exiting.")
            sys.exit(1)
        return True
    except (EOFError, KeyboardInterrupt):
        print("\nExiting.")
        sys.exit(1)


def is_mcp_server_running() -> bool:
    """Check if MCP server process is running"""
    try:
        result = subprocess.run(
            ["pgrep", "-f", MCP_PROCESS_PATTERN],
            capture_output=True,
            timeout=MCP_CHECK_TIMEOUT
        )
        return result.returncode == 0
    except Exception:
        return False


def check_mcp_server() -> None:
    """Check if MCP server is running, exit if not available"""
    print("Checking MCP server...")
    
    if is_mcp_server_running():
        print("MCP server is running!")
        print()
        return
    
    print("ERROR: MCP server is not running.")
    print("Start it with: justdo start-mcp")
    sys.exit(1)


def _get_model_search_dirs() -> List[str]:
    """Get list of directories to search for model file in priority order"""
    model_dir_config = get_config_value('ai.localAI.modelDir', './models')
    script_dir = os.path.dirname(os.path.abspath(__file__))
    
    search_dirs = []
    
    # Priority 1: System installation directory
    search_dirs.append(SYSTEM_MODEL_DIR)
    
    # Priority 2: Current working directory
    if not os.path.isabs(model_dir_config):
        search_dirs.append(os.path.join(os.getcwd(), model_dir_config.lstrip('./')))
        search_dirs.append(model_dir_config)
    
    # Priority 3: Script-relative path
    if not os.path.isabs(model_dir_config):
        script_relative = os.path.join(script_dir, "..", model_dir_config.lstrip('./'))
        search_dirs.append(os.path.normpath(script_relative))
    
    # Priority 4: Common alternatives
    search_dirs.extend([
        "./models",
        "models",
        os.path.join(os.getcwd(), "models"),
    ])
    
    return search_dirs


def find_model_file_in_directory(directory: str, expected_filename: str) -> Optional[str]:
    """Find model file in directory, handling case-insensitive and partial matches"""
    if not os.path.exists(directory) or not os.path.isdir(directory):
        return None
    
    expected_lower = expected_filename.lower()
    expected_base = os.path.splitext(expected_filename)[0].lower()
    
    try:
        files = os.listdir(directory)
        # Exact match
        for file in files:
            if file == expected_filename:
                return os.path.join(directory, file)
        
        # Case-insensitive match
        for file in files:
            if file.lower() == expected_lower:
                return os.path.join(directory, file)
        
        # Partial match (base name matches)
        for file in files:
            file_base = os.path.splitext(file)[0].lower()
            if file_base == expected_base and file.lower().endswith('.gguf'):
                return os.path.join(directory, file)
        
        # Any .gguf file if looking for model
        if expected_filename.lower().endswith('.gguf'):
            for file in files:
                if file.lower().endswith('.gguf'):
                    return os.path.join(directory, file)
    except Exception:
        pass
    
    return None


def check_model_file_exists() -> Tuple[bool, Optional[str], Optional[str]]:
    """Check if model file exists on disk, returns (exists, expected_path, actual_path)"""
    model_file = get_config_value('ai.localAI.config.modelFile', '')
    if not model_file:
        model_file = get_config_value('ai.localAI.downloadModel.modelName', 'Meta-Llama-3-8B-Instruct.Q4_K_M.gguf')
    
    # Get model directory from config
    model_dir_config = get_config_value('ai.localAI.modelDir', './models')
    
    # Get search directories (this includes all possible locations)
    search_dirs = _get_model_search_dirs()
    
    # Expected path should be the primary location based on current working directory
    # This is where the user would expect to find/download the model
    current_cwd = os.getcwd()
    if os.path.isabs(model_dir_config):
        # Config returned absolute path - use it
        expected_path = os.path.join(model_dir_config, model_file)
    else:
        # Config returned relative path - resolve relative to current working directory
        # This matches the primary search location in _get_model_search_dirs()
        normalized_dir = model_dir_config.lstrip('./')
        expected_path = os.path.abspath(os.path.join(current_cwd, normalized_dir, model_file))
    
    # Search in priority order (check all possible locations)
    for search_dir in search_dirs:
        if not search_dir or not os.path.exists(search_dir):
            continue
        
        exact_path = os.path.join(search_dir, model_file)
        if os.path.exists(exact_path) and os.path.isfile(exact_path):
            # Found the file - return success with expected_path and actual_path
            return True, expected_path, exact_path
        
        found_path = find_model_file_in_directory(search_dir, model_file)
        if found_path:
            # Found the file via fuzzy search - return success
            return True, expected_path, found_path
    
    # If not found, return expected_path (based on current working directory + config)
    # This will show user where they should put/download the model
    return False, expected_path, None


def validate_model_availability(client: ChatClient) -> Tuple[bool, Optional[str]]:
    """Validate that the model is available and working in LocalAI"""
    try:
        req = urllib.request.Request(
            f"{client.localai_url}/v1/models",
            headers={"Content-Type": "application/json"}
        )
        with urllib.request.urlopen(req, timeout=CONNECTION_TIMEOUT) as response:
            if response.status == 200:
                data = json.loads(response.read().decode())
                models = data.get("data", [])
                model_ids = [m.get("id", "") for m in models]
                if client.model in model_ids:
                    return True, None
                else:
                    available_models = ", ".join(model_ids) if model_ids else "none"
                    return False, f"Model '{client.model}' not found in LocalAI. Available models: {available_models}"
    except Exception as e:
        return False, f"Failed to check model availability: {str(e)}"
    
    return False, "Could not validate model availability"


def test_model_request(client: ChatClient) -> Tuple[bool, Optional[str]]:
    """Test if LocalAI can process a simple request with the model"""
    try:
        test_payload = {
            "model": client.model,
            "messages": [{"role": "user", "content": "test"}],
            "temperature": 0.7,
            "max_tokens": 5,
            "stream": False
        }
        
        req = urllib.request.Request(
            f"{client.localai_url}/v1/chat/completions",
            data=json.dumps(test_payload).encode(),
            headers={"Content-Type": "application/json"}
        )
        
        with urllib.request.urlopen(req, timeout=REQUEST_TIMEOUT) as response:
            if response.status == 200:
                result = json.loads(response.read().decode())
                if "error" in result:
                    error_info = result.get("error", {})
                    error_msg = error_info.get("message", str(error_info)) if isinstance(error_info, dict) else str(error_info)
                    return False, f"Model test failed: {error_msg}"
                return True, None
            else:
                error_body = response.read().decode()
                error_details = client._parse_error_body(error_body)
                return False, f"HTTP {response.status}: {error_details or 'Unknown error'}"
    except urllib.error.HTTPError as e:
        error_details = client._parse_error_response(e)
        if error_details:
            return False, f"HTTP {e.code}: {error_details}"
        return False, f"HTTP {e.code}: Model test failed"
    except Exception as e:
        return False, f"Model test failed: {str(e)}"


def _get_pid_by_port(port: int) -> Optional[str]:
    """Get PID listening on port using multiple methods"""
    # Method 1: lsof
    try:
        result = subprocess.run(
            ["lsof", "-ti", f":{port}"],
            capture_output=True,
            text=True,
            timeout=2
        )
        if result.returncode == 0 and result.stdout.strip():
            pids = [p.strip() for p in result.stdout.strip().split('\n') if p.strip()]
            for pid in pids:
                if pid.isdigit():
                    return pid
    except Exception:
        pass
    
    # Method 2: pgrep + lsof verification
    try:
        result = subprocess.run(
            ["pgrep", "-f", "localai"],
            capture_output=True,
            text=True,
            timeout=2
        )
        if result.returncode == 0 and result.stdout.strip():
            pids = [p.strip() for p in result.stdout.strip().split('\n') if p.strip()]
            for pid in pids:
                if pid.isdigit():
                    try:
                        check_result = subprocess.run(
                            ["lsof", "-p", pid, "-i", f":{port}"],
                            capture_output=True,
                            text=True,
                            timeout=1
                        )
                        if check_result.returncode == 0 and check_result.stdout.strip():
                            return pid
                    except Exception:
                        return pid
    except Exception:
        pass
    
    # Method 3: ss/netstat
    for cmd in [["ss", "-tlnp"], ["netstat", "-tlnp"]]:
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=2)
            if result.returncode == 0:
                for line in result.stdout.split('\n'):
                    if f":{port}" in line:
                        pid_match = re.search(r'pid=(\d+)', line)
                        if pid_match:
                            return pid_match.group(1)
                        pid_match = re.search(r'(\d+)/(?:localai|python)', line, re.IGNORECASE)
                        if pid_match:
                            return pid_match.group(1)
        except Exception:
            continue
    
    return None


def run_diagnostic_checklist(client: ChatClient, show_all: bool = False) -> Dict[str, Tuple[bool, str]]:
    """Run comprehensive diagnostic checklist, returns results dict"""
    results = {}
    
    if show_all:
        print("=" * 60)
        print("DIAGNOSTIC CHECKLIST - Identifying Issues")
        print("=" * 60)
        print()
    
    # Check 1: Configuration access
    if show_all:
        print("[1/10] Checking configuration access...")
    try:
        port = get_config_value('ai.localAI.defaultPort', DEFAULT_PORT)
        model = get_config_value('ai.localAI.config.modelName', DEFAULT_MODEL)
        model_dir = get_config_value('ai.localAI.modelDir', './models')
        if port and model:
            results['config'] = (True, f"Config accessible (port: {port}, model: {model}, dir: {model_dir})")
            if show_all:
                print(f"  ✓ {results['config'][1]}")
        else:
            results['config'] = (False, "Configuration values missing")
            if show_all:
                print(f"  ✗ {results['config'][1]}")
    except Exception as e:
        results['config'] = (False, f"Config access failed: {str(e)}")
        if show_all:
            print(f"  ✗ {results['config'][1]}")
    if show_all:
        print()
    
    # Check 2: Model file existence
    if show_all:
        print("[2/10] Checking model file existence...")
    model_exists, expected_path, actual_path = check_model_file_exists()
    if model_exists and actual_path:
        file_size = os.path.getsize(actual_path)
        file_size_mb = file_size / (1024 * 1024)
        if actual_path != expected_path:
            results['model_file'] = (True, f"Model file found: {actual_path} ({file_size_mb:.1f} MB) [expected: {expected_path}]")
        else:
            results['model_file'] = (True, f"Model file found: {actual_path} ({file_size_mb:.1f} MB)")
        if show_all:
            print(f"  ✓ {results['model_file'][1]}")
    else:
        results['model_file'] = (False, f"Model file not found: {expected_path or 'unknown path'}")
        if show_all:
            print(f"  ✗ {results['model_file'][1]}")
    if show_all:
        print()
    
    # Check 3: Model directory accessibility
    if show_all:
        print("[3/10] Checking model directory...")
    try:
        found_dir = None
        for search_dir in _get_model_search_dirs():
            if search_dir and os.path.exists(search_dir) and os.path.isdir(search_dir):
                found_dir = search_dir
                break
        
        if found_dir:
            files = os.listdir(found_dir)
            gguf_files = [f for f in files if f.lower().endswith('.gguf')]
            msg = f"Model directory accessible: {found_dir} ({len(files)} files"
            if gguf_files:
                msg += f", {len(gguf_files)} .gguf files"
            msg += ")"
            results['model_dir'] = (True, msg)
            if show_all:
                print(f"  ✓ {results['model_dir'][1]}")
        else:
            results['model_dir'] = (False, f"Model directory not found")
            if show_all:
                print(f"  ✗ {results['model_dir'][1]}")
    except Exception as e:
        results['model_dir'] = (False, f"Model directory check failed: {str(e)}")
        if show_all:
            print(f"  ✗ {results['model_dir'][1]}")
    if show_all:
        print()
    
    # Check 4: LocalAI process status
    if show_all:
        print("[4/10] Checking LocalAI process...")
    try:
        port = get_config_value('ai.localAI.defaultPort', DEFAULT_PORT)
        port_int = int(port)
        
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(1)
        result = sock.connect_ex(('localhost', port_int))
        sock.close()
        
        if result == 0:
            pid = _get_pid_by_port(port_int)
            pid_info = f" (PID: {pid})" if pid else ""
            results['localai_process'] = (True, f"Port {port} is listening{pid_info}")
            if show_all:
                print(f"  ✓ {results['localai_process'][1]}")
        else:
            results['localai_process'] = (False, f"No process listening on port {port}")
            if show_all:
                print(f"  ✗ {results['localai_process'][1]}")
    except Exception as e:
        results['localai_process'] = (False, f"Process check failed: {str(e)}")
        if show_all:
            print(f"  ✗ {results['localai_process'][1]}")
    if show_all:
        print()
    
    # Check 5: LocalAI API connectivity
    if show_all:
        print("[5/10] Checking LocalAI API connectivity...")
    try:
        if client.check_connection(verbose=False):
            results['localai_api'] = (True, f"LocalAI API responding at {client.localai_url}")
            if show_all:
                print(f"  ✓ {results['localai_api'][1]}")
        else:
            results['localai_api'] = (False, f"LocalAI API not responding at {client.localai_url}")
            if show_all:
                print(f"  ✗ {results['localai_api'][1]}")
    except Exception as e:
        results['localai_api'] = (False, f"API connectivity check failed: {str(e)}")
        if show_all:
            print(f"  ✗ {results['localai_api'][1]}")
    if show_all:
        print()
    
    # Check 6: LocalAI models endpoint
    if show_all:
        print("[6/10] Checking LocalAI models endpoint...")
    try:
        req = urllib.request.Request(
            f"{client.localai_url}/v1/models",
            headers={"Content-Type": "application/json"}
        )
        with urllib.request.urlopen(req, timeout=CONNECTION_TIMEOUT) as response:
            if response.status == 200:
                data = json.loads(response.read().decode())
                models = data.get("data", [])
                model_ids = [m.get("id", "") for m in models]
                results['models_endpoint'] = (True, f"Models endpoint OK ({len(model_ids)} models: {', '.join(model_ids)})")
                if show_all:
                    print(f"  ✓ {results['models_endpoint'][1]}")
            else:
                results['models_endpoint'] = (False, f"Models endpoint returned HTTP {response.status}")
                if show_all:
                    print(f"  ✗ {results['models_endpoint'][1]}")
    except Exception as e:
        results['models_endpoint'] = (False, f"Models endpoint check failed: {str(e)}")
        if show_all:
            print(f"  ✗ {results['models_endpoint'][1]}")
    if show_all:
        print()
    
    # Check 7: Model availability in LocalAI
    if show_all:
        print("[7/10] Checking model availability in LocalAI...")
    model_available, error_msg = validate_model_availability(client)
    if model_available:
        results['model_availability'] = (True, f"Model '{client.model}' is available in LocalAI")
        if show_all:
            print(f"  ✓ {results['model_availability'][1]}")
    else:
        results['model_availability'] = (False, error_msg or f"Model '{client.model}' not available")
        if show_all:
            print(f"  ✗ {results['model_availability'][1]}")
    if show_all:
        print()
    
    # Check 8: Model request test
    if show_all:
        print("[8/10] Testing model request...")
    if model_available:
        test_passed, test_error = test_model_request(client)
        if test_passed:
            results['model_request'] = (True, "Model can process requests successfully")
            if show_all:
                print(f"  ✓ {results['model_request'][1]}")
        else:
            results['model_request'] = (False, test_error or "Model request test failed")
            if show_all:
                print(f"  ✗ {results['model_request'][1]}")
    else:
        results['model_request'] = (False, "Skipped (model not available)")
        if show_all:
            print(f"  - {results['model_request'][1]}")
    if show_all:
        print()
    
    # Check 9: MCP server status
    if show_all:
        print("[9/10] Checking MCP server...")
    mcp_running = is_mcp_server_running()
    if mcp_running:
        results['mcp_server'] = (True, "MCP server is running")
        if show_all:
            print(f"  ✓ {results['mcp_server'][1]}")
    else:
        results['mcp_server'] = (False, "MCP server is not running")
        if show_all:
            print(f"  ✗ {results['mcp_server'][1]}")
    if show_all:
        print()
    
    # Check 10: Log file accessibility
    if show_all:
        print("[10/10] Checking log file accessibility...")
    try:
        config_dir = get_config_value('ai.localAI.configDir', './localai-config')
        if not os.path.isabs(config_dir):
            script_dir = os.path.dirname(os.path.abspath(__file__))
            config_dir = os.path.join(script_dir, "..", config_dir.lstrip('./'))
            config_dir = os.path.normpath(config_dir)
        
        log_file = os.path.join(config_dir, "localai.log")
        if os.path.exists(log_file):
            log_size = os.path.getsize(log_file)
            log_size_kb = log_size / 1024
            results['log_file'] = (True, f"Log file accessible: {log_file} ({log_size_kb:.1f} KB)")
            if show_all:
                print(f"  ✓ {results['log_file'][1]}")
        else:
            results['log_file'] = (False, f"Log file not found: {log_file}")
            if show_all:
                print(f"  ✗ {results['log_file'][1]}")
    except Exception as e:
        results['log_file'] = (False, f"Log file check failed: {str(e)}")
        if show_all:
            print(f"  ✗ {results['log_file'][1]}")
    if show_all:
        print()
    
    return results


def print_diagnostic_report(results: Dict[str, Tuple[bool, str]]) -> None:
    """Print diagnostic report summary"""
    print("=" * 60)
    print("DIAGNOSTIC SUMMARY")
    print("=" * 60)
    passed = sum(1 for status, _ in results.values() if status)
    total = len(results)
    
    print(f"\nPassed: {passed}/{total} checks")
    print()
    
    if passed < total:
        print("FAILED CHECKS:")
        for check_name, (status, message) in results.items():
            if not status:
                print(f"  ✗ [{check_name}] {message}")
        print()
        print("RECOMMENDED ACTIONS:")
        action_num = 1
        
        if not results.get('model_file', (True, ''))[0]:
            print(f"  {action_num}. Download model: justdo download-model")
            action_num += 1
        
        if not results.get('localai_process', (True, ''))[0]:
            print(f"  {action_num}. Start LocalAI: justdo start-localai")
            action_num += 1
        
        if not results.get('localai_api', (True, ''))[0]:
            print(f"  {action_num}. Check LocalAI status: justdo status")
            print(f"  {action_num + 1}. Check logs: tail -f ./localai-config/localai.log")
            action_num += 2
        
        if not results.get('mcp_server', (True, ''))[0]:
            print(f"  {action_num}. Start MCP server: justdo start-mcp")
            action_num += 1
        
        # Check for backend errors
        model_request_failed = not results.get('model_request', (True, ''))[0]
        model_request_msg = results.get('model_request', (True, ''))[1]
        backend_error = model_request_failed and model_request_msg and "backend not found" in model_request_msg.lower()
        
        if model_request_failed:
            if backend_error:
                print(f"  {action_num}. Backend configuration error detected:")
                print("     - Check LocalAI config: cat ./localai-config/config.yaml")
                print("     - Verify backend name (try: 'llama', 'llama-cpp', 'llama.cpp', or 'ggml')")
                print("     - Check available backends: localai backends list")
                print("     - Install backend if needed: localai backends install llama-cpp")
                print("     - Check LocalAI version compatibility: localai --version")
                print("     - Restart LocalAI: justdo stop && justdo start")
            elif results.get('model_file', (False, ''))[0]:
                print(f"  {action_num}. Model file exists but request fails - check:")
                print("     - Model file integrity: ls -lh ./models/")
                print("     - LocalAI config: cat ./localai-config/config.yaml")
                print("     - LocalAI logs: tail -f ./localai-config/localai.log")
            else:
                print(f"  {action_num}. Model request failed - check:")
                print("     - LocalAI logs: tail -f ./localai-config/localai.log")
                print("     - LocalAI config: cat ./localai-config/config.yaml")
            action_num += 1
    
    print("=" * 60)
    print()


def validate_environment(client: ChatClient, check_localai: bool = True) -> None:
    """Validate environment before starting chat"""
    print("Validating environment...")
    errors = []
    
    # Check 1: Model file exists
    model_exists, expected_path, actual_path = check_model_file_exists()
    if not model_exists:
        errors.append(f"Model file not found: {expected_path}")
        errors.append("  Download it with: justdo download-model")
    elif actual_path:
        if actual_path != expected_path:
            print(f"✓ Model file found: {actual_path} [expected: {expected_path}]")
        else:
            print(f"✓ Model file found: {actual_path}")
    
    # Check 2 & 3: Only if LocalAI is connected
    if check_localai:
        model_available, error_msg = validate_model_availability(client)
        if not model_available:
            errors.append(error_msg or f"Model '{client.model}' is not available in LocalAI")
        else:
            print(f"✓ Model '{client.model}' is available in LocalAI")
        
        if model_available:
            print("Testing model request...")
            test_passed, test_error = test_model_request(client)
            if not test_passed:
                errors.append(f"Model test failed: {test_error or 'Could not process request'}")
            else:
                print("✓ Model can process requests")
    
    # Report results
    print()
    if errors:
        print("ERROR: Validation failed:")
        for error in errors:
            print(f"  {error}")
        print()
        sys.exit(1)
    
    print("✓ All validations passed!")
    print()


def send_initial_greeting(client: ChatClient) -> None:
    """Send initial greeting to LocalAI"""
    try:
        print("Sending initial greeting...")
        greeting = client.send_message("Hello! Introduce yourself briefly.")
        
        if greeting and not is_error_response(greeting):
            print(f"Assistant: {greeting}")
            print()
        else:
            print(f"ERROR: {greeting}")
            print()
            if "model" in greeting.lower() and ("not found" in greeting.lower() or "missing" in greeting.lower()):
                print("The model file is missing. Download it with:")
                print("  justdo download-model")
                print()
            elif "HTTP error 500" in greeting or "Internal Server Error" in greeting:
                print("LocalAI returned an internal server error. Common causes:")
                print("  1. Model file is missing - Download with: justdo download-model")
                print("  2. Model file is corrupted - Check: ls -lh ./models/")
                print("  3. LocalAI configuration issue - Check logs: tail -f ./localai-config/localai.log")
                print()
            print("You can still try chatting, but responses may fail.")
            print()
    except KeyboardInterrupt:
        print("\n\nGoodbye!")
        sys.exit(0)
    except Exception as e:
        print(f"ERROR: Failed to send initial greeting: {e}")
        print("You can still try chatting.")
        print()


def is_error_response(response: str) -> bool:
    """Check if response is an error message"""
    if not response:
        return False
    error_prefixes = ["Error", "Connection error", "HTTP error", "HTTP 4", "HTTP 5", "LocalAI error"]
    return any(response.startswith(prefix) for prefix in error_prefixes)


def handle_user_input(user_input: str, client: ChatClient) -> bool:
    """Handle user input and return False if should exit"""
    if not user_input:
        return True
    
    if user_input.lower() in ['quit', 'exit', 'q']:
        print("\nGoodbye!")
        return False
    elif user_input.lower() in ['clear', 'reset']:
        client.clear_history()
        print("Conversation history cleared.\n")
        return True
    
    print("Assistant: ", end="", flush=True)
    try:
        response = client.send_message(user_input)
        
        if response:
            if is_error_response(response):
                print(f"\n{response}")
                if "model" in response.lower() and ("not found" in response.lower() or "missing" in response.lower()):
                    print("\nTroubleshooting:")
                    print("  Model file is missing. Download it with:")
                    print("    justdo download-model")
                elif "HTTP error 500" in response or "Internal Server Error" in response:
                    print("\nTroubleshooting:")
                    print("  1. Model file may be missing - Download with: justdo download-model")
                    print("  2. Model file may be corrupted - Check: ls -lh ./models/")
                    print("  3. Check LocalAI logs: tail -f ./localai-config/localai.log")
                    print("  4. Restart LocalAI: justdo stop && justdo start")
            else:
                print(response)
        else:
            print("No response received.")
    except KeyboardInterrupt:
        print("\n\nInterrupted. Type 'quit' to exit or continue chatting.")
        print()
        return True
    
    print()
    return True


def run_chat_loop(client: ChatClient) -> None:
    """Run the main chat loop"""
    try:
        while True:
            try:
                user_input = input("You: ").strip()
            except (EOFError, KeyboardInterrupt):
                print("\n\nGoodbye!")
                break
            
            if not handle_user_input(user_input, client):
                break
    except KeyboardInterrupt:
        print("\n\nGoodbye!")
    except Exception as e:
        print(f"\nError: {e}")
        sys.exit(1)


def main() -> None:
    """Main chat loop"""
    # Check for diagnostic mode
    if len(sys.argv) > 1 and sys.argv[1] in ['--diagnose', '-d', 'diagnose']:
        port = get_config_value('ai.localAI.defaultPort', DEFAULT_PORT)
        localai_url = f"http://localhost:{port}"
        model = get_config_value('ai.localAI.config.modelName', DEFAULT_MODEL)
        client = ChatClient(localai_url=localai_url, model=model)
        results = run_diagnostic_checklist(client, show_all=True)
        print_diagnostic_report(results)
        sys.exit(0)
    
    # Get configuration
    port = get_config_value('ai.localAI.defaultPort', DEFAULT_PORT)
    localai_url = f"http://localhost:{port}"
    model = get_config_value('ai.localAI.config.modelName', DEFAULT_MODEL)
    
    # Create chat client
    client = ChatClient(localai_url=localai_url, model=model)
    
    # Run diagnostic checklist BEFORE validation (only show if failed)
    results = run_diagnostic_checklist(client, show_all=False)
    failed_checks = [name for name, (status, _) in results.items() if not status]
    
    if failed_checks:
        print("Running diagnostic checklist...")
        print()
        run_diagnostic_checklist(client, show_all=True)
        print_diagnostic_report(results)
        print("Fix the issues above before starting chat.")
        print("Common solutions:")
        print("  1. Download model: justdo download-model")
        print("  2. Check LocalAI logs: tail -f ./localai-config/localai.log")
        print("  3. Restart LocalAI: justdo stop && justdo start")
        sys.exit(1)
    
    # Check LocalAI connection
    connected = check_localai_connection(client)
    if not connected:
        print()
        validate_environment(client, check_localai=False)
    else:
        validate_environment(client, check_localai=True)
    
    # Check MCP server is running
    check_mcp_server()
    
    # Print welcome
    client.print_welcome()
    
    # Send initial greeting if connected
    if connected:
        send_initial_greeting(client)
    
    # Run chat loop
    run_chat_loop(client)


if __name__ == "__main__":
    main()
