#!/data/data/com.termux/files/usr/bin/bash
# ================================================================
#  TinyLlama 1.1B — Android/Termux Launcher
# ================================================================
#  Starts the llama.cpp server with TinyLlama and opens the
#  FastChat UI in your browser.
#
#  Run ONCE after install:  bash Android/install.sh
#  Then to chat:            bash Android/start.sh
# ================================================================

# ---- Detect Termux ----
if [ -z "$TERMUX_VERSION" ] && [ ! -d "/data/data/com.termux" ]; then
    echo "ERROR: This script must run inside Termux!"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
USB_ROOT="$(dirname "$SCRIPT_DIR")"
SHARED_DIR="$USB_ROOT/Shared"
SHARED_BIN="$SHARED_DIR/bin"
MODELS_DIR="$SHARED_DIR/models"

RED='\033[0;31m'
YLW='\033[1;33m'
GRN='\033[0;32m'
CYN='\033[0;36m'
DGR='\033[1;30m'
WHT='\033[1;37m'
RST='\033[0m'

echo ""
echo -e "${CYN}==========================================================${RST}"
echo -e "${CYN}   TinyLlama 1.1B — Android Native Launcher              ${RST}"
echo -e "${CYN}==========================================================${RST}"
echo ""

# ---- Check engine binary ----
if [ ! -f "$SHARED_BIN/llama-server-android" ]; then
    echo -e "${RED}ERROR: llama-server-android not found!${RST}"
    echo -e "  Run installer first: ${WHT}bash Android/install.sh${RST}"
    exit 1
fi

# ---- Locate TinyLlama model (prefer Q8_0, fallback to any .gguf) ----
MODEL_FILE="$MODELS_DIR/tinyllama-1.1b-chat-v1.0.Q8_0.gguf"

if [ ! -f "$MODEL_FILE" ]; then
    echo -e "${YLW}  TinyLlama Q8_0 not found, scanning for any .gguf...${RST}"
    MODEL_FILE=$(ls "$MODELS_DIR"/*.gguf 2>/dev/null | head -n 1)
fi

if [ -z "$MODEL_FILE" ] || [ ! -f "$MODEL_FILE" ]; then
    echo -e "${RED}ERROR: No .gguf model found in Shared/models/!${RST}"
    echo -e "  Run installer: ${WHT}bash Android/install.sh${RST}"
    exit 1
fi

echo -e "  Model  : ${WHT}$(basename "$MODEL_FILE")${RST}"
echo -e "  Engine : ${WHT}llama.cpp (native ARM)${RST}"
echo ""

# ---- RAM check ----
TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}')
AVAIL_RAM_KB=$(grep MemAvailable /proc/meminfo 2>/dev/null | awk '{print $2}')
TOTAL_RAM_GB=$(awk "BEGIN{printf \"%.1f\", $TOTAL_RAM_KB/1048576}")
AVAIL_RAM_GB=$(awk "BEGIN{printf \"%.1f\", $AVAIL_RAM_KB/1048576}")
echo -e "  RAM    : ${WHT}${AVAIL_RAM_GB} GB available${RST} / ${TOTAL_RAM_GB} GB total"

AVAIL_INT=$(awk "BEGIN{printf \"%d\", $AVAIL_RAM_KB/1048576}")
if [ "$AVAIL_INT" -lt 1 ]; then
    echo -e "${YLW}  WARNING: Very low available RAM. Close other apps and retry.${RST}"
fi
echo ""

# ---- Wakelock ----
echo -e "${DGR}  Acquiring wakelock (prevents Android sleep)...${RST}"
termux-wake-lock 2>/dev/null || true

# ================================================================
# Start llama-server (if not already running)
# ================================================================
LLAMA_PID=""
LLAMA_PORT=8080

if curl -s "http://127.0.0.1:${LLAMA_PORT}/v1/models" > /dev/null 2>&1; then
    echo -e "${GRN}  llama-server already running on port ${LLAMA_PORT}!${RST}"
else
    echo -e "  Starting llama-server..."

    # TinyLlama 1.1B context tuning:
    #   -c 4096  : context window (fits in 2+ GB RAM at Q8_0)
    #   -cb      : enable context batching
    #   -np 1    : single parallel slot (1.1B doesn't benefit from more on mobile)
    #   -t <N>   : threads — use half of available cores for stability
    #   --temp 0.7, --repeat-penalty 1.1 : sensible defaults baked in
    N_THREADS=$(nproc 2>/dev/null || echo 4)
    N_THREADS=$((N_THREADS / 2))
    [ "$N_THREADS" -lt 2 ] && N_THREADS=2

    "$SHARED_BIN/llama-server-android" \
        -m "$MODEL_FILE" \
        -c 4096 \
        -cb \
        -np 1 \
        -t "$N_THREADS" \
        --port "$LLAMA_PORT" \
        --host 127.0.0.1 \
        > "$SHARED_DIR/llama-server.log" 2>&1 &

    LLAMA_PID=$!

    echo -e "  Loading model into memory..."
    WAIT=0
    until curl -s "http://127.0.0.1:${LLAMA_PORT}/v1/models" > /dev/null 2>&1; do
        sleep 1
        WAIT=$((WAIT + 1))
        printf "."
        if [ "$WAIT" -ge 120 ]; then
            echo ""
            echo -e "${RED}ERROR: Engine failed to start after 120 seconds.${RST}"
            echo -e "  Possible causes:"
            echo -e "    - Not enough RAM (close other apps)"
            echo -e "    - Model file corrupted (re-run install.sh)"
            echo -e "  Check logs: ${WHT}cat $SHARED_DIR/llama-server.log${RST}"
            kill -9 "$LLAMA_PID" 2>/dev/null
            termux-wake-unlock 2>/dev/null || true
            exit 1
        fi
    done
    echo ""
    echo -e "${GRN}  Engine is online! (PID: $LLAMA_PID)${RST}"
fi

# ================================================================
# Get local IP for LAN access
# ================================================================
LOCAL_IP="127.0.0.1"
if command -v ip &>/dev/null; then
    LOCAL_IP=$(ip route get 1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1);exit}}')
elif command -v ifconfig &>/dev/null; then
    LOCAL_IP=$(ifconfig wlan0 2>/dev/null | grep 'inet ' | awk '{print $2}' | sed 's/addr://')
fi
[ -z "$LOCAL_IP" ] && LOCAL_IP="127.0.0.1"

CHAT_PORT=3333
echo ""
echo -e "${CYN}==========================================================${RST}"
echo -e "${GRN}  AI ENGINE ONLINE!${RST}"
echo -e "${CYN}==========================================================${RST}"
echo ""
echo -e "  FastChat UI  : ${WHT}http://localhost:${CHAT_PORT}${RST}"
echo -e "  LAN Access   : ${WHT}http://${LOCAL_IP}:${CHAT_PORT}${RST}"
echo -e "  Raw API      : ${WHT}http://localhost:${LLAMA_PORT}${RST}"
echo ""
echo -e "  Which interface?"
echo -e "  ${YLW}[1]${RST} FastChat UI  (dark mode, chat history)   ${DGR}← recommended${RST}"
echo -e "  ${YLW}[2]${RST} Llama.cpp default UI  (raw dev interface)"
echo -e "  ${YLW}[3]${RST} Skip — I'll open the browser myself"
echo ""
read -r -p "  Choice (1/2/3): " UI_CHOICE

case "$UI_CHOICE" in
    2)
        TARGET_URL="http://localhost:${LLAMA_PORT}"
        echo -e "  Opening Llama.cpp UI..."
        ;;
    3)
        echo -e "  Skipping auto-open."
        TARGET_URL=""
        ;;
    *)
        TARGET_URL="http://localhost:${CHAT_PORT}"
        echo -e "  Opening FastChat UI..."
        ;;
esac

if [ -n "$TARGET_URL" ]; then
    am start -a android.intent.action.VIEW -d "$TARGET_URL" 2>/dev/null || \
    termux-open-url "$TARGET_URL" 2>/dev/null || \
    echo -e "  ${RED}Could not auto-open browser.${RST} Go to: ${WHT}$TARGET_URL${RST}"
fi

# ================================================================
# Start Python chat proxy server (FastChatUI backend)
# ================================================================
echo ""
echo -e "${DGR}  Chat server starting on port ${CHAT_PORT}...${RST}"
echo -e "${DGR}  Press Ctrl+C to shut everything down.${RST}"
echo ""

if command -v python3 &>/dev/null; then
    python3 "$SHARED_DIR/chat_server.py" --no-browser --llama-cpp
elif command -v python &>/dev/null; then
    python "$SHARED_DIR/chat_server.py" --no-browser --llama-cpp
else
    echo -e "${RED}ERROR: Python not found!${RST}"
    echo -e "  Install with: ${WHT}pkg install python${RST}"
    [ -n "$LLAMA_PID" ] && kill -9 "$LLAMA_PID" 2>/dev/null
    termux-wake-unlock 2>/dev/null || true
    exit 1
fi

# ---- Cleanup on Ctrl+C ----
[ -n "$LLAMA_PID" ] && kill "$LLAMA_PID" 2>/dev/null
termux-wake-unlock 2>/dev/null || true
echo -e "${CYN}  Goodbye!${RST}"
