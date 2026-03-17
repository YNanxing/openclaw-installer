#!/usr/bin/env bash
# shellcheck shell=bash
# ==============================================================================
# 🚀 OpenClaw WSL/Debian/Ubuntu 自动化装机 (Enterprise DevOps Edition V1.0.13)
# Github：https://github.com/YNanxing/openclaw-installer
# 欢迎提交 Issue 和 PR！
# ==============================================================================

set -euEo pipefail
IFS=$'\n\t'
shopt -s inherit_errexit 2>/dev/null || true

if [[ "$(uname -s)" != "Linux" ]]; then
    printf "❌ 错误: 此脚本仅支持 Linux (WSL/Debian/Ubuntu) 环境\n" >&2
    exit 1
fi

if ((BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 4))); then
    printf "❌ 错误: 此脚本需要 Bash 4.4 或更高版本，当前版本: %s\n" "${BASH_VERSION}" >&2
    exit 1
fi

# ==============================================================================
# 🧰 全局可调整资源配置区 (Config)
# ==============================================================================
readonly NODE_VERSION="24"
readonly TOTAL_STEPS="8"
readonly CURL_TIMEOUT=15
readonly MAX_DL_SIZE="50M"
readonly SUDO_KEEPALIVE_INTERVAL=30
readonly CURL_DL_OPTS=("-fSL" "-#" "--connect-timeout" "${CURL_TIMEOUT}" "--max-time" "300" "--max-filesize" "${MAX_DL_SIZE}")
readonly LOG_FILE="${HOME}/.openclaw_install_$(date +%Y%m%d_%H%M%S).log"

# Git 代理镜像列表 (用于 github.com 的 insteadOf 替换)
readonly GIT_PROXY_MIRRORS=(
    "https://gh-proxy.com/https://github.com/"
    "https://ghfast.top/https://github.com/"
    "https://mirror.ghproxy.com/https://github.com/"
    "https://ghproxy.com/https://github.com/"
    "https://gh.api.99988866.xyz/https://github.com/"
)

# FNM 二进制包下载代理前缀池
readonly FNM_MIRROR_PREFIXES=(
    "https://ghfast.top/"
    "https://gh-proxy.com/"
    "https://githubproxy.cc/"
    "https://ghps.cc/"
    "https://kkgithub.com/"
    "https://mirror.ghproxy.com/"
    "" # 留空代表官方直连兜底
)

# NPM 注册表测速池
readonly NPM_REGISTRY_MIRRORS=(
    "https://registry.npmmirror.com"
    "https://mirrors.cloud.tencent.com/npm/"
    "https://mirrors.huaweicloud.com/repository/npm/"
)

# 探测 TTY 判断颜色的按需载入 (全新注入柔和真彩色系)
if [[ -t 1 ]]; then
    readonly C_RESET=$'\033[0m' 
    readonly C_BLUE=$'\033[38;2;138;173;244m'
    readonly C_GREEN=$'\033[38;2;166;218;149m'
    readonly C_YELLOW=$'\033[38;2;230;218;166m'
    readonly C_RED=$'\033[38;2;237;135;150m'
    readonly C_CYAN=$'\033[38;2;139;213;202m'
    readonly C_PURPLE=$'\033[38;2;198;160;246m'
    readonly C_BOLD=$'\033[1m'
    readonly C_DIM=$'\033[38;2;128;135;162m'
else
    readonly C_RESET="" C_BLUE="" C_GREEN="" C_YELLOW="" C_RED="" C_CYAN="" C_PURPLE="" C_BOLD="" C_DIM=""
fi

# ==============================================================================
# 📍 全局状态变量 (State)
# ==============================================================================
G_CURRENT_STAGE="INIT"
G_SUDO_KEEPER_PID=""
G_ONBOARD_SUCCESS=true
G_LOG_DIR=""
G_LOG_PIPE=""
G_TEE_PID=""

# ==============================================================================
# 🛠️ 基础工具函数 (界面修饰模块)
# ==============================================================================
log_step()    { printf '\n%s%s ◈ STAGE %s %s %s%s%s\n  %s───────────────────────────────────────────────────────────────────%s\n' "${C_PURPLE}" "${C_BOLD}" "$1" "${C_RESET}" "${C_BOLD}" "$2" "${C_RESET}" "${C_DIM}" "${C_RESET}"; }
log_info()    { printf '  %s[%(%H:%M:%S)T]%s %s󰋼%s  %s%s%s\n' "${C_DIM}" -1 "${C_RESET}" "${C_BLUE}" "${C_RESET}" "${C_RESET}" "$1" "${C_RESET}"; }
log_success() { printf '  %s[%(%H:%M:%S)T]%s %s✔%s  %s%s%s\n' "${C_DIM}" -1 "${C_RESET}" "${C_GREEN}" "${C_RESET}" "${C_RESET}" "$1" "${C_RESET}"; }
log_warn()    { printf '  %s[%(%H:%M:%S)T]%s %s⚠%s  %s%s%s\n' "${C_DIM}" -1 "${C_RESET}" "${C_YELLOW}" "${C_RESET}" "${C_YELLOW}" "$1" "${C_RESET}"; }
log_error()   { printf '  %s[%(%H:%M:%S)T]%s %s✖%s  %s%s%s\n' "${C_DIM}" -1 "${C_RESET}" "${C_RED}" "${C_RESET}" "${C_RED}" "$1" "${C_RESET}" >&2; }

mark_stage() { G_CURRENT_STAGE="$1"; }
print_divider() { :; }

# 【核心重构：无缝进度条，详细日志隐式打入文件】
run_task() {
    local exit_code=0
    set +e
    
    local tmp_out
    tmp_out=$(mktemp)
    
    # 将将要执行的详尽命令写入日志文件
    echo -e "\n============== [运行指令] $* ==============" >> "${LOG_FILE}"
    
    # 将真实海量输出放入后台并写入我们的临时文件
    "$@" > "$tmp_out" 2>&1 &
    local pid=$!
    
    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local i=0
    local has_tty=false
    if [[ -w /dev/tty ]]; then has_tty=true; tput civis >/dev/tty 2>/dev/null || true; fi

    # 在真正的控制台描画旋转进度条，避免污染日志管道 `tee`
    while kill -0 "$pid" 2>/dev/null; do
        if [[ "$has_tty" == true ]]; then
            printf '\r\033[K  %s%s%s %s正在执行底层任务，请稍等...%s' "${C_CYAN}" "${frames[i]}" "${C_RESET}" "${C_DIM}" "${C_RESET}" >/dev/tty
            i=$(( (i + 1) % 10 ))
        fi
        sleep 0.1
    done
    
    wait "$pid"
    exit_code=$?
    
    if [[ "$has_tty" == true ]]; then
        printf '\r\033[K' >/dev/tty
        tput cnorm >/dev/tty 2>/dev/null || true
    fi
    
    # 执行完后，直接将捕获到的冗长日志追加进文件，保持终端纯净
    cat "$tmp_out" >> "${LOG_FILE}"
    echo "============== [退出代码] $exit_code ==============" >> "${LOG_FILE}"
    
    rm -f "$tmp_out"
    set -e
    return "$exit_code"
}

sudo_apt_with_retry() {
    local max_attempts=3 attempt
    for ((attempt=1; attempt<=max_attempts; attempt++)); do
        if run_task sudo env DEBIAN_FRONTEND=noninteractive "$@"; then return 0; fi
        if ((attempt < max_attempts)); then
            log_warn "APT 被锁定或遇到网络错误，等待 10 秒后重试 (第 $((attempt+1))/${max_attempts} 次)..."
            sleep 10
        fi
    done
    return 1
}

apt_update()  { sudo_apt_with_retry apt-get update; }
apt_install() { sudo_apt_with_retry apt-get install -y "$@"; }

# ==============================================================================
# 🛡️ 生命周期与退出清理
# ==============================================================================
on_exit() {
    local exit_code=$?
    trap - ERR EXIT
    trap '' PIPE 
    
    if [[ -n "${G_SUDO_KEEPER_PID:-}" ]] && kill -0 "${G_SUDO_KEEPER_PID}" 2>/dev/null; then
        kill "${G_SUDO_KEEPER_PID}" 2>/dev/null || true
    fi
    
    if [[ $exit_code -ne 0 && "${G_CURRENT_STAGE}" != "DONE" ]]; then
        show_cleanup_guide
    fi

    if [[ -n "${G_TEE_PID:-}" ]]; then
        if [[ -w /dev/tty ]]; then exec >/dev/tty 2>&1; else exec >/dev/null 2>&1; fi
        wait "${G_TEE_PID}" 2>/dev/null || true
    fi

    if [[ -n "${G_LOG_DIR:-}" && -d "${G_LOG_DIR}" ]]; then
        rm -rf "${G_LOG_DIR}" 2>/dev/null || true
    fi
}

handle_error() {
    local line_no="${1:-unknown}" exit_code="${2:-1}"
    if [[ "${BASH_SUBSHELL:-0}" -gt 0 ]]; then exit "$exit_code"; fi
    printf '\n  %s%s╭── ✖ 异常中断 ────────────────────────────────╮%s\n' "${C_RED}" "${C_BOLD}" "${C_RESET}"
    printf '  %s%s│%s 退出码: %s  失败行号: %s\n' "${C_RED}" "${C_BOLD}" "${C_RESET}" "$exit_code" "$line_no"
    printf '  %s%s│%s %s👉 请查阅文件底层详细日志 %s \n' "${C_RED}" "${C_BOLD}" "${C_RESET}" "${C_YELLOW}" "${LOG_FILE}${C_RESET}"
    printf '  %s%s╰──────────────────────────────────────────────╯%s\n' "${C_RED}" "${C_BOLD}" "${C_RESET}"
    exit "$exit_code"
}

handle_interrupt() {
    trap - ERR INT TERM
    printf '\n\n  %s%s⚠️ 【用户中止】 安装进程已终止%s\n' "${C_RED}" "${C_BOLD}" "${C_RESET}"
    generate_cleanup_script
    exit 130
}

trap 'on_exit' EXIT
trap 'handle_error "$LINENO" "$?"' ERR
trap 'handle_interrupt' INT TERM

show_cleanup_guide() {
    printf '\n  %s╭─────────────────────────────────────────────────────────╮%s\n' "${C_DIM}" "${C_RESET}"
    printf '  %s│%s %s📋 环境清理指南%s %s(当前中断进度: %s)%s\n' "${C_DIM}" "${C_RESET}" "${C_CYAN}${C_BOLD}" "${C_RESET}" "${C_DIM}" "${G_CURRENT_STAGE:-未知}" "${C_RESET}"
    printf '  %s╰─────────────────────────────────────────────────────────╯%s\n' "${C_DIM}" "${C_RESET}"
    
    case "${G_CURRENT_STAGE}" in
        "INIT"|"SUDO_CHECK"|"TOOL_CHECK")
            printf '     %s✔ 未做系统层实质修改，修复网络后重新运行即可%s\n' "${C_GREEN}" "${C_RESET}" ;;
        "SYSTEMD_CHECK")
            printf '     %s⚠ 尝试验证: cat /etc/wsl.conf%s\n' "${C_YELLOW}" "${C_RESET}" ;;
        "APT_SETUP")
            printf '     %s⚠ 释放 APT 锁:%s\n' "${C_YELLOW}" "${C_RESET}"
            printf '       sudo rm -f /var/lib/dpkg/lock*\n'
            printf '       sudo dpkg --configure -a\n' ;;
        "FNM_SETUP")
            printf '     %s⚠ 清理 FNM 及 Node 环境:%s\n' "${C_YELLOW}" "${C_RESET}"
            printf '       rm -rf ~/.local/share/fnm ~/.fnm\n'
            printf '       sed -i "/# === OpenClaw FNM START ===/,/# === OpenClaw FNM END ===/d" ~/.bashrc\n' ;;
        "OPENCLAW_SETUP")
            printf '     %s⚠ 清理 OpenClaw 残留:%s\n' "${C_YELLOW}" "${C_RESET}"
            printf '       npm uninstall -g openclaw\n'
            printf '       npm cache clean --force\n' ;;
        *)
            printf '     %s⚠ 通用清理脚本:%s\n' "${C_YELLOW}" "${C_RESET}"
            printf '       bash ~/.openclaw_cleanup.sh\n' ;;
    esac
    printf '\n'
}

generate_cleanup_script() {
    local cleanup_file="${HOME}/.openclaw_cleanup.sh"
    rm -f "${cleanup_file}" 2>/dev/null || true
    cat > "${cleanup_file}" << 'CLEANUP_EOF'
#!/usr/bin/env bash
printf "🧹 正在清理 OpenClaw 环境残留...\n"
export PATH="$HOME/.local/share/fnm:$PATH"
eval "$(fnm env 2>/dev/null)" || true
npm uninstall -g openclaw 2>/dev/null || true
npm cache clean --force 2>/dev/null || true
rm -rf ~/.local/share/fnm ~/.fnm 2>/dev/null || true
sudo rm -f /var/lib/dpkg/lock* 2>/dev/null || true
for rc in ~/.bashrc ~/.zshrc; do
    if [[ -f "$rc" ]]; then sed -i '/# === OpenClaw FNM START ===/,/# === OpenClaw FNM END ===/d' "$rc" 2>/dev/null || true; fi
done
printf "✅ 清理完成！\n"
CLEANUP_EOF
    chmod +x "${cleanup_file}" 2>/dev/null || true
}

# ==============================================================================
# 🚀 核心逻辑组 (Core Logic)
# ==============================================================================

prevent_root_execution() {
    mark_stage "INIT"
    if [[ "${EUID}" -eq 0 ]]; then
        printf '\n  %s🛑 错误: 请勿使用 root 或 sudo su 身份运行此脚本%s\n' "${C_RED}" "${C_RESET}"
        exit 1
    fi
}

ensure_sudo() {
    mark_stage "SUDO_CHECK"
    if ! sudo -v; then
        log_error "sudo 权限获取失败，脚本已终止"
        exit 1
    fi
    local my_comm=""
    read -r my_comm < "/proc/$$/comm" 2>/dev/null || true
    (
        while kill -0 "$$" 2>/dev/null; do
            local current_comm=""
            read -r current_comm < "/proc/$$/comm" 2>/dev/null || true
            if [[ -n "${my_comm}" ]] && [[ "${current_comm}" != "${my_comm}" ]]; then break; fi
            sudo -n true 2>/dev/null || true
            sleep "${SUDO_KEEPALIVE_INTERVAL}"
        done
    ) &
    G_SUDO_KEEPER_PID=$!
    disown "${G_SUDO_KEEPER_PID}" 2>/dev/null || true
}

get_fastest() {
    local - 
    set +e +o pipefail 2>/dev/null || true
    
    local urls=("$@")
    if [[ ${#urls[@]} -eq 0 ]]; then return 1; fi
    
    local best
    best=$(
        printf '%s\n' "${urls[@]}" | \
        xargs -d '\n' -P 8 -n 1 sh -c 'curl -s -m 4 -o /dev/null -w "%{http_code}\t%{time_starttransfer}\t%{url_effective}\n" "$1"' _ | \
        awk -F'\t' '/^[234]/ && $2>0 {print $2, $3}' | sort -n | head -1 | awk '{print $2}'
    ) || true
    
    if [[ -n "$best" ]]; then printf '%s\n' "$best"; return 0; else return 1; fi
}

check_required_tools() {
    mark_stage "TOOL_CHECK"
    log_step "1/${TOTAL_STEPS}" "检查环境与修改镜像源"

    local codename="bookworm" distro_id="debian"
    
    if [[ -r /etc/os-release ]]; then
        codename=$(awk -F= '
            /^VERSION_CODENAME=/ { gsub(/["\047]/, "", $2); c=$2 }
            /^VERSION_ID=/       { gsub(/["\047]/, "", $2); i=$2 }
            END { print (c != "" ? c : i) }
        ' /etc/os-release 2>/dev/null) || true
        
        distro_id=$(awk -F= '/^ID=/ {gsub(/["\047]/, "", $2); print $2; exit}' /etc/os-release 2>/dev/null) || true
        
        codename="${codename:-bookworm}"
        distro_id="${distro_id:-debian}"
    fi

    local china_mirrors="mirrors\.(aliyun|tuna|ustc|nju|tencent|huaweicloud)"
    local already_mirrored=false
    if [[ -f /etc/apt/sources.list.d/debian.sources ]] && grep -qE "${china_mirrors}" /etc/apt/sources.list.d/debian.sources 2>/dev/null; then already_mirrored=true; fi
    if [[ -f /etc/apt/sources.list.d/ubuntu.sources ]] && grep -qE "${china_mirrors}" /etc/apt/sources.list.d/ubuntu.sources 2>/dev/null; then already_mirrored=true; fi
    if [[ -f /etc/apt/sources.list ]] && grep -qE "${china_mirrors}" /etc/apt/sources.list 2>/dev/null; then already_mirrored=true; fi

    if [[ "${already_mirrored}" != "true" ]]; then
        if [[ "${codename}" =~ ^[0-9.]+$ ]]; then
            log_warn "读取到数字代号 (${codename})，为避免 404，跳过自动修源"
            apt_update || { log_error "APT 更新失败，请检查网络设置"; exit 1; }
        else
            if [[ -f /etc/apt/sources.list ]]; then sudo cp -a /etc/apt/sources.list /etc/apt/sources.list.bak 2>/dev/null || true; fi
            if [[ "${distro_id}" == "debian" ]]; then
                log_info "配置 Debian 清华 TUNA 镜像源..."
                if [[ -f /etc/apt/sources.list.d/debian.sources ]]; then sudo mv /etc/apt/sources.list.d/debian.sources /etc/apt/sources.list.d/debian.sources.bak 2>/dev/null || true; fi
                local comps="main contrib non-free"
                if [[ "${codename}" == "bookworm" || "${codename}" == "trixie" ]]; then comps+=" non-free-firmware"; fi
                local sec_url="http://mirrors.tuna.tsinghua.edu.cn/debian-security" sec_suite="${codename}-security"
                if [[ "${codename}" == "buster" ]]; then sec_url="http://mirrors.tuna.tsinghua.edu.cn/debian/security"; sec_suite="buster/updates"; fi
                printf '%s\n' "deb http://mirrors.tuna.tsinghua.edu.cn/debian/ ${codename} ${comps}
deb http://mirrors.tuna.tsinghua.edu.cn/debian/ ${codename}-updates ${comps}
deb ${sec_url} ${sec_suite} ${comps}" | sudo tee /etc/apt/sources.list >/dev/null
                apt_update || { log_error "APT 更新失败"; exit 1; }
                log_success "Debian 镜像源切换完成"
            elif [[ "${distro_id}" == "ubuntu" ]]; then
                log_info "配置 Ubuntu 清华 TUNA 镜像源..."
                if [[ -f /etc/apt/sources.list.d/ubuntu.sources ]]; then sudo mv /etc/apt/sources.list.d/ubuntu.sources /etc/apt/sources.list.d/ubuntu.sources.bak 2>/dev/null || true; fi
                printf '%s\n' "deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${codename} main restricted universe multiverse
deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${codename}-updates main restricted universe multiverse
deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${codename}-backports main restricted universe multiverse
deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${codename}-security main restricted universe multiverse" | sudo tee /etc/apt/sources.list >/dev/null
                apt_update || { log_error "APT 更新失败"; exit 1; }
                log_success "Ubuntu 镜像源切换完成"
            else
                log_warn "未识别的分支发行版 (${distro_id})，保留默认源配置"
                apt_update || { log_error "APT 更新失败"; exit 1; }
            fi
        fi
    else
        log_success "已配置国内镜像源，跳过换源操作"
        apt_update || { log_error "APT 更新失败"; exit 1; }
    fi

    local missing=()
    if ! command -v curl >/dev/null 2>&1; then missing+=("curl"); fi
    if ! command -v git >/dev/null 2>&1; then missing+=("git"); fi
    if ! dpkg -s polkitd >/dev/null 2>&1 && ! dpkg -s policykit-1 >/dev/null 2>&1; then
        if [[ "${distro_id}" == "ubuntu" ]] && [[ "${codename}" == "focal" || "${codename}" == "bionic" ]]; then missing+=("policykit-1")
        elif [[ "${distro_id}" == "debian" ]] && [[ "${codename}" == "bullseye" || "${codename}" == "buster" ]]; then missing+=("policykit-1")
        else missing+=("polkitd"); fi
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        local display_missing
        display_missing="$(IFS=' '; echo "${missing[*]}")"
        log_info "需安装缺失的基础组件: ${C_YELLOW}${display_missing}${C_RESET} ..."
        apt_install "${missing[@]}" || { log_error "依赖包安装失败"; exit 1; }
    fi
    log_success "系统环境与基础组件检查通过"
}

setup_git_mirrors() {
    mark_stage "GIT_SETUP"
    log_step "2/${TOTAL_STEPS}" "配置 Git 代理与克隆重定向"
    log_info "正在测速并配置最快的 Git 代理镜像..."

    # 使用 get_fastest 动态测速，如果全部超时则使用兜底源
    local best_git
    best_git="$(get_fastest "${GIT_PROXY_MIRRORS[@]}" || echo "")"
    best_git="${best_git:-https://ghfast.top/https://github.com/}"

    log_info "已选定最优 Git 代理: ${C_GREEN}${best_git}${C_RESET}"

    for old in "${GIT_PROXY_MIRRORS[@]:-}"; do 
        git config --global --remove-section "url.${old}" 2>/dev/null || true
    done
    
    git config --global --add url."${best_git}".insteadOf "https://github.com/"
    git config --global url."https://github.com/".insteadOf "git@github.com:"
    git config --global url."https://github.com/".insteadOf "ssh://git@github.com/"
    git config --global url."https://github.com/".insteadOf "git://github.com/"

    if [[ -n "${http_proxy:-}" ]]; then 
        git config --global http.proxy "${http_proxy}"
    fi
    if [[ -n "${https_proxy:-}" ]]; then 
        git config --global https.proxy "${https_proxy}"
    fi
    log_success "Git 代理与克隆重定向设置完成"
}

setup_apt_mirror_and_deps() {
    mark_stage "APT_SETUP"
    log_step "3/${TOTAL_STEPS}" "安装系统基础编译依赖"

    timedatectl set-timezone Asia/Shanghai 2>/dev/null || true
    local -a deps=(
        ca-certificates jq unzip
        build-essential cmake pkg-config libssl-dev gcc g++ make gnupg
        sqlite3 libsqlite3-dev python3 python3-venv ffmpeg
    )
    log_info "正在安装系统依赖包 (C++/Python等)..."
    apt_install "${deps[@]}" || { log_error "系统依赖安装失败"; exit 1; }
    log_success "系统基础编译依赖安装完成"
}

setup_fnm_node() {
    mark_stage "FNM_SETUP"
    log_step "4/${TOTAL_STEPS}" "安装 Node.js 与 FNM 工具"

    local fnm_dir="${HOME}/.local/share/fnm"
    mkdir -p "${fnm_dir}"

    if ! command -v fnm >/dev/null 2>&1 && [[ ! -x "${fnm_dir}/fnm" ]]; then
        local arch fnm_bin
        arch="$(uname -m)"
        case "${arch}" in
            aarch64|arm64) fnm_bin="fnm-arm64" ;;
            x86_64|amd64)  fnm_bin="fnm-linux" ;;
            *) log_error "暂不支持当前主机的 CPU 架构: ${arch}"; exit 1 ;;
        esac

        local base_suffix="Schniz/fnm/releases/latest/download/${fnm_bin}.zip"
        local fnm_urls=()
        for prefix in "${FNM_MIRROR_PREFIXES[@]}"; do
            fnm_urls+=("${prefix}https://github.com/${base_suffix}")
        done

        log_info "获取最新 FNM 下载信息..."
         local proxy_prefix="${FNM_MIRROR_PREFIXES[0]}"
        local checksums_url="${proxy_prefix}https://github.com/Schniz/fnm/releases/latest/download/checksums.txt"
        local expected_sha=""
        expected_sha=$(curl -sL --max-time 10 "${checksums_url}" 2>/dev/null | awk "/${fnm_bin}\.zip/ {print \$1}") || true
        
        log_info "尝试通过代理节点下载 FNM..."
        local tmp_dir tmp_file downloaded=false
        tmp_dir=$(mktemp -d -t openclaw_fnm.XXXXXX)
        tmp_file="${tmp_dir}/${fnm_bin}.zip"

        for url in "${fnm_urls[@]}"; do
            log_info "尝试节点: ${url}"
            if curl "${CURL_DL_OPTS[@]}" "${url}" -o "${tmp_file}"; then
                if unzip -tq "${tmp_file}" >/dev/null 2>&1; then
                    if [[ -n "${expected_sha}" ]]; then
                        local actual_sha
                        actual_sha=$(sha256sum "${tmp_file}" | awk '{print $1}')
                        if [[ "${expected_sha}" != "${actual_sha}" ]]; then
                            log_error "SHA-256 校验不匹配"
                            rm -f "${tmp_file}"; continue
                        fi
                        log_success "SHA-256 校验通过"
                    else
                        log_warn "未获取到校验文件，仅验证 zip 格式完整性"
                    fi
                    downloaded=true
                    break
                else
                     log_warn "下载文件损坏，尝试下一个节点"
                fi
            fi
            rm -f "${tmp_file}"
        done

        if [[ "${downloaded}" != "true" ]]; then
            log_error "所有代理节点下载失败，请检查网络"
            rm -rf "${tmp_dir}" 2>/dev/null || true
            exit 1
        fi

        unzip -qo "${tmp_file}" -d "${fnm_dir}"
        chmod +x "${fnm_dir}/fnm"
        rm -rf "${tmp_dir}" 2>/dev/null || true

        if [[ ! -x "${fnm_dir}/fnm" ]]; then log_error "FNM 二进制文件缺少执行权限"; exit 1; fi
        log_success "FNM 安装完成"
    else
        log_success "已安装 FNM，跳过"
    fi

    if [[ ":${PATH}:" != *":${fnm_dir}:"* ]]; then export PATH="${fnm_dir}:${PATH}"; fi

    export FNM_NODE_DIST_MIRROR="https://registry.npmmirror.com/-/binary/node/"
    eval "$(fnm env 2>/dev/null)" || { log_error "FNM 环境初始化失败"; exit 1; }

    local config='# === OpenClaw FNM START ===
export FNM_NODE_DIST_MIRROR="https://registry.npmmirror.com/-/binary/node/"
case ":$PATH:" in
  *":$HOME/.local/share/fnm:"*) ;;
  *) export PATH="$HOME/.local/share/fnm:$PATH" ;;
esac
eval "$(fnm env 2>/dev/null)" 2>/dev/null || true
# === OpenClaw FNM END ==='

    for rc in "${HOME}/.bashrc" "${HOME}/.zshrc"; do
        if [[ -f "$rc" ]]; then
            cp -a "$rc" "${rc}.openclaw.bak" 2>/dev/null || true
            sed -i '/# === OpenClaw FNM START ===/,/# === OpenClaw FNM END ===/d' "$rc" 2>/dev/null || true
            if ! grep -q '# === OpenClaw FNM START ===' "$rc" 2>/dev/null; then printf '\n%s\n' "$config" >> "$rc"; fi
        fi
    done

    log_info "正在安装 Node.js v${NODE_VERSION}..."
    run_task fnm install "${NODE_VERSION}" || { log_error "Node.js 安装失败"; exit 1; }
    run_task fnm default "${NODE_VERSION}" || { log_error "Node.js 默认版本设置失败"; exit 1; }
    run_task fnm use "${NODE_VERSION}" || { log_error "Node.js 版本切换失败"; exit 1; }

    eval "$(fnm env 2>/dev/null)" || { log_error "Node.js 环境加载失败"; exit 1; }

    local full_ver node_ver
    full_ver="$(node -v 2>/dev/null || echo 'v0.0.0')"
    node_ver="${full_ver#v}"
    node_ver="${node_ver%%.*}"

    if ! [[ "${node_ver}" =~ ^[0-9]+$ ]] || [[ "${node_ver}" -lt 22 ]]; then
        log_error "Node.js 版本低于要求 (最低需要 >= 22): ${full_ver}"
        exit 1
    fi

    local npm_ver
    npm_ver="$(npm -v 2>/dev/null || echo 'unknown')"
    log_success "准备就绪 | Node ${full_ver} | NPM v${npm_ver}"
}

setup_openclaw() {
    mark_stage "OPENCLAW_SETUP"
    log_step "5/${TOTAL_STEPS}" "安装 OpenClaw 命令行工具"

    log_info "清理 NPM 缓存..."
    npm cache clean --force >/dev/null 2>&1 || true

    local best_npm
    best_npm="$(get_fastest "${NPM_REGISTRY_MIRRORS[@]}" || echo "")"
    best_npm="${best_npm:-https://registry.npmmirror.com}"
    
    npm config set registry "${best_npm}" || { log_error "NPM 镜像源设置失败"; exit 1; }
    log_success "NPM 镜像源已切换至: ${best_npm}"

    # setup_git_mirrors

    log_info "正在通过 NPM 安装 OpenClaw (可能需要10-20分钟，请耐心等待)..."
    if ! run_task npm install -g openclaw@latest; then
        log_warn "首次安装失败，清理缓存后尝试重新安装..."
        sleep 5
        npm cache clean --force >/dev/null 2>&1 || true
        rm -rf "${HOME}/.npm/_locks" 2>/dev/null || true
        
        if ! run_task npm install -g openclaw@latest; then
            log_error "重试后仍然安装失败，请查看日志文件排查问题"
            exit 1
        fi
    fi
    log_success "OpenClaw 安装完成"
}

verify_installation() {
    mark_stage "VERIFY"
    log_step "6/${TOTAL_STEPS}" "验证安装结果"

    local all_passed=true full_ver node_ver
    printf '\n  %s╭────────────────── ENVIRONMENT AUDIT ──────────────────╮%s\n' "${C_DIM}" "${C_RESET}"

    if command -v node >/dev/null 2>&1; then
        full_ver="$(node -v 2>/dev/null || echo 'v0.0.0')"
        node_ver="${full_ver#v}"
        node_ver="${node_ver%%.*}"
        if [[ "${node_ver}" =~ ^[0-9]+$ ]] && [[ "${node_ver}" -ge 22 ]]; then
            printf '  %s│%s  %-2s %-12s ➜ %s%s%s%s \n' "${C_DIM}" "${C_RESET}" "✅" "Node.js" "${C_GREEN}" "${C_BOLD}" "${full_ver}" "${C_RESET}"
        else
            printf '  %s│%s  %-2s %-12s ➜ %s%s (项目建议版本 >= 22)%s \n' "${C_DIM}" "${C_RESET}" "⚠️" "Node.js" "${C_YELLOW}" "${full_ver}" "${C_RESET}"
        fi
    else
        printf '  %s│%s  %-2s %-12s ➜ %s%s%s%s \n' "${C_DIM}" "${C_RESET}" "❌" "Node.js" "${C_RED}" "${C_BOLD}" "未找到" "${C_RESET}"; all_passed=false
    fi

    if command -v npm >/dev/null 2>&1; then
        printf '  %s│%s  %-2s %-12s ➜ %s%s%s%s \n' "${C_DIM}" "${C_RESET}" "✅" "NPM" "${C_GREEN}" "${C_BOLD}" "v$(npm -v 2>/dev/null)" "${C_RESET}"
    else
        printf '  %s│%s  %-2s %-12s ➜ %s%s%s%s \n' "${C_DIM}" "${C_RESET}" "❌" "NPM" "${C_RED}" "${C_BOLD}" "未找到" "${C_RESET}"; all_passed=false
    fi

    if command -v openclaw >/dev/null 2>&1; then
        local oc_ver
        oc_ver=$(openclaw --version 2>/dev/null || echo '已安装')
        [[ "$oc_ver" =~ ^[0-9] ]] && oc_ver="v$oc_ver"
        printf '  %s│%s  %-2s %-12s ➜ %s%s%s%s \n' "${C_DIM}" "${C_RESET}" "✅" "OpenClaw CLI" "${C_BLUE}" "${C_BOLD}" "${oc_ver}" "${C_RESET}"
    else
        printf '  %s│%s  %-2s %-12s ➜ %s%s%s%s \n' "${C_DIM}" "${C_RESET}" "❌" "OpenClaw CLI" "${C_RED}" "${C_BOLD}" "未找到" "${C_RESET}"; all_passed=false
    fi

    printf '  %s╰───────────────────────────────────────────────────────╯%s\n\n' "${C_DIM}" "${C_RESET}"

    if [[ "${all_passed}" != "true" ]]; then log_error "组件验证未通过全部检查"; exit 1; fi
    log_success "所有组件验证通过"
}

finalize_and_onboard() {
    mark_stage "FINALIZE"
    log_step "7/${TOTAL_STEPS}" "执行启动配置向导"

    if ! command -v openclaw >/dev/null 2>&1; then
        log_error "未找到 OpenClaw 命令，跳过向导"
        G_ONBOARD_SUCCESS=false
        return 0
    fi
    
    local exit_code=0
    # 由于该命令可能具备向用户打点询问的界面交互，所以不能裹入暗箱进程组
    if ! openclaw onboard --install-daemon; then exit_code=$?; fi
    
    if [[ $exit_code -eq 0 ]]; then
        log_success "配置向导执行完成"
    else
        log_warn "向导未完整完成 (Exit Code: ${exit_code})"
        printf '  %s%s👉 安装后可手动输入此命令重试：openclaw onboard --install-daemon%s\n' "${C_CYAN}" "${C_DIM}" "${C_RESET}"
        G_ONBOARD_SUCCESS=false
    fi
}

show_final_info() {
    log_step "8/${TOTAL_STEPS}" "安装完毕"

    printf '\n'
    if [[ "${G_ONBOARD_SUCCESS}" == "true" ]]; then
        printf '  %s%s╭──────────────────────────────────────────────────────────╮%s\n' "${C_GREEN}" "${C_BOLD}" "${C_RESET}"
        printf '  %s%s│  🎉  OpenClaw 安装与配置全部完成！                         │%s\n' "${C_GREEN}" "${C_BOLD}" "${C_RESET}"
        printf '  %s%s╰──────────────────────────────────────────────────────────╯%s\n' "${C_GREEN}" "${C_BOLD}" "${C_RESET}"
    else
        printf '  %s%s╭──────────────────────────────────────────────────────────╮%s\n' "${C_YELLOW}" "${C_BOLD}" "${C_RESET}"
        printf '  %s%s│  ⚠  核心组件已安装，部分配置向导需手动完成。               │%s\n' "${C_YELLOW}" "${C_BOLD}" "${C_RESET}"
        printf '  %s%s╰──────────────────────────────────────────────────────────╯%s\n' "${C_YELLOW}" "${C_BOLD}" "${C_RESET}"
    fi

    printf '\n  %s%s■ 常用命令手册:%s\n' "${C_BLUE}" "${C_BOLD}" "${C_RESET}"
    printf '    %sopenclaw dashboard%s                %s# 在默认浏览器打开本地控制台页面%s\n' "${C_GREEN}" "${C_RESET}" "${C_DIM}" "${C_RESET}"
    printf '    %sopenclaw gateway status%s           %s# 查看后台守护节点运行状态%s\n' "${C_GREEN}" "${C_RESET}" "${C_DIM}" "${C_RESET}"
    printf '    %sopenclaw logs --follow%s            %s# 实时查看后台运行日志%s\n' "${C_GREEN}" "${C_RESET}" "${C_DIM}" "${C_RESET}"
    printf '    %sopenclaw doctor%s                   %s# 诊断运行环境与健康状态%s\n' "${C_GREEN}" "${C_RESET}" "${C_DIM}" "${C_RESET}"
    printf '    %sopenclaw onboard --install-daemon%s %s# 重新执行服务启动配置%s\n' "${C_GREEN}" "${C_RESET}" "${C_DIM}" "${C_RESET}"
    printf '\n'
}

show_usage() {
    printf '\n  %s用法:%s %s [选项入参]\n' "${C_CYAN}" "${C_RESET}" "$0"
    printf '    --help     显示帮助信息\n\n'
}

main() {
    case "${1:-}" in
        -h|--help) show_usage; return 0 ;;
    esac

    printf '\n\n'
    prevent_root_execution

    printf '  %s%s╭────────────────────────────────────────────────────────────╮%s\n' "${C_BLUE}" "${C_BOLD}" "${C_RESET}"
    printf '  %s%s│   %s🦞 OpenClaw WSL/Debian/Ubuntu 自动集成安装脚本 V1.0.13 %s      %s│%s\n' "${C_BLUE}" "${C_BOLD}" "${C_CYAN}" "${C_RESET}" "${C_BLUE}${C_BOLD}" "${C_RESET}"
    printf '  %s%s╰────────────────────────────────────────────────────────────╯%s\n\n' "${C_BLUE}" "${C_BOLD}" "${C_RESET}"

    if command -v openclaw >/dev/null 2>&1 && command -v node >/dev/null 2>&1; then
        log_info "检测到当前环境已存在 OpenClaw 安装"
        if [[ -t 0 ]]; then
            printf "  %s%s?%s 是否需要继续并覆盖当前安装？[y/N] " "${C_YELLOW}" "${C_BOLD}" "${C_RESET}"
            read -r answer
            [[ "${answer}" =~ ^[Yy]$ ]] || { log_success "用户取消，安装已终止。"; exit 0; }
        else
            log_warn "检测到非交互终端且已存在安装，安全起见自动跳过。如需覆盖请在交互模式下运行。"
            exit 0
        fi
    fi

    G_LOG_DIR=$(mktemp -d -t openclaw_install.XXXXXX)
    G_LOG_PIPE="${G_LOG_DIR}/openclaw_install.fifo"
    mkfifo "${G_LOG_PIPE}"
    tee -a "${LOG_FILE}" < "${G_LOG_PIPE}" &
    G_TEE_PID=$!
    exec > "${G_LOG_PIPE}" 2>&1

    log_info "详细安装日志将同步保存至: ${C_DIM}${LOG_FILE}${C_RESET}"

    ensure_sudo
    check_required_tools
    setup_git_mirrors
    setup_apt_mirror_and_deps
    setup_fnm_node
    setup_openclaw
    verify_installation
    finalize_and_onboard

    sudo apt-get clean >/dev/null 2>&1 || true
    rm -f "${HOME}/.openclaw_cleanup.sh" 2>/dev/null || true

    printf '\n  %s💡 为了确保环境变量生效，建议关闭当前终端窗口并重新打开%s\n' "${C_YELLOW}" "${C_RESET}"
    
    mark_stage "DONE"
    show_final_info
}

main "$@"
