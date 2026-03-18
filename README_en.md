# 🦞 虾道 (Xiadao) Installer / LobsterDeploy

> WSL/Linux Automated Installation Script | Enterprise DevOps Edition

[![Version](https://img.shields.io/badge/version-v1.1.0-blue)](https://github.com/YNanxing/openclaw-installer)
[![Platform](https://img.shields.io/badge/platform-Linux-green)](https://github.com/YNanxing/openclaw-installer)
[![License](https://img.shields.io/badge/license-MIT-yellow)](LICENSE)

A one-click automated Shell script for installing [OpenClaw](https://github.com/openclaw/openclaw), specifically optimized for the Chinese network environment, featuring intelligent mirror source switching and automatic proxy node selection.

**Xiadao (虾道)** - Takes "Xia" (Lobster) combined with "Dao" (The Way) to convey professionalism, with a homophone meaning "Chivalrous Way" (侠道) for a touch of hacker culture.

**LobsterDeploy** - Lobster + Deploy. Concise, powerful, and full of DevOps aesthetics.

## ✨ Features

- 🚀 **One-Click Installation** - 8-step automated process requiring no manual intervention.
- 🌐 **Network Optimization** - Automatically configures Tsinghua TUNA, domestic NPM mirrors, and GitHub proxy nodes.
- 🔍 **Smart Speed Test** - Automatically selects the fastest NPM registry and FNM download node.
- 🛡️ **Secure & Robust** - Comprehensive error handling, logging, and interrupt recovery mechanisms.
- 📊 **Visual Feedback** - True-color terminal output and progress bar animations for clear installation status.
- 🧹 **Auto Cleanup** - Automatically generates an environment cleanup script in case of installation failure.

## 🚀 Quick Start

### One-Click Installation (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/YNanxing/openclaw-installer/main/install.sh | bash
```

For domestic (Chinese) environments via Gitee:

```bash
curl -fsSL https://gitee.com/s1/openclaw-installer/raw/main/install.sh | bash
```

Or using wget:

```bash
wget -qO- https://raw.githubusercontent.com/YNanxing/openclaw-installer/main/install.sh | bash
```

### Manual Download & Installation

```bash
# Download the script
curl -fsSL -o install.sh https://raw.githubusercontent.com/YNanxing/openclaw-installer/main/install.sh

# Grant execution permissions
chmod +x install.sh

# Run the installation
./install.sh
```

## 📋 System Requirements

| Item | Requirement |
|------|------|
| OS | Linux (WSL / Debian / Ubuntu) |
| Bash Version | >= 4.4 |
| Network | Internet access (Proxies supported) |
| Permissions | Standard User (Root not required, but `sudo` is needed) |

**Supported Distributions:**
- ✅ Ubuntu 20.04 / 22.04 / 24.04
- ✅ Debian 11 / 12
- ✅ WSL2 (Windows 10/11)

## 🔧 Installation Process

The script will automatically execute the following 8 stages:

1. **Environment Check** - Detects OS version, auto-configures Tsinghua mirror source.
2. **Dependencies** - Installs basic components (git, curl, build-essential, etc.).
3. **FNM Installation** - Multi-node smart speed-test download, SHA-256 verification.
4. **Node.js Installation** - Auto-installs Node.js v24, configures environment variables.
5. **OpenClaw Installation** - Installs OpenClaw CLI globally via NPM.
6. **Verification** - Validates Node, NPM, and OpenClaw components.
7. **Configuration Wizard** - Executes `openclaw onboard` for initial setup.
8. **Completion Prompt** - Displays common commands and next steps.

## 📁 Installation Paths

| Component | Path |
|------|------|
| FNM | `~/.local/share/fnm` |
| Node.js | `~/.local/share/fnm/node-versions/` |
| OpenClaw | Global NPM installation path |
| Log Files | `~/.openclaw_install_YYYYMMDD_HHMMSS.log` |

## 🛠️ Common Commands

### OpenClaw Commands

```bash
openclaw dashboard                 # Open the dashboard
openclaw gateway status            # Check service status
openclaw logs --follow             # Tail real-time logs
openclaw doctor                    # Environment diagnostics
openclaw onboard --install-daemon  # Reconfigure components
```

### WSL Common Commands

```powershell
# Installation & Management
wsl --install -d Debian         # Install Debian
wsl --list --verbose            # View WSL status
wsl --terminate Debian          # Terminate specific distro
wsl --shutdown                  # Shutdown all WSL instances

# Backup & Restore
wsl --export Debian D:\backup.tar     # Export backup
wsl --import Debian D:\WSL\Debian D:\backup.tar  # Import/Restore
```

### Linux Common Commands

```bash
# File Operations
ls -la                          # List files
rm -rf dir/                     # Delete directory
tail -f ~/.openclaw/logs/*.log  # View OpenClaw logs

# System
sudo apt update && sudo apt upgrade -y   # Update system
df -h                           # Disk usage
free -h                         # Memory usage

# Processes
ps aux | grep openclaw          # Find OpenClaw processes
kill -9 PID                     # Kill process by PID
```

## 🌐 Proxy Configuration

The script automatically detects and utilizes system proxy environment variables:

```bash
# Set parameters before running if a proxy is needed
export http_proxy=http://127.0.0.1:7890
export https_proxy=http://127.0.0.1:7890
./install.sh
```

## 📝 Logs & Troubleshooting

Installation logs are saved by default to: `~/.openclaw_install_YYYYMMDD_HHMMSS.log`

If the installation is interrupted, the script provides targeted cleanup guidelines based on the current stage and automatically generates a `~/.openclaw_cleanup.sh` script to revert changes.

## ⚠️ Important Notices

1. **Do not run as root** - The script will automatically request `sudo` privileges when necessary.
2. **Existing Installation Detection** - If an existing OpenClaw setup is detected, you will be prompted before overwriting.
3. **Terminal Restart** - It is highly recommended to close and reopen your terminal instance after installation to properly load new environment variables.

## 📜 Changelog

### v1.1.0 (2026-03-16)
- Optimized FNM download node selection logic.
- Enhanced error handling and interrupt recovery mechanisms.
- Improved terminal color output compatibility.

### v1.0.12
- Added automatic switching for GitHub proxy nodes.
- Optimized NPM mirror source speed test logic.

### v1.0.11
- Fixed WSL environment detection issues.

*[View Full Changelog](CHANGELOG.md)*

## 🤝 Contributing

Issues and Pull Requests are welcome!

## 📄 License

[MIT](LICENSE) © 2026

---

> 🦞 Making OpenClaw deployment simple and elegant.
