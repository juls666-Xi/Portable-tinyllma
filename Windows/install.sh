#!/usr/bin/env bash
# ================================================================
# TinyLlama 1.1B — Windows Installer (Q2_K Edition)
# Run this in Git Bash, MSYS2, or WSL
# Everything installs to %USERPROFILE%\.tinyllama\
# ================================================================

# Don't use set -e for interactive scripts
# set -e

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
read -r -p " Choice (1/2): " MODEL_CHOICE || true

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
        read -r -p " Select file number (or 0 for manual): " FILE_NUM || true

        if [ "$FILE_NUM" = "0" ]; then
            echo ""
            read -r -p " Enter full path to your .gguf file: " CUSTOM_PATH || true
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
        read -r -p " Enter full path to your .gguf file: " CUSTOM_PATH || true
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
        warn "Please download manually from: https://github.com/ggerganov/llama.cpp/releases"
        warn "Extract llama-server.exe to: $BIN_DIR/"
        fail "Cannot continue without llama-server.exe"
    }

    info "Extracting..."
    unzip -q "$TEMP_ZIP" -d "$BIN_DIR/"
    rm "$TEMP_ZIP"

    if [ -f "$BIN_DIR/llama-server.exe" ]; then
        ok "Engine ready: $BIN_DIR/llama-server.exe"
    elif [ -f "$BIN_DIR/build/bin/llama-server.exe" ]; then
        cp "$BIN_DIR/build/bin/llama-server.exe" "$BIN_DIR/"
        ok "Engine ready: $BIN_DIR/llama-server.exe"
    else
        fail "Could not find llama-server.exe after extraction."
    fi
fi

if [ -f "$BIN_DIR/llama-server.exe" ]; then
    LLAMA_BIN="$BIN_DIR/llama-server.exe"
else
    LLAMA_BIN="$BIN_DIR/llama-server"
fi

# ================================================================
# 2. Check Python
# ================================================================
step 2 "Checking Python..."

if command -v python3 &>/dev/null; then
    ok "Python3 found"
    PYTHON_CMD="python3"
elif command -v python &>/dev/null; then
    ok "Python found"
    PYTHON_CMD="python"
else
    warn "Python not found. Please install Python 3 from python.org"
    fail "Python is required for the chat server."
fi

# ================================================================
# 3. Download or verify model
# ================================================================
step 3 "Setting up model..."

if [ -n "$MODEL_PATH" ] && [ -f "$MODEL_PATH" ]; then
    ok "Using imported model: $(basename "$MODEL_PATH")"
else
    MODEL_FILE="tinyllama-1.1b-chat-v1.0.Q2_K.gguf"
    MODEL_URL="https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/${MODEL_FILE}"
    MODEL_PATH="$MODEL_DIR/$MODEL_FILE"

    if [ -f "$MODEL_PATH" ]; then
        SIZE=$(stat -c%s "$MODEL_PATH" 2>/dev/null || echo 0)
        if [ "$SIZE" -gt 300000000 ]; then
            ok "Model already downloaded."
        else
            warn "Incomplete file found. Re-downloading..."
            rm -f "$MODEL_PATH"
        fi
    fi

    if [ ! -f "$MODEL_PATH" ]; then
        info "Downloading from HuggingFace..."
        info "Saving to: $MODEL_PATH"
        wget -c "$MODEL_URL" -O "$MODEL_PATH" --show-progress || fail "Download failed. Check internet connection."
        SIZE=$(stat -c%s "$MODEL_PATH" 2>/dev/null || echo 0)
        [ "$SIZE" -gt 300000000 ] || fail "Download incomplete. Re-run install.sh to resume."
        ok "Model downloaded."
    fi
fi

# ================================================================
# 4. Write config
# ================================================================
step 4 "Writing config..."

cat > "$BASE_DIR/config.sh" << CONF
# TinyLlama Windows config — auto-generated by install.sh
TINYLLAMA_BASE="$BASE_DIR"
TINYLLAMA_BIN="$LLAMA_BIN"
TINYLLAMA_MODEL="$MODEL_PATH"
TINYLLAMA_UI="$SCRIPT_DIR/FastChatUI.html"
TINYLLAMA_SERVER="$SCRIPT_DIR/chat_server.py"
TINYLLAMA_LLAMA_PORT=8080
TINYLLAMA_CHAT_PORT=3333
CONF

ok "Config saved to $BASE_DIR/config.sh"

# ================================================================
# Done
# ================================================================
echo ""
echo -e "${C}================================================${N}"
echo -e "${G} INSTALL COMPLETE!${N}"
echo -e "${C}================================================${N}"
echo ""
echo -e " Model  : ${W}$(basename "$MODEL_PATH")${N}"
echo -e " Size   : ${W}$(du -h "$MODEL_PATH" 2>/dev/null || echo "~400 MB")${N}"
echo -e " Engine : ${W}$LLAMA_BIN${N}"
echo -e " Config : ${W}$BASE_DIR/config.sh${N}"
echo ""
echo -e " Start the AI:"
echo -e " ${W}bash start.sh${N}"
echo ""
