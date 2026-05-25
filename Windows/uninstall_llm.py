#!/usr/bin/env python3
"""
Local LLM Uninstaller
Supports: Ollama, LM Studio, LocalAI, llama.cpp, Python venvs, custom installs
"""

import os
import sys
import shutil
import argparse
import subprocess
import platform
import json
from pathlib import Path
from typing import List, Dict, Optional, Tuple
from dataclasses import dataclass, asdict
from datetime import datetime


@dataclass
class InstallTarget:
    name: str
    paths: List[Path]
    processes: List[str]
    services: List[str]
    registry_keys: List[str]
    description: str


class Colors:
    RED = '\033[91m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    MAGENTA = '\033[95m'
    CYAN = '\033[96m'
    WHITE = '\033[97m'
    BOLD = '\033[1m'
    END = '\033[0m'

    @classmethod
    def disable(cls):
        cls.RED = cls.GREEN = cls.YELLOW = cls.BLUE = ''
        cls.MAGENTA = cls.CYAN = cls.WHITE = cls.BOLD = cls.END = ''


class LLMUninstaller:
    COMMON_TARGETS = [
        InstallTarget(
            name="Ollama",
            paths=[
                Path.home() / ".ollama",
                Path("/usr/local/bin/ollama"),
                Path("/usr/bin/ollama"),
                Path.home() / "AppData/Local/Programs/Ollama",
                Path("/Applications/Ollama.app"),
            ],
            processes=["ollama", "ollama.exe"],
            services=["ollama"],
            registry_keys=[
                r"HKCU\Software\Ollama",
                r"HKLM\Software\Ollama",
            ],
            description="Popular local LLM runner with model library"
        ),
        InstallTarget(
            name="LM Studio",
            paths=[
                Path.home() / ".cache/lm-studio",
                Path.home() / ".lmstudio",
                Path.home() / "AppData/Local/LM-Studio",
                Path("/Applications/LM Studio.app"),
            ],
            processes=["LM Studio", "LM Studio.exe", "lm-studio"],
            services=[],
            registry_keys=[
                r"HKCU\Software\LM-Studio",
            ],
            description="GUI for running local LLMs"
        ),
        InstallTarget(
            name="LocalAI",
            paths=[
                Path("/usr/local/bin/local-ai"),
                Path("/usr/bin/local-ai"),
                Path.home() / "local-ai",
            ],
            processes=["local-ai", "local-ai.exe"],
            services=["local-ai"],
            registry_keys=[],
            description="OpenAI API-compatible local inference"
        ),
        InstallTarget(
            name="llama.cpp",
            paths=[
                Path.home() / "llama.cpp",
                Path("/usr/local/bin/llama-server"),
                Path("/usr/local/bin/main"),
            ],
            processes=["llama-server", "main", "llama-cli"],
            services=[],
            registry_keys=[],
            description="Plain C++ LLM inference (various builds)"
        ),
        InstallTarget(
            name="Python Venv (Generic)",
            paths=[
                Path.home() / "venv",
                Path.home() / ".venvs",
                Path("venv"),
                Path(".venv"),
            ],
            processes=["python", "python3"],
            services=[],
            registry_keys=[],
            description="Generic Python virtual environments"
        ),
        InstallTarget(
            name="Custom/Unknown",
            paths=[],
            processes=[],
            services=[],
            registry_keys=[],
            description="User-specified custom installation"
        ),
    ]

    def __init__(self, dry_run: bool = False, backup: bool = False, force: bool = False):
        self.dry_run = dry_run
        self.backup = backup
        self.force = force
        self.os_type = platform.system().lower()
        self.removed_items: List[Dict] = []
        self.errors: List[str] = []
        
        if not sys.stdout.isatty():
            Colors.disable()

    def _print(self, text: str, color: str = Colors.WHITE):
        print(f"{color}{text}{Colors.END}")

    def _header(self, text: str):
        print(f"\n{Colors.BOLD}{Colors.CYAN}{'='*60}{Colors.END}")
        print(f"{Colors.BOLD}{Colors.CYAN}  {text}{Colors.END}")
        print(f"{Colors.BOLD}{Colors.CYAN}{'='*60}{Colors.END}\n")

    def _success(self, text: str):
        self._print(f"✓ {text}", Colors.GREEN)

    def _warning(self, text: str):
        self._print(f"⚠ {text}", Colors.YELLOW)

    def _error(self, text: str):
        self._print(f"✗ {text}", Colors.RED)

    def _info(self, text: str):
        self._print(f"ℹ {text}", Colors.BLUE)

    def detect_installations(self) -> List[Tuple[InstallTarget, List[Path], List[str]]]:
        """Scan for existing LLM installations."""
        found = []
        
        for target in self.COMMON_TARGETS:
            existing_paths = []
            running_procs = []
            
            # Check paths
            for path in target.paths:
                if path.exists():
                    existing_paths.append(path)
            
            # Check processes
            for proc in target.processes:
                if self._is_process_running(proc):
                    running_procs.append(proc)
            
            # Only include if something found, or it's the custom target
            if existing_paths or running_procs or target.name == "Custom/Unknown":
                found.append((target, existing_paths, running_procs))
                
        return found

    def _is_process_running(self, name: str) -> bool:
        """Check if process is running."""
        try:
            if self.os_type == "windows":
                result = subprocess.run(
                    ["tasklist", "/FI", f"IMAGENAME eq {name}"],
                    capture_output=True, text=True, check=False
                )
                return name.lower() in result.stdout.lower()
            else:
                result = subprocess.run(
                    ["pgrep", "-f", name],
                    capture_output=True, check=False
                )
                return result.returncode == 0
        except Exception:
            return False

    def kill_processes(self, processes: List[str]) -> bool:
        """Kill running processes."""
        success = True
        for proc in processes:
            try:
                if self.dry_run:
                    self._info(f"[DRY-RUN] Would kill process: {proc}")
                    continue
                    
                self._info(f"Stopping process: {proc}")
                
                if self.os_type == "windows":
                    subprocess.run(
                        ["taskkill", "/F", "/IM", proc],
                        capture_output=True, check=False
                    )
                else:
                    subprocess.run(
                        ["pkill", "-9", "-f", proc],
                        capture_output=True, check=False
                    )
                    
                # Verify killed
                import time
                time.sleep(0.5)
                if not self._is_process_running(proc):
                    self._success(f"Stopped: {proc}")
                    self.removed_items.append({"type": "process", "name": proc})
                else:
                    self._error(f"Failed to stop: {proc}")
                    success = False
                    
            except Exception as e:
                self._error(f"Error killing {proc}: {e}")
                success = False
                
        return success

    def stop_services(self, services: List[str]) -> bool:
        """Stop system services."""
        success = True
        for service in services:
            try:
                if self.dry_run:
                    self._info(f"[DRY-RUN] Would stop service: {service}")
                    continue
                    
                self._info(f"Stopping service: {service}")
                
                if self.os_type == "windows":
                    subprocess.run(
                        ["sc", "stop", service],
                        capture_output=True, check=False
                    )
                else:
                    subprocess.run(
                        ["sudo", "systemctl", "stop", service],
                        capture_output=True, check=False
                    )
                    subprocess.run(
                        ["sudo", "systemctl", "disable", service],
                        capture_output=True, check=False
                    )
                    
                self._success(f"Stopped service: {service}")
                self.removed_items.append({"type": "service", "name": service})
                
            except Exception as e:
                self._error(f"Error stopping service {service}: {e}")
                success = False
                
        return success

    def remove_paths(self, paths: List[Path], target_name: str) -> bool:
        """Remove files and directories with backup option."""
        success = True
        
        for path in paths:
            try:
                if not path.exists():
                    continue
                    
                if self.dry_run:
                    self._info(f"[DRY-RUN] Would remove: {path}")
                    continue
                
                # Backup if requested
                if self.backup:
                    backup_path = Path(str(path) + f".backup_{datetime.now().strftime('%Y%m%d_%H%M%S')}")
                    self._info(f"Backing up to: {backup_path}")
                    if path.is_dir():
                        shutil.copytree(path, backup_path)
                    else:
                        shutil.copy2(path, backup_path)
                
                self._info(f"Removing: {path}")
                
                if path.is_dir():
                    shutil.rmtree(path, ignore_errors=False)
                else:
                    path.unlink()
                    
                if not path.exists():
                    self._success(f"Removed: {path}")
                    self.removed_items.append({
                        "type": "path", 
                        "path": str(path),
                        "target": target_name
                    })
                else:
                    self._error(f"Failed to remove: {path}")
                    success = False
                    
            except PermissionError:
                self._error(f"Permission denied: {path} (try running as admin/sudo)")
                self.errors.append(f"Permission denied: {path}")
                success = False
            except Exception as e:
                self._error(f"Error removing {path}: {e}")
                success = False
                
        return success

    def clean_registry(self, keys: List[str]) -> bool:
        """Clean Windows registry keys."""
        if self.os_type != "windows":
            return True
            
        success = True
        for key in keys:
            try:
                if self.dry_run:
                    self._info(f"[DRY-RUN] Would delete registry key: {key}")
                    continue
                    
                self._info(f"Removing registry key: {key}")
                result = subprocess.run(
                    ["reg", "delete", key, "/f"],
                    capture_output=True, check=False
                )
                if result.returncode == 0:
                    self._success(f"Removed registry key: {key}")
                    self.removed_items.append({"type": "registry", "key": key})
                else:
                    self._warning(f"Registry key not found or could not remove: {key}")
                    
            except Exception as e:
                self._error(f"Error removing registry key {key}: {e}")
                success = False
                
        return success

    def clean_shell_config(self):
        """Remove PATH entries and aliases from shell configs."""
        shell_files = []
        home = Path.home()
        
        if self.os_type == "windows":
            # Windows environment variables would need registry edits
            return
        else:
            shell_files = [
                home / ".bashrc",
                home / ".zshrc",
                home / ".bash_profile",
                home / ".zprofile",
                home / ".profile",
            ]
        
        llm_patterns = ["ollama", "lm-studio", "local-ai", "llama.cpp", "cuda", "nvidia"]
        
        for shell_file in shell_files:
            if not shell_file.exists():
                continue
                
            try:
                content = shell_file.read_text()
                lines = content.split('\n')
                modified = False
                new_lines = []
                
                for line in lines:
                    # Check if line contains LLM-related exports/aliases
                    if any(pattern in line.lower() for pattern in llm_patterns):
                        if self.dry_run:
                            self._info(f"[DRY-RUN] Would remove from {shell_file}: {line.strip()}")
                            new_lines.append(line)  # Keep in dry-run
                        else:
                            self._info(f"Removing from {shell_file}: {line.strip()}")
                            modified = True
                            continue
                    new_lines.append(line)
                
                if modified and not self.dry_run:
                    backup = Path(str(shell_file) + ".backup_llm_uninstall")
                    shutil.copy2(shell_file, backup)
                    shell_file.write_text('\n'.join(new_lines))
                    self._success(f"Cleaned: {shell_file}")
                    self.removed_items.append({"type": "shell_config", "file": str(shell_file)})
                    
            except Exception as e:
                self._error(f"Error processing {shell_file}: {e}")

    def generate_report(self, output_path: Optional[Path] = None):
        """Generate uninstallation report."""
        report = {
            "timestamp": datetime.now().isoformat(),
            "dry_run": self.dry_run,
            "platform": platform.platform(),
            "removed_items": self.removed_items,
            "errors": self.errors,
        }
        
        report_text = json.dumps(report, indent=2)
        
        if output_path:
            output_path.write_text(report_text)
            self._success(f"Report saved to: {output_path}")
        else:
            print(f"\n{Colors.BOLD}Uninstallation Report:{Colors.END}")
            print(report_text)
            
        return report

    def uninstall_target(self, target: InstallTarget, paths: List[Path], processes: List[str]):
        """Uninstall a specific target."""
        self._header(f"Uninstalling: {target.name}")
        self._info(f"Description: {target.description}")
        
        # 1. Kill processes
        if processes:
            self._print(f"\n{Colors.BOLD}Step 1: Stopping processes{Colors.END}")
            self.kill_processes(processes)
        
        # 2. Stop services
        if target.services:
            self._print(f"\n{Colors.BOLD}Step 2: Stopping services{Colors.END}")
            self.stop_services(target.services)
        
        # 3. Remove files
        if paths:
            self._print(f"\n{Colors.BOLD}Step 3: Removing files{Colors.END}")
            self.remove_paths(paths, target.name)
        
        # 4. Clean registry (Windows)
        if target.registry_keys:
            self._print(f"\n{Colors.BOLD}Step 4: Cleaning registry{Colors.END}")
            self.clean_registry(target.registry_keys)
        
        # 5. Shell config cleanup
        self._print(f"\n{Colors.BOLD}Step 5: Cleaning shell configurations{Colors.END}")
        self.clean_shell_config()

    def run_interactive(self):
        """Interactive uninstallation wizard."""
        self._header("Local LLM Uninstaller")
        self._info(f"Platform: {platform.platform()}")
        self._info(f"User: {os.getlogin() if hasattr(os, 'getlogin') else 'unknown'}")
        
        if self.dry_run:
            self._warning("DRY-RUN MODE: No changes will be made")
        if self.backup:
            self._info("BACKUP MODE: Files will be backed up before removal")
        
        # Detection phase
        self._header("Detection Phase")
        detected = self.detect_installations()
        
        if not detected or all(not paths and not procs for _, paths, procs in detected[:-1]):
            self._warning("No common LLM installations detected.")
            if not self.force:
                response = input(f"\n{Colors.YELLOW}No installations found. Run custom uninstall? [y/N]: {Colors.END}")
                if response.lower() != 'y':
                    self._info("Exiting.")
                    return
                detected = [detected[-1]]  # Use custom target
            else:
                detected = [detected[-1]]
        else:
            self._success(f"Found {len([d for d in detected if d[1] or d[2]])} installation(s)")
            for target, paths, procs in detected:
                if paths or procs:
                    status = f"{Colors.GREEN}DETECTED{Colors.END}"
                    details = []
                    if paths:
                        details.append(f"{len(paths)} path(s)")
                    if procs:
                        details.append(f"{len(procs)} running process(es)")
                    print(f"  • {Colors.BOLD}{target.name}{Colors.END}: {status} ({', '.join(details)})")
        
        # Selection phase
        self._header("Selection Phase")
        print("Select installations to uninstall (comma-separated numbers, or 'all'):\n")
        
        valid_targets = [(target, paths, procs) for target, paths, procs in detected if paths or procs or target.name == "Custom/Unknown"]
        
        for i, (target, paths, procs) in enumerate(valid_targets, 1):
            print(f"  {Colors.CYAN}[{i}]{Colors.END} {Colors.BOLD}{target.name}{Colors.END}")
            print(f"      {target.description}")
            if paths:
                print(f"      Paths: {', '.join(str(p) for p in paths[:2])}{'...' if len(paths) > 2 else ''}")
            if procs:
                print(f"      Running: {', '.join(procs)}")
            print()
        
        try:
            selection = input(f"{Colors.BOLD}Selection: {Colors.END}").strip()
            
            if selection.lower() == 'all':
                selected = valid_targets
            else:
                indices = [int(x.strip()) - 1 for x in selection.split(',')]
                selected = [valid_targets[i] for i in indices if 0 <= i < len(valid_targets)]
        except (ValueError, IndexError):
            self._error("Invalid selection")
            return
        
        if not selected:
            self._warning("Nothing selected. Exiting.")
            return
        
        # Confirmation
        self._header("Confirmation")
        total_size = 0
        for target, paths, _ in selected:
            for path in paths:
                if path.exists():
                    try:
                        if path.is_dir():
                            total_size += sum(f.stat().st_size for f in path.rglob('*') if f.is_file())
                        else:
                            total_size += path.stat().st_size
                    except:
                        pass
        
        print(f"About to uninstall {len(selected)} item(s)")
        print(f"Estimated disk space to free: {total_size / (1024**3):.2f} GB")
        
        if self.dry_run:
            print(f"{Colors.YELLOW}DRY-RUN: No actual changes will be made{Colors.END}")
        
        confirm = input(f"\n{Colors.RED}{Colors.BOLD}Type 'uninstall' to proceed: {Colors.END}").strip()
        
        if confirm != 'uninstall':
            self._info("Cancelled.")
            return
        
        # Execution
        self._header("Uninstallation")
        
        for target, paths, procs in selected:
            self.uninstall_target(target, paths, procs)
        
        # Final cleanup
        self._header("Final Cleanup")
        self.clean_shell_config()
        
        # Report
        self._header("Complete")
        if self.errors:
            self._warning(f"Completed with {len(self.errors)} error(s)")
            for err in self.errors:
                print(f"  - {err}")
        else:
            self._success("Uninstallation completed successfully!")
        
        # Save report
        report_path = Path.home() / f"llm_uninstall_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        self.generate_report(report_path)
        
        print(f"\n{Colors.BOLD}Note:{Colors.END} You may need to restart your terminal or system for all changes to take effect.")


def main():
    parser = argparse.ArgumentParser(
        description="Uninstall local LLM installations cleanly and safely",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s                          # Interactive mode
  %(prog)s --dry-run                # Preview what would be removed
  %(prog)s --backup                 # Backup before removal
  %(prog)s --target ollama          # Uninstall specific target
  %(prog)s --path /custom/path      # Add custom path to scan
        """
    )
    
    parser.add_argument('--dry-run', action='store_true', 
                       help='Preview changes without making them')
    parser.add_argument('--backup', action='store_true',
                       help='Create backups before removing files')
    parser.add_argument('--force', action='store_true',
                       help='Force uninstall even if nothing detected')
    parser.add_argument('--target', choices=['ollama', 'lm-studio', 'localai', 'llama.cpp', 'all'],
                       help='Target specific LLM (skip interactive selection)')
    parser.add_argument('--path', action='append', default=[],
                       help='Additional paths to remove (can be used multiple times)')
    parser.add_argument('--yes', '-y', action='store_true',
                       help='Skip confirmation prompts')
    
    args = parser.parse_args()
    
    # Check if running with sufficient privileges
    if platform.system().lower() == "windows":
        import ctypes
        if not ctypes.windll.shell32.IsUserAnAdmin():
            print(f"{Colors.YELLOW}Warning: Not running as administrator. Some items may not be removable.{Colors.END}")
    else:
        if os.geteuid() != 0:
            print(f"{Colors.YELLOW}Warning: Not running as root. Use sudo for system-wide installations.{Colors.END}")
    
    uninstaller = LLMUninstaller(dry_run=args.dry_run, backup=args.backup, force=args.force)
    
    # Handle custom paths
    if args.path:
        custom_target = uninstaller.COMMON_TARGETS[-1]  # Custom/Unknown
        custom_target.paths.extend([Path(p) for p in args.path])
    
    if args.target:
        # Non-interactive mode
        target_map = {
            'ollama': 'Ollama',
            'lm-studio': 'LM Studio',
            'localai': 'LocalAI',
            'llama.cpp': 'llama.cpp',
            'all': None
        }
        
        detected = uninstaller.detect_installations()
        
        if args.target == 'all':
            selected = [(t, p, pr) for t, p, pr in detected if p or pr]
        else:
            name = target_map[args.target]
            selected = [(t, p, pr) for t, p, pr in detected if t.name == name]
        
        if not selected:
            print(f"{Colors.RED}Target '{args.target}' not found{Colors.END}")
            sys.exit(1)
        
        if not args.yes and not args.dry_run:
            print(f"About to uninstall: {', '.join(t.name for t, _, _ in selected)}")
            confirm = input("Proceed? [y/N]: ")
            if confirm.lower() != 'y':
                sys.exit(0)
        
        for target, paths, procs in selected:
            uninstaller.uninstall_target(target, paths, procs)
        
        uninstaller.generate_report()
    else:
        # Interactive mode
        uninstaller.run_interactive()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print(f"\n\n{Colors.YELLOW}Cancelled by user{Colors.END}")
        sys.exit(1)
