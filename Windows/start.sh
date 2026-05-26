
#!/usr/bin/env bash
# ================================================================
# TinyLlama 1.1B Q2_K — Windows Launcher
# Works in Git Bash, MSYS2, or WSL
# ================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG="$HOME/.tinyllama/config.sh"

R='\033[0;31m' Y='\033[1;33m' G='\033[0;32m'
C='\033[0;36m' D='\033[1;30m' W='\033[1;37m' N='\033[0m'

ok() { echo -e "${G} ✓ $1${N}"; }
info() { echo -e "${D} $1${N}"; }
warn() { echo -e "${Y} ! $1${N}"; }
fail() { echo -e "${R} ✗ $1${N}"; exit 1; }

echo ""
echo -e "${C}================================================${N}"
echo -e "${C} TinyLlama 1.1B Q2_K — Windows Launcher ${N}"
echo -e "${C}================================================${N}"
echo ""

if [ ! -f "$CONFIG" ]; then
    fail "Not installed yet. Run: bash install.sh"
fi
source "$CONFIG"

[ -f "$TINYLLAMA_BIN" ] || fail "Engine binary missing. Re-run install.sh."

if [ ! -f "$TINYLLAMA_MODEL" ]; then
    warn "Model not found at: $TINYLLAMA_MODEL"
    FOUND=$(ls "$HOME/.tinyllama/models/"*.gguf 2>/dev/null | head -1)
    [ -n "$FOUND" ] || fail "No .gguf model found. Re-run install.sh."
    TINYLLAMA_MODEL="$FOUND"
    warn "Using fallback: $(basename "$TINYLLAMA_MODEL")"
fi

echo -e " Model  : ${W}$(basename "$TINYLLAMA_MODEL")${N}"
echo -e " Engine : ${W}llama.cpp${N}"
echo -e " Quant  : ${W}Q2_K (ultra-lightweight, ~400MB)${N}"
echo ""

if command -v wmic &>/dev/null; then
    TOTAL_KB=$(wmic ComputerSystem get TotalPhysicalMemory | awk 'NR==2{print $1/1024}')
    AVAIL_KB=$(wmic OS get FreePhysicalMemory | awk 'NR==2{print $1}')
    TOTAL_GB=$(awk "BEGIN{printf \"%.1f\", $TOTAL_KB/1048576}")
    AVAIL_GB=$(awk "BEGIN{printf \"%.1f\", $AVAIL_KB/1048576}")
    echo -e " RAM    : ${W}${AVAIL_GB} GB free${N} / ${TOTAL_GB} GB total"
else
    info "RAM info unavailable on this shell"
fi
echo ""

LLAMA_PID=""

if curl -s "http://127.0.0.1:${TINYLLAMA_LLAMA_PORT}/v1/models" >/dev/null 2>&1; then
    ok "llama-server already running on port ${TINYLLAMA_LLAMA_PORT}"
else
    N_THREADS=$(nproc 2>/dev/null || echo 4)
    N_THREADS=$(( N_THREADS / 2 ))
    [ "$N_THREADS" -lt 2 ] && N_THREADS=2
    [ "$N_THREADS" -gt 8 ] && N_THREADS=8

    info "Starting engine on port ${TINYLLAMA_LLAMA_PORT} with ${N_THREADS} threads..."

    "$TINYLLAMA_BIN" \
        -m "$TINYLLAMA_MODEL" \
        -c 4096 \
        -cb \
        -np 1 \
        -t "$N_THREADS" \
        --port "$TINYLLAMA_LLAMA_PORT" \
        --host 127.0.0.1 \
        > "$HOME/.tinyllama/logs/llama-server.log" 2>&1 &

    LLAMA_PID=$!

    printf " Loading model"
    WAIT=0
    until curl -s "http://127.0.0.1:${TINYLLAMA_LLAMA_PORT}/v1/models" >/dev/null 2>&1; do
        printf "."
        sleep 1
        WAIT=$(( WAIT + 1 ))
        if [ "$WAIT" -ge 120 ]; then
            echo ""
            fail "Engine failed to start after 120s. Check: cat ~/.tinyllama/logs/llama-server.log"
        fi
    done
    echo ""
    ok "Engine online (PID $LLAMA_PID)"
fi

LOCAL_IP="127.0.0.1"
if command -v ip &>/dev/null; then
    LOCAL_IP=$(ip route get 1 2>/dev/null \
        | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1);exit}}')
elif command -v ipconfig &>/dev/null; then
    LOCAL_IP=$(ipconfig | grep -A5 "Wireless\|Ethernet" | grep "IPv4" | head -1 | awk -F: '{print $2}' | tr -d ' ')
fi
[ -z "$LOCAL_IP" ] && LOCAL_IP="127.0.0.1"

echo ""
echo -e "${C}================================================${N}"
echo -e "${G} ENGINE ONLINE${N}"
echo -e "${C}================================================${N}"
echo ""
echo -e " Chat UI (local) : ${W}http://localhost:${TINYLLAMA_CHAT_PORT}${N}"
echo -e " Chat UI (LAN)   : ${W}http://${LOCAL_IP}:${TINYLLAMA_CHAT_PORT}${N}"
echo -e " Raw API         : ${W}http://localhost:${TINYLLAMA_LLAMA_PORT}${N}"
echo ""
echo -e " Open which UI?"
echo -e " ${Y}[1]${N} FastChat — dark mode, saves history ${D}← recommended${N}"
echo -e " ${Y}[2]${N} Llama.cpp — raw developer interface"
echo -e " ${Y}[3]${N} Skip, I'll open the browser myself"
echo ""
read -r -p " Choice (1/2/3): " UI_CHOICE

case "$UI_CHOICE" in
    2) URL="http://localhost:${TINYLLAMA_LLAMA_PORT}" ;;
    3) URL="" ;;
    *) URL="http://localhost:${TINYLLAMA_CHAT_PORT}" ;;
esac

if [ -n "$URL" ]; then
    start "$URL" 2>/dev/null || \
        cmd /c start "$URL" 2>/dev/null || \
        explorer "$URL" 2>/dev/null || \
        info "Could not auto-open browser. Go to: $URL"
fi

echo ""
info "Starting chat proxy on port ${TINYLLAMA_CHAT_PORT}..."
info "Press Ctrl+C to shut down everything."
echo ""

export FASTCHAT_HTML="$TINYLLAMA_UI"

if command -v python3 &>/dev/null; then
    python3 "$TINYLLAMA_SERVER" --no-browser --llama-cpp
elif command -v python &>/dev/null; then
    python "$TINYLLAMA_SERVER" --no-browser --llama-cpp
else
    fail "Python not found. Install Python 3 from python.org"
fi

if [ -n "$LLAMA_PID" ]; then
    kill -9 "$LLAMA_PID" 2>/dev/null || taskkill /F /PID "$LLAMA_PID" 2>/dev/null || true
fi
echo -e "${C} Goodbye.${N}"
