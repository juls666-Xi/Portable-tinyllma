#!/data/data/com.termux/files/usr/bin/bash
# ================================================================
#  TINYLLAMA-1.1B — Android/Termux Native Installer (Llama.cpp)
# ================================================================
#  Compiles llama.cpp natively on your Android device and
#  downloads TinyLlama-1.1B-Chat-v1.0.Q8_0 (~1.1 GB).
#
#  Requirements:
#    - Termux (from F-Droid — NOT Play Store)
#    - ~3 GB free storage (build artifacts + model)
#    - Internet connection for initial setup
# ================================================================

# ---- Detect Termux ----
if [ -z "$TERMUX_VERSION" ] && [ ! -d "/data/data/com.termux" ]; then
    echo "ERROR: This script must run inside Termux!"
    echo "Install Termux from F-Droid: https://f-droid.org/en/packages/com.termux/"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
USB_ROOT="$(dirname "$SCRIPT_DIR")"
SHARED_DIR="$USB_ROOT/Shared"
SHARED_BIN="$SHARED_DIR/bin"
MODELS_DIR="$SHARED_DIR/models"

mkdir -p "$SHARED_BIN" "$MODELS_DIR"

RED='\033[0;31m'
YLW='\033[1;33m'
GRN='\033[0;32m'
CYN='\033[0;36m'
MAG='\033[0;35m'
DGR='\033[1;30m'
WHT='\033[1;37m'
RST='\033[0m'

echo ""
echo -e "${CYN}==========================================================${RST}"
echo -e "${CYN}   TinyLlama 1.1B — Android/Termux Installer             ${RST}"
echo -e "${CYN}   Engine: llama.cpp (native ARM build)                   ${RST}"
echo -e "${CYN}==========================================================${RST}"

# ================================================================
# 1. System & Dependencies
# ================================================================
echo ""
echo -e "${YLW}[1/4] Preparing Termux environment...${RST}"

if [ ! -d "$HOME/storage" ]; then
    echo -e "${DGR}      Requesting storage permission...${RST}"
    termux-setup-storage 2>/dev/null || true
    sleep 2
fi

echo -e "${DGR}      Updating packages and installing build tools...${RST}"
apt update -y 2>/dev/null
apt full-upgrade -y 2>/dev/null
pkg install -y clang cmake git wget ninja python

TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}')
TOTAL_RAM_GB=$(awk "BEGIN{printf \"%.1f\", $TOTAL_RAM_KB/1048576}")
echo -e "${GRN}      Dependencies installed! Device RAM: ${TOTAL_RAM_GB} GB${RST}"

RAM_INT=$(awk "BEGIN{printf \"%d\", $TOTAL_RAM_KB/1048576}")
if [ "$RAM_INT" -lt 2 ]; then
    echo -e "${YLW}      WARNING: Low RAM (${TOTAL_RAM_GB} GB). TinyLlama Q8_0 needs ~1.2 GB.${RST}"
    echo -e "${YLW}      Close all other apps before running start.sh.${RST}"
fi

# ================================================================
# 2. Download UI vendor assets
# ================================================================
echo ""
echo -e "${YLW}[2/4] Downloading UI assets (offline fonts/markdown)...${RST}"
VENDOR_DIR="$SHARED_DIR/vendor"
mkdir -p "$VENDOR_DIR"
VENDOR_SCRIPT="$SHARED_DIR/scripts/download-ui-assets.sh"
if [ -f "$VENDOR_SCRIPT" ]; then
    bash "$VENDOR_SCRIPT" "$VENDOR_DIR"
else
    echo -e "${DGR}      Vendor script not found, skipping.${RST}"
fi

# ================================================================
# 3. Compile llama.cpp natively for ARM
# ================================================================
echo ""
echo -e "${YLW}[3/4] Building llama.cpp Engine (ARM native)...${RST}"
cd "$SHARED_BIN"

if [ ! -d "llama.cpp" ]; then
    echo -e "${DGR}      Cloning llama.cpp (shallow clone)...${RST}"
    git clone --depth=1 https://github.com/ggerganov/llama.cpp.git
fi

cd llama.cpp

if [ ! -f "build/bin/llama-server" ]; then
    echo -e "${MAG}      Compiling for your processor — do NOT close Termux!${RST}"
    echo -e "${MAG}      This takes 10–30 min depending on your device.${RST}"

    termux-wake-lock 2>/dev/null || true

    rm -rf build 2>/dev/null
    cmake -B build -GNinja \
        -DLLAMA_BUILD_SERVER=ON \
        -DLLAMA_BUILD_TESTS=OFF \
        -DCMAKE_BUILD_TYPE=Release
    cmake --build build --config Release --target llama-server -j$(nproc)

    termux-wake-unlock 2>/dev/null || true
    echo -e "${GRN}      Compilation complete!${RST}"
else
    echo -e "${GRN}      Engine already compiled — skipping.${RST}"
fi

cp build/bin/llama-server "$SHARED_BIN/llama-server-android" 2>/dev/null
if [ ! -f "$SHARED_BIN/llama-server-android" ]; then
    echo -e "${RED}ERROR: Build failed. Check the output above for errors.${RST}"
    exit 1
fi

# ================================================================
# 4. Download TinyLlama-1.1B-Chat-v1.0.Q8_0
# ================================================================
echo ""
echo -e "${YLW}[4/4] Downloading TinyLlama-1.1B-Chat-v1.0.Q8_0 (~1.1 GB)...${RST}"

MODEL_FILE="tinyllama-1.1b-chat-v1.0.Q8_0.gguf"
MODEL_URL="https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q8_0.gguf"
MODEL_PATH="$MODELS_DIR/$MODEL_FILE"

cd "$MODELS_DIR"

if [ -f "$MODEL_PATH" ]; then
    FILE_SIZE=$(stat -c%s "$MODEL_PATH" 2>/dev/null || stat -f%z "$MODEL_PATH" 2>/dev/null || echo 0)
    if [ "$FILE_SIZE" -gt 1000000000 ]; then
        echo -e "${GRN}      $MODEL_FILE already present!${RST}"
    else
        echo -e "${YLW}      File looks incomplete. Re-downloading...${RST}"
        rm -f "$MODEL_PATH"
    fi
fi

if [ ! -f "$MODEL_PATH" ]; then
    echo -e "${DGR}      Saving to: $MODEL_PATH${RST}"
    echo -e "${DGR}      Tip: If interrupted, re-run install.sh — wget -c resumes.${RST}"
    termux-wake-lock 2>/dev/null || true
    wget -c "$MODEL_URL" -O "$MODEL_PATH" --show-progress
    termux-wake-unlock 2>/dev/null || true

    FILE_SIZE=$(stat -c%s "$MODEL_PATH" 2>/dev/null || stat -f%z "$MODEL_PATH" 2>/dev/null || echo 0)
    if [ "$FILE_SIZE" -lt 1000000000 ]; then
        echo -e "${RED}ERROR: Download incomplete (got $(du -sh "$MODEL_PATH" | cut -f1)).${RST}"
        echo -e "${YLW}      Re-run install.sh to resume, or manually place the file at:${RST}"
        echo -e "${WHT}      $MODEL_PATH${RST}"
        exit 1
    fi
    echo -e "${GRN}      Download complete!${RST}"
fi

# ================================================================
# Done
# ================================================================
echo ""
echo -e "${CYN}==========================================================${RST}"
echo -e "${GRN}   SETUP COMPLETE!${RST}"
echo -e "${CYN}==========================================================${RST}"
echo ""
echo -e "  Model  : ${WHT}$MODEL_FILE${RST}"
echo -e "  Engine : ${WHT}llama.cpp (native ARM)${RST}"
echo -e "  Stored : ${WHT}$MODELS_DIR${RST}"
echo ""
echo -e "  To start the AI, run:"
echo -e "  ${WHT}bash Android/start.sh${RST}"
echo ""
read -n 1 -s -r -p "Press any key to close..."
echo ""
