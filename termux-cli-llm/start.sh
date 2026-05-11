#!/data/data/com.termux/files/usr/bin/bash
# ================================================================
#  TinyLlama 1.1B — Termux Launcher
#  Usage: bash start.sh
# ================================================================

if [ ! -d "/data/data/com.termux" ]; then
    echo "ERROR: Run this inside Termux."
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG="$HOME/tinyllama/config.sh"

R='\033[0;31m' Y='\033[1;33m' G='\033[0;32m'
C='\033[0;36m' D='\033[1;30m' W='\033[1;37m' N='\033[0m'

ok()   { echo -e "${G}  ✓ $1${N}"; }
info() { echo -e "${D}    $1${N}"; }
warn() { echo -e "${Y}  ! $1${N}"; }
fail() { echo -e "${R}  ✗ $1${N}"; exit 1; }

echo ""
echo -e "${C}================================================${N}"
echo -e "${C}      TinyLlama 1.1B — Termux Launcher          ${N}"
echo -e "${C}================================================${N}"
echo ""

# ---- Load config ----
if [ ! -f "$CONFIG" ]; then
    fail "Not installed yet. Run: bash install.sh"
fi
source "$CONFIG"

# ---- Check binary ----
[ -f "$TINYLLAMA_BIN" ] || fail "Engine binary missing. Re-run install.sh."

# ---- Check model ----
if [ ! -f "$TINYLLAMA_MODEL" ]; then
    warn "Model not found at: $TINYLLAMA_MODEL"
    # fallback: scan models dir
    FOUND=$(ls "$HOME/tinyllama/models/"*.gguf 2>/dev/null | head -1)
    [ -n "$FOUND" ] || fail "No .gguf model found. Re-run install.sh."
    TINYLLAMA_MODEL="$FOUND"
    warn "Using fallback: $(basename "$TINYLLAMA_MODEL")"
fi

echo -e "  Model  : ${W}$(basename "$TINYLLAMA_MODEL")${N}"
echo -e "  Engine : ${W}llama.cpp (native ARM)${N}"
echo ""

# ---- RAM check ----
TOTAL_KB=$(grep MemTotal    /proc/meminfo | awk '{print $2}')
AVAIL_KB=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
TOTAL_GB=$(awk "BEGIN{printf \"%.1f\", $TOTAL_KB/1048576}")
AVAIL_GB=$(awk "BEGIN{printf \"%.1f\", $AVAIL_KB/1048576}")
echo -e "  RAM    : ${W}${AVAIL_GB} GB free${N} / ${TOTAL_GB} GB total"

AVAIL_INT=$(awk "BEGIN{printf \"%d\", $AVAIL_KB/1048576}")
if [ "$AVAIL_INT" -lt 1 ]; then
    warn "Very low RAM! Close all other apps, then retry."
    read -r -p "  Continue anyway? (y/N): " ANS
    [[ "$ANS" =~ ^[Yy]$ ]] || exit 0
fi
echo ""

# ---- Wakelock ----
info "Acquiring wakelock..."
termux-wake-lock 2>/dev/null || true

# ================================================================
# Start llama-server
# ================================================================
LLAMA_PID=""

if curl -s "http://127.0.0.1:${TINYLLAMA_LLAMA_PORT}/v1/models" >/dev/null 2>&1; then
    ok "llama-server already running on port ${TINYLLAMA_LLAMA_PORT}"
else
    # Thread count: half of cores, min 2, max 8
    N_THREADS=$(nproc 2>/dev/null || echo 4)
    N_THREADS=$(( N_THREADS / 2 ))
    [ "$N_THREADS" -lt 2 ] && N_THREADS=2
    [ "$N_THREADS" -gt 8 ] && N_THREADS=8

    info "Starting engine on port ${TINYLLAMA_LLAMA_PORT} with ${N_THREADS} threads..."

    "$TINYLLAMA_BIN" \
        -m  "$TINYLLAMA_MODEL" \
        -c  4096 \
        -cb \
        -np 1 \
        -t  "$N_THREADS" \
        --port "$TINYLLAMA_LLAMA_PORT" \
        --host 127.0.0.1 \
        > "$HOME/tinyllama/logs/llama-server.log" 2>&1 &

    LLAMA_PID=$!

    printf "  Loading model"
    WAIT=0
    until curl -s "http://127.0.0.1:${TINYLLAMA_LLAMA_PORT}/v1/models" >/dev/null 2>&1; do
        printf "."
        sleep 1
        WAIT=$(( WAIT + 1 ))
        if [ "$WAIT" -ge 120 ]; then
            echo ""
            fail "Engine failed to start after 120s. Check: cat ~/tinyllama/logs/llama-server.log"
        fi
    done
    echo ""
    ok "Engine online (PID $LLAMA_PID)"
fi

# ================================================================
# Local IP for LAN access
# ================================================================
LOCAL_IP="127.0.0.1"
if command -v ip &>/dev/null; then
    LOCAL_IP=$(ip route get 1 2>/dev/null \
        | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1);exit}}')
fi
[ -z "$LOCAL_IP" ] && LOCAL_IP="127.0.0.1"

echo ""
echo -e "${C}================================================${N}"
echo -e "${G}  ENGINE ONLINE${N}"
echo -e "${C}================================================${N}"
echo ""
echo -e "  Chat UI (phone) : ${W}http://localhost:${TINYLLAMA_CHAT_PORT}${N}"
echo -e "  Chat UI (LAN)   : ${W}http://${LOCAL_IP}:${TINYLLAMA_CHAT_PORT}${N}"
echo -e "  Raw API         : ${W}http://localhost:${TINYLLAMA_LLAMA_PORT}${N}"
echo ""
echo -e "  Open which UI?"
echo -e "  ${Y}[1]${N} FastChat  — dark mode, saves history   ${D}← recommended${N}"
echo -e "  ${Y}[2]${N} Llama.cpp — raw developer interface"
echo -e "  ${Y}[3]${N} Skip, I'll open the browser myself"
echo ""
read -r -p "  Choice (1/2/3): " UI_CHOICE

case "$UI_CHOICE" in
    2) URL="http://localhost:${TINYLLAMA_LLAMA_PORT}" ;;
    3) URL="" ;;
    *) URL="http://localhost:${TINYLLAMA_CHAT_PORT}" ;;
esac

if [ -n "$URL" ]; then
    am start -a android.intent.action.VIEW -d "$URL" 2>/dev/null \
    || termux-open-url "$URL" 2>/dev/null \
    || info "Could not auto-open browser. Go to: $URL"
fi

# ================================================================
# Python chat proxy (FastChatUI backend)
# ================================================================
echo ""
info "Starting chat proxy on port ${TINYLLAMA_CHAT_PORT}..."
info "Press Ctrl+C to shut down everything."
echo ""

# Patch chat_server.py to look for FastChatUI.html next to itself
export FASTCHAT_HTML="$TINYLLAMA_UI"

if command -v python3 &>/dev/null; then
    python3 "$TINYLLAMA_SERVER" --no-browser --llama-cpp
elif command -v python &>/dev/null; then
    python  "$TINYLLAMA_SERVER" --no-browser --llama-cpp
else
    fail "Python not found. Run: pkg install python"
fi

# ---- Cleanup ----
[ -n "$LLAMA_PID" ] && kill -9 "$LLAMA_PID" 2>/dev/null
termux-wake-unlock 2>/dev/null || true
echo -e "${C}  Goodbye.${N}"
