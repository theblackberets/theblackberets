#!/usr/bin/env python3
"""
MCP Server for Kali Tools Integration with LocalAI
Enables AI assistants to execute Kali Linux security tools via Model Context Protocol
"""

import json
import subprocess
import sys
import os
from typing import Any, Dict, List, Optional

class KaliMCPServer:
    def __init__(self):
        self.tools = self._register_tools()
    
    def _register_tools(self) -> List[Dict[str, Any]]:
        """Register available Kali tools as MCP tools"""
        return [
            {
                "name": "nmap_scan",
                "description": "Perform network scanning with nmap",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "target": {"type": "string", "description": "Target host or IP address"},
                        "scan_type": {"type": "string", "description": "Scan type (stealth, full, quick)", "default": "quick"},
                        "ports": {"type": "string", "description": "Port range (e.g., '80,443' or '1-1000')", "default": ""}
                    },
                    "required": ["target"]
                }
            },
            {
                "name": "sqlmap_scan",
                "description": "Test for SQL injection vulnerabilities",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "url": {"type": "string", "description": "Target URL to test"},
                        "level": {"type": "integer", "description": "Scan level (1-5)", "default": 1},
                        "risk": {"type": "integer", "description": "Risk level (1-3)", "default": 1}
                    },
                    "required": ["url"]
                }
            },
            {
                "name": "gobuster_scan",
                "description": "Directory/file brute-forcing with gobuster",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "url": {"type": "string", "description": "Target URL"},
                        "wordlist": {"type": "string", "description": "Wordlist path", "default": "/usr/share/wordlists/dirb/common.txt"},
                        "extensions": {"type": "string", "description": "File extensions to search (e.g., 'php,html,txt')", "default": ""}
                    },
                    "required": ["url"]
                }
            },
            {
                "name": "hash_identify",
                "description": "Identify hash type",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "hash": {"type": "string", "description": "Hash to identify"}
                    },
                    "required": ["hash"]
                }
            },
            {
                "name": "john_crack",
                "description": "Crack password hash with John the Ripper",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "hash_file": {"type": "string", "description": "Path to hash file"},
                        "wordlist": {"type": "string", "description": "Wordlist path", "default": "/usr/share/wordlists/rockyou.txt"}
                    },
                    "required": ["hash_file"]
                }
            },
            {
                "name": "analyze_with_localai",
                "description": "Send tool output to LocalAI for analysis",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "data": {"type": "string", "description": "Data to analyze"},
                        "analysis_type": {"type": "string", "description": "Type of analysis (security, vulnerability, report)", "default": "security"},
                        "localai_url": {"type": "string", "description": "LocalAI API URL", "default": "http://localhost:8080"}
                    },
                    "required": ["data"]
                }
            },
            {
                "name": "wifi_scan",
                "description": "Scan for WiFi networks",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "interface": {"type": "string", "description": "WiFi interface (e.g., wlan0)", "default": "wlan0"}
                    }
                }
            },
            {
                "name": "aircrack_crack",
                "description": "Crack WiFi password with aircrack-ng",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "capture_file": {"type": "string", "description": "Path to .cap file"},
                        "bssid": {"type": "string", "description": "BSSID of target network"},
                        "wordlist": {"type": "string", "description": "Wordlist path", "default": "/usr/share/wordlists/rockyou.txt"}
                    },
                    "required": ["capture_file", "bssid"]
                }
            }
        ]
    
    def _execute_command(self, cmd: List[str], timeout: int = 300, input_text: Optional[str] = None) -> Dict[str, Any]:
        """Execute shell command safely with robust error handling"""
        if not cmd:
            return {
                "success": False,
                "stdout": "",
                "stderr": "Empty command",
                "returncode": -1
            }
        
        # Validate command exists
        if not self._check_tool_available(cmd[0]):
            return {
                "success": False,
                "stdout": "",
                "stderr": f"Command not found: {cmd[0]}",
                "returncode": -1
            }
        
        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=timeout,
                check=False,
                stderr=subprocess.STDOUT,  # Combine stderr with stdout for better error visibility
                input=input_text
            )
            # When stderr is redirected to stdout, result.stderr will be empty
            # Use stdout for both since they're combined
            return {
                "success": result.returncode == 0,
                "stdout": result.stdout or "",
                "stderr": result.stdout or "",  # stderr is redirected to stdout
                "returncode": result.returncode
            }
        except subprocess.TimeoutExpired:
            return {
                "success": False,
                "stdout": "",
                "stderr": f"Command timed out after {timeout} seconds",
                "returncode": -1
            }
        except FileNotFoundError:
            return {
                "success": False,
                "stdout": "",
                "stderr": f"Command not found: {cmd[0]}",
                "returncode": -1
            }
        except PermissionError:
            return {
                "success": False,
                "stdout": "",
                "stderr": f"Permission denied: {cmd[0]}",
                "returncode": -1
            }
        except Exception as e:
            return {
                "success": False,
                "stdout": "",
                "stderr": f"Error executing command: {str(e)}",
                "returncode": -1
            }
    
    def _check_tool_available(self, tool: str) -> bool:
        """Check if a tool is available in PATH"""
        result = self._execute_command(["which", tool])
        return result["success"] and result["stdout"].strip() != ""
    
    def handle_nmap_scan(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Handle nmap scan request"""
        if not self._check_tool_available("nmap"):
            return {"error": "nmap not found. Install with: just install-kali-tools"}
        
        target = params["target"]
        scan_type = params.get("scan_type", "quick")
        ports = params.get("ports", "")
        
        cmd = ["nmap"]
        
        if scan_type == "stealth":
            cmd.extend(["-sS", "-T2"])
        elif scan_type == "full":
            cmd.extend(["-sV", "-sC", "-A"])
        else:  # quick
            cmd.extend(["-sV", "-sC"])
        
        if ports:
            cmd.extend(["-p", ports])
        
        cmd.append(target)
        
        result = self._execute_command(cmd)
        return {
            "tool": "nmap",
            "target": target,
            "output": result["stdout"],
            "error": result["stderr"] if not result["success"] else None
        }
    
    def handle_sqlmap_scan(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Handle sqlmap scan request"""
        if not self._check_tool_available("sqlmap"):
            return {"error": "sqlmap not found. Install with: just install-kali-tools"}
        
        url = params["url"]
        level = params.get("level", 1)
        risk = params.get("risk", 1)
        
        cmd = ["sqlmap", "-u", url, "--batch", "--level", str(level), "--risk", str(risk)]
        result = self._execute_command(cmd, timeout=600)
        
        return {
            "tool": "sqlmap",
            "url": url,
            "output": result["stdout"],
            "error": result["stderr"] if not result["success"] else None
        }
    
    def handle_gobuster_scan(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Handle gobuster scan request"""
        if not self._check_tool_available("gobuster"):
            return {"error": "gobuster not found. Install with: just install-kali-tools"}
        
        url = params["url"]
        wordlist = params.get("wordlist", "/usr/share/wordlists/dirb/common.txt")
        extensions = params.get("extensions", "")
        
        cmd = ["gobuster", "dir", "-u", url, "-w", wordlist]
        if extensions:
            cmd.extend(["-x", extensions])
        
        result = self._execute_command(cmd, timeout=600)
        
        return {
            "tool": "gobuster",
            "url": url,
            "output": result["stdout"],
            "error": result["stderr"] if not result["success"] else None
        }
    
    def handle_analyze_with_localai(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Send data to LocalAI for analysis"""
        import urllib.request
        import urllib.parse
        
        data = params["data"]
        analysis_type = params.get("analysis_type", "security")
        localai_url = params.get("localai_url", "http://localhost:8080")
        
        system_prompts = {
            "security": "You are a cybersecurity expert. Analyze the provided data and provide security insights.",
            "vulnerability": "You are a vulnerability assessment expert. Analyze the data and identify security vulnerabilities.",
            "report": "You are a cybersecurity consultant. Generate a professional security assessment report."
        }
        
        system_prompt = system_prompts.get(analysis_type, system_prompts["security"])
        
        payload = {
            "model": "llama-3-8b",
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": data}
            ],
            "temperature": 0.3
        }
        
        try:
            req = urllib.request.Request(
                f"{localai_url}/v1/chat/completions",
                data=json.dumps(payload).encode(),
                headers={"Content-Type": "application/json"}
            )
            
            with urllib.request.urlopen(req, timeout=60) as response:
                result = json.loads(response.read().decode())
                return {
                    "tool": "localai_analysis",
                    "analysis_type": analysis_type,
                    "output": result.get("choices", [{}])[0].get("message", {}).get("content", "")
                }
        except Exception as e:
            return {"error": f"Failed to connect to LocalAI: {str(e)}"}
    
    def handle_hash_identify(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Identify hash type"""
        hash_value = params["hash"]
        
        # Try using hash-identifier or hashid if available
        if self._check_tool_available("hashid"):
            result = self._execute_command(["hashid", hash_value])
            return {
                "tool": "hashid",
                "hash": hash_value,
                "output": result["stdout"],
                "error": result["stderr"] if not result["success"] else None
            }
        elif self._check_tool_available("hash-identifier"):
            # hash-identifier reads from stdin
            result = self._execute_command(["hash-identifier"], input_text=hash_value + "\n")
            return {
                "tool": "hash-identifier",
                "hash": hash_value,
                "output": result["stdout"],
                "error": result["stderr"] if not result["success"] else None
            }
        else:
            # Basic hash length/pattern analysis
            hash_len = len(hash_value)
            possible_types = []
            
            if hash_len == 32 and all(c in '0123456789abcdef' for c in hash_value.lower()):
                possible_types.append("MD5")
            elif hash_len == 40 and all(c in '0123456789abcdef' for c in hash_value.lower()):
                possible_types.append("SHA1")
            elif hash_len == 64 and all(c in '0123456789abcdef' for c in hash_value.lower()):
                possible_types.append("SHA256")
            elif hash_value.startswith("$2") or hash_value.startswith("$2a") or hash_value.startswith("$2b"):
                possible_types.append("bcrypt")
            elif hash_value.startswith("$1$"):
                possible_types.append("MD5 Crypt")
            elif hash_value.startswith("$5$"):
                possible_types.append("SHA256 Crypt")
            elif hash_value.startswith("$6$"):
                possible_types.append("SHA512 Crypt")
            
            return {
                "tool": "hash_identify",
                "hash": hash_value,
                "length": hash_len,
                "possible_types": possible_types if possible_types else ["Unknown - install hashid for better detection"],
                "output": f"Hash length: {hash_len}, Possible types: {', '.join(possible_types) if possible_types else 'Unknown'}"
            }
    
    def handle_john_crack(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Crack password hash with John the Ripper"""
        if not self._check_tool_available("john"):
            return {"error": "john not found. Install with: just install-kali-tools"}
        
        hash_file = params["hash_file"]
        wordlist = params.get("wordlist", "/usr/share/wordlists/rockyou.txt")
        
        if not os.path.exists(hash_file):
            return {"error": f"Hash file not found: {hash_file}"}
        
        if not os.path.exists(wordlist):
            return {"error": f"Wordlist not found: {wordlist}"}
        
        cmd = ["john", "--wordlist", wordlist, hash_file]
        result = self._execute_command(cmd, timeout=3600)  # 1 hour timeout for cracking
        
        return {
            "tool": "john",
            "hash_file": hash_file,
            "wordlist": wordlist,
            "output": result["stdout"],
            "error": result["stderr"] if not result["success"] else None
        }
    
    def handle_wifi_scan(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Scan for WiFi networks"""
        if not self._check_tool_available("iwlist"):
            if not self._check_tool_available("iw"):
                return {"error": "WiFi scanning tools not found. Install wireless-tools or iw"}
        
        interface = params.get("interface", "wlan0")
        
        # Try iwlist first (more common), then iw
        if self._check_tool_available("iwlist"):
            cmd = ["iwlist", interface, "scan"]
        else:
            cmd = ["iw", "dev", interface, "scan"]
        
        result = self._execute_command(cmd, timeout=30)
        
        return {
            "tool": "wifi_scan",
            "interface": interface,
            "output": result["stdout"],
            "error": result["stderr"] if not result["success"] else None
        }
    
    def handle_aircrack_crack(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Crack WiFi password with aircrack-ng"""
        if not self._check_tool_available("aircrack-ng"):
            return {"error": "aircrack-ng not found. Install with: just install-kali-tools"}
        
        capture_file = params["capture_file"]
        bssid = params["bssid"]
        wordlist = params.get("wordlist", "/usr/share/wordlists/rockyou.txt")
        
        if not os.path.exists(capture_file):
            return {"error": f"Capture file not found: {capture_file}"}
        
        if not os.path.exists(wordlist):
            return {"error": f"Wordlist not found: {wordlist}"}
        
        cmd = ["aircrack-ng", "-w", wordlist, "-b", bssid, capture_file]
        result = self._execute_command(cmd, timeout=3600)  # 1 hour timeout for cracking
        
        # Try to extract password from output
        password = None
        if result["success"] and "KEY FOUND" in result["stdout"]:
            import re
            match = re.search(r'\[(.*?)\]', result["stdout"])
            if match:
                password = match.group(1).strip()
        
        return {
            "tool": "aircrack-ng",
            "capture_file": capture_file,
            "bssid": bssid,
            "wordlist": wordlist,
            "password": password,
            "output": result["stdout"],
            "error": result["stderr"] if not result["success"] else None
        }
    
    def handle_tool_call(self, name: str, params: Dict[str, Any]) -> Dict[str, Any]:
        """Route tool calls to appropriate handlers"""
        handlers = {
            "nmap_scan": self.handle_nmap_scan,
            "sqlmap_scan": self.handle_sqlmap_scan,
            "gobuster_scan": self.handle_gobuster_scan,
            "analyze_with_localai": self.handle_analyze_with_localai,
            "hash_identify": self.handle_hash_identify,
            "john_crack": self.handle_john_crack,
            "wifi_scan": self.handle_wifi_scan,
            "aircrack_crack": self.handle_aircrack_crack
        }
        
        handler = handlers.get(name)
        if not handler:
            return {"error": f"Unknown tool: {name}"}
        
        return handler(params)
    
    def process_request(self, request: Dict[str, Any]) -> Dict[str, Any]:
        """Process MCP request with robust error handling"""
        try:
            method = request.get("method")
            params = request.get("params", {})
            
            if method == "tools/list":
                return {
                    "tools": self.tools
                }
            elif method == "tools/call":
                tool_name = params.get("name")
                if not tool_name:
                    return {"error": "Tool name is required"}
                
                arguments = params.get("arguments", {})
                if not isinstance(arguments, dict):
                    return {"error": "Arguments must be a dictionary"}
                
                result = self.handle_tool_call(tool_name, arguments)
                return {
                    "content": [
                        {
                            "type": "text",
                            "text": json.dumps(result, indent=2)
                        }
                    ]
                }
            elif method == "initialize":
                return {
                    "protocolVersion": "2024-11-05",
                    "capabilities": {
                        "tools": {}
                    },
                    "serverInfo": {
                        "name": "kali-tools-mcp-server",
                        "version": "1.0.0"
                    }
                }
            else:
                return {"error": f"Unknown method: {method}"}
        except Exception as e:
            return {"error": f"Error processing request: {str(e)}"}

def main():
    """Main MCP server loop with robust error handling"""
    server = KaliMCPServer()
    
    # MCP uses stdio for communication
    try:
        for line in sys.stdin:
            if not line.strip():
                continue
                
            try:
                request = json.loads(line.strip())
            except json.JSONDecodeError as e:
                error_response = {
                    "jsonrpc": "2.0",
                    "error": {
                        "code": -32700,
                        "message": f"Parse error: {str(e)}"
                    },
                    "id": None
                }
                print(json.dumps(error_response))
                sys.stdout.flush()
                continue
            
            try:
                response = server.process_request(request)
                response["jsonrpc"] = "2.0"
                if "id" in request:
                    response["id"] = request["id"]
                else:
                    response["id"] = None
                
                print(json.dumps(response))
                sys.stdout.flush()
            except Exception as e:
                error_response = {
                    "jsonrpc": "2.0",
                    "error": {
                        "code": -32603,
                        "message": f"Internal error: {str(e)}"
                    },
                    "id": request.get("id") if isinstance(request, dict) else None
                }
                print(json.dumps(error_response))
                sys.stdout.flush()
    except KeyboardInterrupt:
        sys.exit(0)
    except Exception as e:
        error_response = {
            "jsonrpc": "2.0",
            "error": {
                "code": -32603,
                "message": f"Fatal error: {str(e)}"
            },
            "id": None
        }
        print(json.dumps(error_response))
        sys.stdout.flush()
        sys.exit(1)

if __name__ == "__main__":
    main()

