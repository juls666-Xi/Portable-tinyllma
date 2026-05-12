# TinyLlama 1.1B

Run **TinyLlama-1.1B-Chat-v1.0 (Q8_0)** 100% offline on Android using Termux.  
No root. No cloud. No USB drive needed. Runs straight from your phone's storage.

---

## What you get

- **llama.cpp** compiled natively for your ARM64 CPU
- **TinyLlama-1.1B-Chat-v1.0 Q8_0** — ~1.1 GB, fast on any modern phone
- **Dark-mode chat UI** with persistent history at `localhost:3333`
- **OpenAI-compatible API** at `localhost:8080` for developers
- LAN access — other devices on your Wi-Fi can connect too

---

## Requirements

| | Minimum |
|---|---|
| Android | 8.0+ |
| CPU | ARM64 (all phones since ~2015) |
| RAM | 2 GB · 3 GB+ recommended |
| Storage | 3 GB free (build ~1.5 GB + model 1.1 GB) |
| App | **Termux from F-Droid** — see below |

---

## Step 0 — Install Termux (F-Droid only)

> ⚠️ The Play Store version of Termux is broken. Use **F-Droid**.

1. Download F-Droid from [f-droid.org](https://f-droid.org)
2. Open F-Droid → search **Termux** → install
3. Open Termux

---

## Step 1 — Get the project

### Option A — Clone inside Termux

```bash
pkg install git -y
git clone https://github.com/YOUR_REPO/tinyllama-termux.git
cd tinyllama-termux
```

### Option B — Copy via USB cable

1. Plug phone into PC, choose **File Transfer (MTP)** on the notification
2. Copy the `tinyllama-termux` folder to your phone's `Downloads/`
3. In Termux:

```bash
# Grant storage access first (one-time)
termux-setup-storage

# Then navigate to the folder
cd ~/storage/downloads/tinyllama-termux
```

> If `~/storage` doesn't exist yet, run `termux-setup-storage`, tap Allow, then re-open Termux.

---

## Step 2 — Install

Run once. Installs everything to `~/tinyllama/`.

```bash
bash install.sh
```

What it does, step by step:

**[1/4] Packages**
Installs `clang`, `cmake`, `ninja`, `git`, `wget`, `python` via apt/pkg.
Also requests storage permission if not already granted.

**[2/4] Build llama.cpp**
Clones and compiles llama.cpp natively for your CPU.
This takes **10–30 minutes** depending on your device.
- Keep Termux in the **foreground** the whole time
- Do not lock your screen or Android may kill the build
- If it stops, re-run `bash install.sh` — it detects what's already done and skips it

**[3/4] Download model**
Downloads `tinyllama-1.1b-chat-v1.0.Q8_0.gguf` (~1.1 GB) from HuggingFace.
Uses `wget -c` — if your connection drops, re-run `bash install.sh` to resume.

**[4/4] Config**
Writes `~/tinyllama/config.sh` with all paths. You never need to edit this manually.

When install finishes you will see:
```
================================================
  INSTALL COMPLETE!
================================================

  Model  : tinyllama-1.1b-chat-v1.0.Q8_0.gguf
  Engine : /data/data/com.termux/files/home/tinyllama/bin/llama-server
  Config : /data/data/com.termux/files/home/tinyllama/config.sh

  Start the AI:
  bash start.sh
```

---

## Step 3 — Start

```bash
bash start.sh
```

What it does:

1. Reads `~/tinyllama/config.sh`
2. Shows your available RAM — warns if it's below 1 GB
3. Acquires a **wakelock** so Android can't kill the process mid-chat
4. Starts `llama-server` on `localhost:8080` and waits for it to load (~5–20 sec)
5. Asks which UI to open:

```
  Open which UI?
  [1] FastChat  — dark mode, saves history   ← recommended
  [2] Llama.cpp — raw developer interface
  [3] Skip, I'll open the browser myself
```

6. Opens your browser automatically
7. Runs the Python chat proxy on `localhost:3333` (keeps terminal active)

**To stop:** Press `Ctrl+C` in Termux. The engine shuts down cleanly.

---

## Using the Chat UI

### On your phone
Open Chrome (or any browser) and go to:
```
http://localhost:3333
```

### From a PC or tablet on the same Wi-Fi
The start script prints your phone's local IP:
```
  Chat UI (LAN)   : http://192.168.1.42:3333
```
Type that URL in any browser on the same network.

### Raw API (developers)
llama-server exposes an OpenAI-compatible endpoint:
```
http://localhost:8080/v1/chat/completions
```

Example with curl:
```bash
curl http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [{"role":"user","content":"What is 2+2?"}],
    "stream": false
  }'
```

---

## File layout

```
tinyllama-termux/          ← project folder (clone or copy here)
├── install.sh             ← run once to set up everything
├── start.sh               ← run every time to chat
├── chat_server.py         ← Python proxy + chat history server
└── FastChatUI.html        ← dark-mode web chat interface

~/tinyllama/               ← auto-created by install.sh
├── config.sh              ← generated config (paths + ports)
├── bin/
│   ├── llama.cpp/         ← source + build directory
│   └── llama-server       ← compiled engine binary
├── models/
│   └── tinyllama-1.1b-chat-v1.0.Q8_0.gguf   ← 1.1 GB model
├── logs/
│   └── llama-server.log   ← engine output (check here if something breaks)
└── chat_data/
    ├── chats.json         ← your saved conversations
    └── settings.json      ← UI settings (temperature, system prompt)
```

---

## Tips

**Prevent Android from killing Termux mid-session:**

Go to Settings → Apps → Termux → Battery → set to **Unrestricted** (label varies by brand).

**Keep the session alive in the background with tmux:**

```bash
pkg install tmux -y
tmux new -s llama        # start a named session
bash start.sh            # run the AI inside it
# Detach:  Ctrl+B then D
# Return:  tmux attach -t llama
```

**Check if the engine is already running:**

```bash
curl -s http://localhost:8080/v1/models | python3 -m json.tool
```

**Kill a stuck engine:**

```bash
pkill -f llama-server
```

**Check RAM usage:**

```bash
grep -E "MemTotal|MemAvailable" /proc/meminfo
```

**See engine logs live:**

```bash
tail -f ~/tinyllama/logs/llama-server.log
```

---

## Troubleshooting

**"Not installed yet. Run: bash install.sh"**
`~/tinyllama/config.sh` is missing. Run `bash install.sh`.

**Build fails with cmake/clang error**
```bash
apt update -y && apt full-upgrade -y
pkg install -y clang cmake ninja
bash install.sh
```

**Download stops partway through**
Re-run `bash install.sh`. The `-c` flag in wget resumes from where it left off.

**Engine takes more than 2 minutes to start / never comes online**
```bash
cat ~/tinyllama/logs/llama-server.log
```
Most common cause: not enough free RAM. Close all other apps, then retry.

**Model file is corrupted / engine crashes immediately**
```bash
rm ~/tinyllama/models/tinyllama-1.1b-chat-v1.0.Q8_0.gguf
bash install.sh    # re-downloads the model only
```

**Port already in use**
```bash
pkill -f llama-server   # clears port 8080
pkill -f chat_server    # clears port 3333
bash start.sh
```

**`termux-setup-storage` does nothing / storage still not accessible**
Open Android Settings → Apps → Termux → Permissions → Files → Allow.

**Phone gets warm, responses are slow (3–8 tok/s)**
This is normal for CPU inference on a phone. TinyLlama is one of the fastest models at this quality level. A fan or cool environment helps sustained performance.

---

## Uninstall

```bash
# Remove compiled engine + downloaded model (~2.5 GB)
rm -rf ~/tinyllama

# Remove the project folder too
rm -rf ~/storage/downloads/tinyllama-termux   # adjust path
```

Nothing is written outside `~/tinyllama/` and the project folder.

---

## Model details

| | |
|---|---|
| Model | TinyLlama-1.1B-Chat-v1.0 |
| Quantization | Q8_0 — near-lossless 8-bit |
| File size | ~1.1 GB |
| RAM at runtime | ~1.2–1.5 GB |
| Context window | 4096 tokens |
| Chat template | `<\|system\|>` / `<\|user\|>` / `<\|assistant\|>` |
| HuggingFace | [TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF](https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF) |
