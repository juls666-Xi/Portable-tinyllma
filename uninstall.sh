#!/usr/bin/env bash
# ================================================================
# TinyLlama 1.1B — Uninstaller
# Reverts changes made by the install scripts.
# ================================================================

R='\033[0;31m' Y='\033[1;33m' G='\033[0;32m'
C='\033[0;36m' W='\033[1;37m' N='\033[0m'

echo ""
echo -e "${C}================================================${N}"
echo -e "${C}       TinyLlama — Uninstaller                  ${N}"
echo -e "${C}================================================${N}"
echo ""

confirm() {
    read -r -p " $1 (y/N): " ANS
    [[ "$ANS" =~ ^[Yy]$ ]]
}

# 1. Termux installation path (termux-cli-llm/install.sh)
TERMUX_DIR="$HOME/tinyllama"
if [ -d "$TERMUX_DIR" ]; then
    echo -e " Found Termux installation at: ${W}$TERMUX_DIR${N}"
    if confirm " Remove this directory and all its contents (models, bin, history)?"; then
        rm -rf "$TERMUX_DIR"
        echo -e "${G} ✓ Removed $TERMUX_DIR${N}"
    fi
fi

# 2. Linux native installation path (linux/install_linux.sh)
LINUX_DIR="$HOME/.local/share/tinyllama"
if [ -d "$LINUX_DIR" ]; then
    echo -e " Found Linux installation at: ${W}$LINUX_DIR${N}"
    if confirm " Remove this directory and all its contents?"; then
        rm -rf "$LINUX_DIR"
        echo -e "${G} ✓ Removed $LINUX_DIR${N}"
    fi
fi

# 3. Shared data (Android/USB installation style)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SHARED_DIR="$SCRIPT_DIR/Shared"
if [ -d "$SHARED_DIR" ]; then
    echo -e " Found Shared data directory at: ${W}$SHARED_DIR${N}"
    echo -e " This folder contains: ${W}bin/, models/, vendor/, chat_data/${N}"
    if confirm " Clean up these installed components?"; then
        # Remove specific subdirectories to avoid deleting unrelated user files
        rm -rf "$SHARED_DIR/bin"
        rm -rf "$SHARED_DIR/models"
        rm -rf "$SHARED_DIR/vendor"
        rm -rf "$SHARED_DIR/chat_data"
        rm -f "$SHARED_DIR/llama-server.log"
        echo -e "${G} ✓ Cleaned up components in $SHARED_DIR${N}"
        
        # If Shared is now empty, offer to remove it
        if [ -d "$SHARED_DIR" ] && [ -z "$(ls -A "$SHARED_DIR" 2>/dev/null)" ]; then
            if confirm " $SHARED_DIR is empty. Remove the folder entirely?"; then
                rm -rf "$SHARED_DIR"
                echo -e "${G} ✓ Removed $SHARED_DIR${N}"
            fi
        fi
    fi
fi

# 4. Cleanup any running processes
if pgrep -f "llama-server" >/dev/null || pgrep -f "chat_server.py" >/dev/null; then
    if confirm " Found running AI processes (engine or proxy). Kill them?"; then
        pkill -f "llama-server" || true
        pkill -f "chat_server.py" || true
        echo -e "${G} ✓ Processes terminated.${N}"
    fi
fi

# 5. Optional System Package Cleanup
echo -e "\n${Y}--- System Packages ---${N}"
echo -e " The installers added several build tools (git, python, cmake, etc.)."
echo -e " ${R}Warning: Only remove these if you don't use them for other projects!${N}"

if [ -d "/data/data/com.termux" ]; then
    # Termux environment
    TERMUX_PKGS="clang cmake ninja git wget python"
    if confirm " Uninstall Termux build dependencies ($TERMUX_PKGS)?"; then
        pkg uninstall $TERMUX_PKGS
        echo -e "${G} ✓ Packages removed.${N}"
    fi
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux environment - Detect package manager
    if command -v apt &>/dev/null; then
        LINUX_PKGS="build-essential cmake ninja-build git wget python3 python3-pip"
        if confirm " Uninstall Linux dependencies via apt ($LINUX_PKGS)?"; then
            sudo apt remove --purge $LINUX_PKGS
            sudo apt autoremove -y
            echo -e "${G} ✓ Packages removed.${N}"
        fi
    elif command -v pacman &>/dev/null; then
        LINUX_PKGS="base-devel cmake ninja git wget python python-pip"
        if confirm " Uninstall Linux dependencies via pacman ($LINUX_PKGS)?"; then
            sudo pacman -Rs $LINUX_PKGS
            echo -e "${G} ✓ Packages removed.${N}"
        fi
    elif command -v dnf &>/dev/null; then
        LINUX_PKGS="gcc gcc-c++ cmake ninja-build git wget python3 python3-pip"
        if confirm " Uninstall Linux dependencies via dnf ($LINUX_PKGS)?"; then
            sudo dnf remove $LINUX_PKGS
            echo -e "${G} ✓ Packages removed.${N}"
        fi
    elif command -v zypper &>/dev/null; then
        LINUX_PKGS="gcc gcc-c++ cmake ninja git wget python3 python3-pip"
        if confirm " Uninstall Linux dependencies via zypper ($LINUX_PKGS)?"; then
            sudo zypper remove $LINUX_PKGS
            echo -e "${G} ✓ Packages removed.${N}"
        fi
    else
        echo -e " No supported package manager found to automate uninstallation."
    fi
fi

echo ""
echo -e "${C} Uninstallation finished.${N}"
echo ""
