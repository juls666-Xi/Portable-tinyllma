# TinyLlama-1.1B — Android/Termux AI (llama.cpp)

Run **TinyLlama-1.1B-Chat-v1.0.Q8_0** fully offline on Android via Termux.  
No root required. No internet needed after setup.

---

## Requirements

| Item | Minimum |
|------|---------|
| Android | 8.0+ (ARM64) |
| RAM | 2 GB (3 GB+ recommended) |
| Storage | 3 GB free (model + build) |
| App | [Termux from F-Droid](https://f-droid.org/en/packages/com.termux/) ⚠️ NOT Play Store |

> **⚠️ Use F-Droid Termux only.** The Play Store version has broken API access.

---

## Quick Start

### Step 1 — Get the project
```bash
# Option A: git clone inside Termux
pkg install git -y
git clone https://github.com/YOUR_FORK/TinyLlama-Termux.git
cd TinyLlama-Termux

# Option B: copy the folder to your phone via USB file transfer,
# then open Termux and cd to it
cd /sdcard/TinyLlama-Termux   # adjust path as needed
```

### Step 2 — Install (one time only)
```bash
bash Android/install.sh
```
This will:
1. Install build tools (`clang`, `cmake`, `ninja`, etc.)
2. Download and compile **llama.cpp** natively for your CPU (~10–30 min)
3. Download **TinyLlama-1.1B-Chat-v1.0.Q8_0.gguf** (~1.1 GB)

> Keep Termux in the foreground during compilation and download.  
> If interrupted, re-run `install.sh` — the download resumes automatically.

### Step 3 — Start chatting
```bash
bash Android/start.sh
```
- Opens **FastChat UI** at `http://localhost:3333` (dark mode, saves history)
- Or raw llama.cpp UI at `http://localhost:8080`

---

## Tips

**Prevent Android from killing Termux:**
```bash
termux-wake-lock   # run before starting
```

**Run in background (Termux session):**  
Use `tmux` or just leave Termux open. Android may kill background processes.

**Low RAM device?**  
Close all other apps before running `start.sh`. TinyLlama Q8_0 needs ~1.2 GB RAM.

**LAN access from PC/tablet:**  
The start script prints your local IP (`http://192.168.x.x:3333`).  
Open that URL in any browser on the same Wi-Fi network.

---

## File Layout

```
TinyLlama-Termux/
├── Android/
│   ├── install.sh       ← run first (builds engine + downloads model)
│   └── start.sh         ← run to chat
└── Shared/
    ├── FastChatUI.html  ← web chat interface
    ├── chat_server.py   ← Python proxy server (port 3333)
    ├── chat_data/       ← saved chat history (auto-created)
    ├── models/
    │   └── tinyllama-1.1b-chat-v1.0.Q8_0.gguf  ← ~1.1 GB
    └── bin/
        └── llama-server-android  ← compiled engine binary
```

---

## Model Info

| Property | Value |
|----------|-------|
| Model | TinyLlama-1.1B-Chat-v1.0 |
| Quantization | Q8_0 (highest quality at this size) |
| Size | ~1.1 GB |
| Context | 4096 tokens |
| Source | [TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF](https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF) |

---

## Troubleshooting

**Engine fails to start:**
```bash
cat Shared/llama-server.log
```

**Download interrupted:**  
Just re-run `bash Android/install.sh` — `wget -c` resumes the download.

**`pkg: command not found` / weird errors:**  
Make sure you're using **F-Droid Termux**, not Play Store Termux.

**Port 8080 already in use:**  
Kill existing llama-server: `pkill llama-server-android`

---

Based on [techjarves/USB-Uncensored-LLM](https://github.com/techjarves/USB-Uncensored-LLM) — stripped to Android/Termux only with TinyLlama.
