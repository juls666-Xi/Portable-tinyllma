#!/usr/bin/env bash
# ================================================================
# TinyLlama 1.1B — Windows Installer (Q2_K Edition)
# Run this in Git Bash, MSYS2, or WSL
# ================================================================

set -e

BASE_DIR="$HOME/.tinyllama"
BIN_DIR="$BASE_DIR/bin"
MODEL_DIR="$BASE_DIR/models"
LOG_DIR="$BASE_DIR/logs"
CHAT_DIR="$BASE_DIR/chat_data"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$BIN_DIR" "$MODEL_DIR" "$LOG_DIR" "$CHAT_DIR"

R='\033[0;31m' Y='\033[1;33m' G='\033[0;32m'
C='\033[0;36m' M='\033[0;35m' D='\033[1;30m'
W='\033[1;37m' N='\033[0m'

banner() {
    echo ""
    echo -e "${C}================================================${N}"
    echo -e "${C} TinyLlama 1.1B Q2_K — Windows Installer ${N}"
    echo -e "${C}================================================${N}"
    echo ""
}

step() { echo -e "\n${Y}[$1/$TOTAL] $2${N}"; }
ok() { echo -e "${G} ✓ $1${N}"; }
info() { echo -e "${D} $1${N}"; }
warn() { echo -e "${Y} ! $1${N}"; }
fail() { echo -e "${R} ✗ $1${N}"; exit 1; }

TOTAL=4
banner

# ================================================================
# 0. Check for existing GGUF file to import
# ================================================================
echo ""
echo -e "${C}--- Model Setup ---${N}"
echo ""
echo -e " ${Y}[1]${N} Download Q2_K model from HuggingFace (~400 MB)"
echo -e " ${Y}[2]${N} Import existing GGUF file from your system"
echo ""
read -r -p " Choice (1/2): " MODEL_CHOICE

MODEL_FILE=""
MODEL_PATH=""

if [ "$MODEL_CHOICE" = "2" ]; then
    echo ""
    info "Looking for .gguf files..."
    
    FOUND_FILES=$(find "$HOME" -name "*.gguf" -type f 2>/dev/null | grep -v "$MODEL_DIR" | head -20)
    
    WIN_DOWNLOADS="/c/Users/$(whoami)/Downloads"
    if [ -d "$WIN_DOWNLOADS" ]; then
        WIN_FILES=$(find "$WIN_DOWNLOADS" -name "*.gguf" -type f 2>/dev/null | head -20)
        if [ -n "$WIN_FILES" ]; then
            FOUND_FILES="$FOUND_FILES\n$WIN_FILES"
        fi
    fi
    
    if [ -n "$FOUND_FILES" ]; then
        echo ""
        echo -e "${G}Found these GGUF files:${N}"
        echo -e "$FOUND_FILES" | nl -w2 -s') '
        echo ""
        echo -e " ${Y}[0]${N} None of these — I'll enter the path manually"
        echo ""
        read -r -p " Select file number (or 0 for manual): " FILE_NUM
        
        if [ "$FILE_NUM" = "0" ]; then
            echo ""
            read -r -p " Enter full path to your .gguf file: " CUSTOM_PATH
            if [ -f "$CUSTOM_PATH" ] && [[ "$CUSTOM_PATH" == *.gguf ]]; then
                MODEL_FILE=$(basename "$CUSTOM_PATH")
                if [ "$CUSTOM_PATH" = "$MODEL_DIR/$MODEL_FILE" ]; then
                    info "File already in models directory."
                    MODEL_PATH="$CUSTOM_PATH"
                else
                    info "Copying model to $MODEL_DIR/"
                    cp "$CUSTOM_PATH" "$MODEL_DIR/$MODEL_FILE"
                    ok "Model imported: $MODEL_FILE"
                    MODEL_PATH="$MODEL_DIR/$MODEL_FILE"
                fi
            else
                fail "Invalid file path or not a .gguf file."
            fi
        else
            SELECTED=$(echo -e "$FOUND_FILES" | sed -n "${FILE_NUM}p")
            if [ -n "$SELECTED" ] && [ -f "$SELECTED" ]; then
                MODEL_FILE=$(basename "$SELECTED")
                if [ "$SELECTED" = "$MODEL_DIR/$MODEL_FILE" ]; then
                    info "File already in models directory."
                    MODEL_PATH="$SELECTED"
                else
                    info "Copying model to $MODEL_DIR/"
                    cp "$SELECTED" "$MODEL_DIR/$MODEL_FILE"
                    ok "Model imported: $MODEL_FILE"
                    MODEL_PATH="$MODEL_DIR/$MODEL_FILE"
                fi
            else
                fail "Invalid selection."
            fi
        fi
    else
        echo ""
        warn "No .gguf files found"
        echo ""
        read -r -p " Enter full path to your .gguf file: " CUSTOM_PATH
        if [ -f "$CUSTOM_PATH" ] && [[ "$CUSTOM_PATH" == *.gguf ]]; then
            MODEL_FILE=$(basename "$CUSTOM_PATH")
            if [ "$CUSTOM_PATH" = "$MODEL_DIR/$MODEL_FILE" ]; then
                info "File already in models directory."
                MODEL_PATH="$CUSTOM_PATH"
            else
                info "Copying model to $MODEL_DIR/"
                cp "$CUSTOM_PATH" "$MODEL_DIR/$MODEL_FILE"
                ok "Model imported: $MODEL_FILE"
                MODEL_PATH="$MODEL_DIR/$MODEL_FILE"
            fi
        else
            fail "Invalid file path or not a .gguf file."
        fi
    fi
fi

# ================================================================
# 1. Check for llama.cpp server binary
# ================================================================
step 1 "Setting up llama.cpp engine..."

if [ -f "$BIN_DIR/llama-server.exe" ]; then
    ok "Engine already present."
elif [ -f "$BIN_DIR/llama-server" ]; then
    ok "Engine already present."
else
    info "Downloading pre-built llama-server for Windows..."
    
    LLAMA_RELEASE="https://github.com/ggerganov/llama.cpp/releases/download/b3492/llama-b3492-bin-win-avx2-x64.zip"
    TEMP_ZIP="$BIN_DIR/llama.zip"
    
    wget -q "$LLAMA_RELEASE" -O "$TEMP_ZIP" || {
        warn "Failed to download pre-built binary."
        warn "Please download manually from: https://github.com/ggergan