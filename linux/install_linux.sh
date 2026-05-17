#!/usr/bin/env bash
# ================================================================
# TinyLlama 1.1B — Linux Native Installer (Q2_K Edition)
# With GGUF import support + error handling
# Run this once. Everything installs to ~/.local/share/tinyllama/
# ================================================================

set -e

BASE_DIR="$HOME/.local/share/tinyllama"
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
    echo -e "${C} TinyLlama 1.1B Q2_K — Linux Installer ${N}"
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
    info "Looking for .gguf files in common locations..."

    # Search common locations (exclude the target model dir to avoid duplicates)
    FOUND_FILES=$(find "$HOME" -name "*.gguf" -type f 2>/dev/null | grep -v "$MODEL_DIR" | head -20)

    if [ -n "$FOUND_FILES" ]; then
        echo ""
        echo -e "${G}Found these GGUF files:${N}"
        echo "$FOUND_FILES" | nl -w2 -s') '
        echo ""
        echo -e " ${Y}[0]${N} None of these — I'll enter the path manually"
        echo ""
        read -r -p " Select file number (or 0 for manual): " FILE_NUM || true

        if [ "$FILE_NUM" = "0" ]; then
            echo ""
            read -r -p " Enter full path to your .gguf file: " CUSTOM_PATH || true
            if [ -f "$CUSTOM_PATH" ] && [[ "$CUSTOM_PATH" == *.gguf ]]; then
                MODEL_FILE=$(basename "$CUSTOM_PATH")
                # Check if file is already in the target directory
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
            SELECTED=$(echo "$FOUND_FILES" | sed -n "${FILE_NUM}p")
            if [ -n "$SELECTED" ] && [ -f "$SELECTED" ]; then
                MODEL_FILE=$(basename "$SELECTED")
                # Check if file is already in the target directory
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
        warn "No .gguf files found in $HOME (outside of $MODEL_DIR)"
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
# 1. Detect distro and install packages
# ================================================================
step 1 "Installing packages..."

# Check if required tools already exist
HAVE_ALL=true
for tool in gcc cmake ninja git wget python3; do
    if ! command -v $tool &>/dev/null; then
        HAVE_ALL=false
        break
    fi
done

if [ "$HAVE_ALL" = true ]; then
    ok "All required packages already installed."
else
    info "Some packages missing. Attempting to install..."

    if command -v apt &>/dev/null; then
        PKG_MGR="apt"
        sudo apt update -y || warn "apt update failed — continuing anyway"
        sudo apt install -y build-essential cmake ninja-build git wget python3 python3-pip || warn "Some packages failed to install"
    elif command -v pacman &>/dev/null; then
        PKG_MGR="pacman"
        sudo pacman -Sy --noconfirm base-devel cmake ninja git wget python python-pip || warn "Some packages failed to install"
    elif command -v dnf &>/dev/null; then
        PKG_MGR="dnf"
        sudo dnf install -y gcc gcc-c++ cmake ninja-build git wget python3 python3-pip || warn "Some packages failed to install"
    elif command -v zypper &>/dev/null; then
        PKG_MGR="zypper"
        sudo zypper install -y gcc gcc-c++ cmake ninja git wget python3 python3-pip || warn "Some packages failed to install"
    else
        warn "Unknown package manager. Please install manually: build-essential cmake ninja-build git wget python3"
    fi

    # Re-check
    HAVE_ALL=true
    for tool in gcc cmake ninja git wget python3; do
        if ! command -v $tool &>/dev/null; then
            HAVE_ALL=false
            break
        fi
    done

    if [ "$HAVE_ALL" = false ]; then
        echo ""
        warn "Some required tools are still missing after install attempt."
        warn "Please install manually and re-run this script."
        echo ""
        echo "Required: gcc, cmake, ninja, git, wget, python3"
        echo ""
        read -r -p " Continue anyway? (y/N): " ANS || true
        [[ "$ANS" =~ ^[Yy]$ ]] || exit 0
    fi
fi

ok "Packages ready"

RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
RAM_GB=$(awk "BEGIN{printf \"%.1f\", $RAM_KB/1048576}")
info "Device RAM: ${RAM_GB} GB"

AVAIL_KB=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
AVAIL_INT=$(awk "BEGIN{printf \"%d\", $AVAIL_KB/1048576}")
if [ "$AVAIL_INT" -lt 1 ]; then
    warn "Low available RAM. Close other apps before running start.sh."
fi

# ================================================================
# 2. Build llama.cpp
# ================================================================
step 2 "Building llama.cpp engine..."

cd "$BIN_DIR"

if [ ! -d "llama.cpp" ]; then
    info "Cloning llama.cpp..."
    git clone --depth=1 https://github.com/ggerganov/llama.cpp.git || fail "Failed to clone llama.cpp. Check internet connection."
fi

cd llama.cpp

if [ -f "build/bin/llama-server" ]; then
    ok "Engine already compiled, skipping build."
else
    warn "Compiling natively..."
    rm -rf build
    cmake -B build -GNinja \
        -DLLAMA_BUILD_SERVER=ON \
        -DLLAMA_BUILD_TESTS=OFF \
        -DCMAKE_BUILD_TYPE=Release || fail "cmake configuration failed"
    cmake --build build --config Release --target llama-server -j$(nproc) || fail "Build failed"
    ok "Compilation done."
fi

cp build/bin/llama-server "$BIN_DIR/llama-server"
[ -f "$BIN_DIR/llama-server" ] || fail "Build failed — check output above."
ok "Engine binary ready: $BIN_DIR/llama-server"

# ================================================================
# 3. Download or verify model
# ================================================================
step 3 "Setting up model..."

# If user chose to import, model is already in place
if [ -n "$MODEL_PATH" ] && [ -f "$MODEL_PATH" ]; then
    ok "Using imported model: $(basename "$MODEL_PATH")"
else
    # Download default Q2_K model
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
        info "If interrupted, re-run install.sh — download resumes."
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
# TinyLlama Linux config — auto-generated by install.sh
TINYLLAMA_BASE="$BASE_DIR"
TINYLLAMA_BIN="$BIN_DIR/llama-server"
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
echo -e " Size   : ${W}$(du -h "$MODEL_PATH" | cut -f1)${N}"
echo -e " Engine : ${W}$BIN_DIR/llama-server${N}"
echo -e " Config : ${W}$BASE_DIR/config.sh${N}"
echo ""
echo -e " Start the AI:"
echo -e " ${W}bash start.sh${N}"
echo ""
