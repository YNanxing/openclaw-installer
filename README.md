# 🦞 虾道安装器 / LobsterDeploy

> WSL/Linux 自动化装机脚本 | Enterprise DevOps Edition

[![Version](https://img.shields.io/badge/version-v1.0.13-blue)](https://github.com/yourusername/openclaw-installer)
[![Platform](https://img.shields.io/badge/platform-Linux-green)](https://github.com/yourusername/openclaw-installer)
[![License](https://img.shields.io/badge/license-MIT-yellow)](LICENSE)

一键自动化安装 [OpenClaw](https://github.com/openclaw/openclaw) 的 Shell 脚本，专为国内网络环境优化，支持智能镜像源切换和代理节点自动选择。

**虾道** - 取小龙虾之「虾」，配合「道」字显专业，谐音「侠道」有江湖气。

**LobsterDeploy** - Lobster(小龙虾) + Deploy(部署)，简洁有力，DevOps 范儿十足。

## ✨ 功能特性

- 🚀 **一键安装** - 8 步自动化流程，全程无需人工干预
- 🌐 **国内优化** - 自动配置清华 TUNA、NPM 国内镜像、GitHub 代理节点
- 🔍 **智能测速** - 自动选择最快的 NPM 注册表和 FNM 下载节点
- 🛡️ **安全健壮** - 完善的错误处理、日志记录、中断恢复机制
- 📊 **可视反馈** - 真彩色终端输出，进度条动画，安装状态一目了然
- 🧹 **自动清理** - 安装失败时自动生成环境清理脚本

## 🚀 快速开始

### 一键安装（推荐）

```bash
curl -fsSL https://raw.githubusercontent.com/yourusername/openclaw-installer/main/install.sh | bash
```

或使用 wget：

```bash
wget -qO- https://raw.githubusercontent.com/yourusername/openclaw-installer/main/install.sh | bash
```

### 手动下载安装

```bash
# 下载脚本
curl -fsSL -o install.sh https://raw.githubusercontent.com/yourusername/openclaw-installer/main/install.sh

# 赋予执行权限
chmod +x install.sh

# 运行安装
./install.sh
```

## 📋 系统要求

| 项目 | 要求 |
|------|------|
| 操作系统 | Linux (WSL/Debian/Ubuntu) |
| Bash 版本 | >= 4.4 |
| 网络 | 可访问互联网（支持代理） |
| 权限 | 普通用户（无需 root，但需 sudo） |

**支持的发行版：**
- ✅ Ubuntu 20.04 / 22.04 / 24.04
- ✅ Debian 11 / 12
- ✅ WSL2 (Windows 10/11)

## 🔧 安装流程

脚本将自动执行以下 8 个阶段：

1. **环境检查** - 检测系统版本，自动配置清华镜像源
2. **依赖安装** - 安装 git、curl、build-essential 等基础组件
3. **FNM 安装** - 多节点智能测速下载，SHA-256 校验
4. **Node.js 安装** - 自动安装 Node.js v24，配置环境变量
5. **OpenClaw 安装** - 从 NPM 安装 OpenClaw CLI
6. **安装验证** - 验证 Node、NPM、OpenClaw 组件
7. **配置向导** - 执行 `openclaw onboard` 初始化配置
8. **完成提示** - 显示常用命令和后续指引

## 📁 安装路径

| 组件 | 路径 |
|------|------|
| FNM | `~/.local/share/fnm` |
| Node.js | `~/.local/share/fnm/node-versions/` |
| OpenClaw | 全局 NPM 安装 |
| 日志文件 | `~/.openclaw_install_YYYYMMDD_HHMMSS.log` |

## 🛠️ 常用命令

### OpenClaw 命令

```bash
openclaw dashboard              # 打开控制台
openclaw gateway status         # 查看服务状态
openclaw logs --follow          # 实时日志
openclaw doctor                 # 环境诊断
openclaw onboard --install-daemon  # 重新配置
```

### WSL 常用命令

```powershell
# 安装/管理
wsl --install -d Debian         # 安装 Debian
wsl --list --verbose            # 查看状态
wsl --terminate Debian          # 终止发行版
wsl --shutdown                  # 关闭所有 WSL

# 备份/恢复
wsl --export Debian D:\backup.tar     # 导出备份
wsl --import Debian D:\WSL\Debian D:\backup.tar  # 导入恢复
```

### Linux 常用命令

```bash
# 文件操作
ls -la                          # 列出文件
rm -rf dir/                     # 删除目录
tail -f ~/.openclaw/logs/*.log  # 查看日志

# 系统
sudo apt update && sudo apt upgrade -y   # 更新系统
df -h                           # 磁盘使用
free -h                         # 内存使用

# 进程
ps aux | grep openclaw          # 查找进程
kill -9 PID                     # 结束进程
```

## 🌐 代理配置

脚本会自动检测并使用系统代理环境变量：

```bash
# 如需使用代理，可在运行前设置
export http_proxy=http://127.0.0.1:7890
export https_proxy=http://127.0.0.1:7890
./install.sh
```

## 📝 日志与排错

安装日志默认保存至：`~/.openclaw_install_YYYYMMDD_HHMMSS.log`

如果安装中断，脚本会根据当前阶段提供针对性的清理指南，并自动生成 `~/.openclaw_cleanup.sh` 清理脚本。

## ⚠️ 注意事项

1. **请勿使用 root 运行** - 脚本会自动申请 sudo 权限
2. **已安装检测** - 如果检测到已有 OpenClaw 安装，会提示是否覆盖
3. **终端重启** - 安装完成后建议关闭并重新打开终端，以加载环境变量

## 📜 更新日志

### v1.0.13 (2026-03-16)
- 优化 FNM 下载节点选择逻辑
- 增强错误处理和恢复机制
- 改进终端颜色输出兼容性

### v1.0.12
- 添加 GitHub 代理节点自动切换
- 优化 NPM 镜像源测速逻辑

### v1.0.11
- 修复 WSL 环境检测问题

*[查看完整更新日志](CHANGELOG.md)*

## 🤝 贡献

欢迎提交 Issue 和 PR！

## 📄 许可证

[MIT](LICENSE) © 2026

---

> 🦞 让 OpenClaw 安装变得简单优雅
