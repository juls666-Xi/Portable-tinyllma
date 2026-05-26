
readme = r'''# Portable TinyLlama

Run **TinyLlama 1.1B Chat** locally on your phone, PC, or laptop — completely offline, no cloud, no API keys.

- **Termux/Android** — Run AI on your phone
- **Linux** — Native desktop/server deployment
- **Windows** — Git Bash/MSYS2/WSL support

---

## What's Included

| Component | Purpose |
|-----------|---------|
| `llama.cpp` engine | Fast C++ inference backend |
| `chat_server.py` | Python web proxy + chat history |
| `FastChatUI.html` | Dark-mode web chat interface |
| `install.sh` / `install_linux.sh` / `install_windows.sh` | One-time setup |
| `start.sh` / `start_linux.sh` / `start_windows.sh` | Launch everything |

---

## Model Variants

| Variant | Size | RAM Needed | Quality | Use Case |
|---------|------|------------|---------|----------|
| **Q2_K** (default) | ~400 MB | ~500 MB | Lower | Low-end phones, 2GB RAM devices |
| Q4_K_M | ~600 MB | ~800 MB | Good | Balanced quality/size |
| Q5_K_M | ~750 MB | ~1 GB | Better | Higher quality |
| Q8_0 | ~1.1 GB | ~1.5 GB | Best | High-end devices |

**Default is Q2_K** for maximum compatibility. You can import any GGUF model during install.

---

## Termux / Android

### Requirements
- [Termux from F-Droid](https://f-droid.org/packages/com.termux/) (NOT Play Store version)
- 2 GB RAM minimum (3 GB+ recommended)
- ~500 MB storage for Q2_K model

### Install
```bash
# In Termux
mkdir -p ~/tinyllama-termux && cd ~/tinyllama-termux

# Create install.sh, start.sh, chat_server.py (see files below)
# Download web UI
wget https://raw.githubusercontent.com/juls666-Xi/Portable-tinyllma/main/termux-cli-llm/FastChatUI.html

chmod +x install.sh start.sh
bash install.sh
```

**Keep Termux open during install.** Building llama.cpp takes 10–30 minutes on phone CPUs.

### Start
```bash
bash start.sh
```

### Access from Other Devices
When `start.sh` runs, it prints your phone's LAN IP:
```
Chat UI (LAN) : http://192.168.1.42:3333
```

On another device on the **same Wi-Fi**, open that URL in any browser.

---

## Linux

### Requirements
- Any modern Linux distro (Ubuntu, Fedora, Arch, etc.)
- `sudo` access for package installation
- 2 GB RAM minimum
- Python 3

### Supported Package Managers
- `apt` (Debian/Ubuntu)
- `pacman` (Arch/Manjaro)
- `dnf` (Fedora/RHEL)
- `zypper` (openSUSE)

### Install
```bash
mkdir -p ~/tinyllama-linux && cd ~/tinyllama-linux

# Create install_linux.sh, start_linux.sh, chat_server.py
# Download web UI
wget https://raw.githubusercontent.com/juls666-Xi/Portable-tinyllma/main/termux-cli-llm/FastChatUI.html

chmod +x install_linux.sh start_linux.sh
bash install_linux.sh
```

### Start
```bash
bash start_linux.sh
```

### Import Existing GGUF Model
During install, choose option `[2]` to import an existing model:
```
--- Model Setup ---

 [1] Download Q2_K model from HuggingFace (~400 MB)
 [2] Import existing GGUF file from your system

 Choice (1/2): 2
```

The installer will:
1. Search your home directory for `.gguf` files
2. Show a numbered list of found models
3. Let you pick one or enter a custom path
4. Copy it to `~/.local/share/tinyllama/models/`

---

## Windows

### Requirements
- [Git Bash](https://git-scm.com/download/win) or MSYS2 or WSL
- Python 3 (from [python.org](https://python.org))
- `wget` and `unzip` (included in Git Bash)
- 2 GB RAM minimum

### Install
```bash
# In Git Bash
mkdir -p ~/tinyllama-windows && cd ~/tinyllama-windows

# Create install_windows.sh, start_windows.sh, chat_server_windows.py
# Download web UI
wget https://raw.githubusercontent.com/juls666-Xi/Portable-tinyllma/main/termux-cli-llm/FastChatUI.html

chmod +x install_windows.sh start_windows.sh
bash install_windows.sh
```

The Windows installer downloads a **pre-built `llama-server.exe`** from GitHub releases — no compilation needed.

### Start
```bash
bash start_windows.sh
```

---

## Web Interfaces

When you run `start.sh`, you get three options:

| Option | URL | Description |
|--------|-----|-------------|
| `[1] FastChat` | `http://localhost:3333` | Dark mode, chat history, mobile-friendly |
| `[2] Llama.cpp` | `http://localhost:8080` | Raw developer API interface |
| `[3] Skip` | — | Open browser manually |

### FastChatUI Features
- Dark theme (easy on eyes/battery)
- Persistent chat history (saved locally)
- System prompt configuration
- Temperature control
- Hardware stats display (CPU/RAM usage)
- Works on phone, tablet, or desktop browsers

---

## API Endpoints

| Endpoint | Description |
|----------|-------------|
| `http://localhost:8080/v1/chat/completions` | OpenAI-compatible chat API |
| `http://localhost:8080/v1/models` | List loaded models |
| `http://localhost:3333/api/chats` | Get/save chat history |
| `http://localhost:3333/api/settings` | Get/save settings |
| `http://localhost:3333/api/stats` | CPU/RAM usage |
| `http://localhost:3333/ollama/api/tags` | Ollama-compatible model list |

---

## File Locations

### Termux/Android
```
~/tinyllama/
├── bin/llama-server          # Engine binary
├── models/*.gguf              # AI model
├── logs/llama-server.log      # Engine logs
├── chat_data/                 # Chat history & settings
└── config.sh                  # Paths config
```

### Linux
```
~/.local/share/tinyllama/
├── bin/llama-server
├── models/*.gguf
├── logs/
├── chat_data/
└── config.sh
```

### Windows
```
C:\Users\You\.tinyllama\
├── bin\llama-server.exe
├── models\*.gguf
├── logs\
├── chat_data\
└── config.sh
```

---

## Troubleshooting

### "FastChatUI.html not found"
The HTML file is missing or the path in `config.sh` is wrong.

**Fix:**
```bash
# Find where the file actually is
find ~ -name "FastChatUI.html" 2>/dev/null

# Update config with correct path
cat > ~/.local/share/tinyllama/config.sh << 'EOF'
TINYLLAMA_BASE="$HOME/.local/share/tinyllama"
TINYLLAMA_BIN="$HOME/.local/share/tinyllama/bin/llama-server"
TINYLLAMA_MODEL="$HOME/.local/share/tinyllama/models/tinyllama-1.1b-chat-v1.0.Q2_K.gguf"
TINYLLAMA_UI="/correct/path/to/FastChatUI.html"
TINYLLAMA_SERVER="/correct/path/to/chat_server.py"
TINYLLAMA_LLAMA_PORT=8080
TINYLLAMA_CHAT_PORT=3333
EOF
```

### "Engine failed to start"
Check the log:
```bash
# Termux
cat ~/tinyllama/logs/llama-server.log

# Linux
cat ~/.local/share/tinyllama/logs/llama-server.log

# Windows
cat ~/.tinyllama/logs/llama-server.log
```

Common causes:
- Model file corrupted → re-download
- Port 8080 in use → kill existing process: `killall llama-server`
- Not enough RAM → close other apps

### "Cannot access from other device"
Both devices must be on the **same Wi-Fi network**.

Check your phone's IP:
```bash
ip route get 1 | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1);exit}}'
```

Some public Wi-Fi (hotels, cafes) blocks device-to-device connections.

### Linux `dnf` package install fails
If you're offline or package manager fails, install manually:
```bash
# Fedora
sudo dnf install gcc gcc-c++ cmake ninja-build git wget python3

# Then re-run install_linux.sh
bash install_linux.sh
```

The script now detects existing tools and skips package install if they're present.

### Windows: "Python not found"
Install Python 3 from https://python.org and make sure it's added to PATH.

---

## Swapping Models

To use a different GGUF model:

1. **During install:** Choose option `[2]` to import
2. **After install:** Replace the model file and update `config.sh`:
```bash
# Linux example
cp /path/to/new-model.Q4_K_M.gguf ~/.local/share/tinyllama/models/

# Edit config
sed -i 's|tinyllama-1.1b-chat-v1.0.Q2_K.gguf|new-model.Q4_K_M.gguf|' ~/.local/share/tinyllama/config.sh
```

---

## Performance Tips

| Device | Threads | Context | Expected Speed |
|--------|---------|---------|----------------|
| Phone (8 core) | 4 | 2048 | 5–10 tokens/sec |
| Laptop (4 core) | 2 | 4096 | 10–20 tokens/sec |
| Desktop (8+ core) | 4–8 | 4096 | 20–40 tokens/sec |

Lower context size (`-c`) = faster, less memory.
Higher thread count = faster, more battery drain.

---

## Credits

- [llama.cpp](https://github.com/ggerganov/llama.cpp) by Georgi Gerganov — the inference engine
- [TinyLlama](https://github.com/jzhang38/TinyLlama) by Zhang et al. — the 1.1B model
- [TheBloke](https://huggingface.co/TheBloke) — GGUF quantization
- Original Termux wrapper by [juls666-Xi](https://github.com/juls666-Xi/Portable-tinyllma)

---

## License

This project follows the same license as llama.cpp (MIT). The TinyLlama model is under Apache 2.0.
'''

with open('/mnt/agents/output/README.md', 'w') as f:
    f.write(readme)

print("README.md created successfully!")
print(f"Size: {len(readme)} characters")