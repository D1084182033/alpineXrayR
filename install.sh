#!/usr/bin/env bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

XRAYR_DIR="/etc/XrayR"

msg() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

err() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    [ "$(id -u)" != "0" ] && {
        err "请使用root运行"
        exit 1
    }
}

detect_os() {
    if [ -f /etc/alpine-release ]; then
        OS="alpine"
    elif [ -f /etc/debian_version ]; then
        OS="debian"
    elif [ -f /etc/redhat-release ]; then
        OS="centos"
    else
        err "不支持的系统"
        exit 1
    fi

    msg "系统: ${OS}"
}

install_dep() {

    case "$OS" in
        alpine)
            apk update
            apk add curl wget unzip bash
            ;;
        debian)
            apt update
            apt install -y curl wget unzip
            ;;
        centos)
            yum install -y curl wget unzip
            ;;
    esac
}

detect_arch() {

    case "$(uname -m)" in

        x86_64|amd64)
            ARCH="64"
            ;;
        aarch64|arm64)
            ARCH="arm64-v8a"
            ;;
        armv7l)
            ARCH="arm32-v7a"
            ;;
        armv6l)
            ARCH="arm32-v6"
            ;;
        *)
            err "不支持架构: $(uname -m)"
            exit 1
            ;;
    esac

    msg "架构: ${ARCH}"
}

get_latest_version() {

    VERSION=$(curl -s https://api.github.com/repos/XrayR-project/XrayR/releases/latest \
        | grep tag_name \
        | cut -d '"' -f4)

    [ -z "$VERSION" ] && {
        err "获取版本失败"
        exit 1
    }

    msg "版本: ${VERSION}"
}

download_xrayr() {

    FILE="XrayR-linux-${ARCH}.zip"

    URL="https://github.com/XrayR-project/XrayR/releases/download/${VERSION}/${FILE}"

    msg "下载中..."

    if ! wget -O /tmp/XrayR.zip "$URL"; then

        msg "Github失败，切换代理"

        wget -O /tmp/XrayR.zip \
        "https://ghfast.top/${URL}"
    fi
}

install_xrayr() {

    mkdir -p ${XRAYR_DIR}

    unzip -o /tmp/XrayR.zip -d ${XRAYR_DIR}

    chmod +x ${XRAYR_DIR}/XrayR

    ln -sf ${XRAYR_DIR}/XrayR /usr/local/bin/XrayR
}

install_service() {

    if [ "$OS" = "alpine" ]; then

cat >/etc/init.d/XrayR <<'EOF'
#!/sbin/openrc-run

name="XrayR"

command="/etc/XrayR/XrayR"
command_args="run -config /etc/XrayR/config.yml"

pidfile="/run/XrayR.pid"

depend() {
    need net
}
EOF

        chmod +x /etc/init.d/XrayR

        rc-update add XrayR default

    else

cat >/etc/systemd/system/XrayR.service <<'EOF'
[Unit]
Description=XrayR
After=network.target

[Service]
Type=simple
ExecStart=/etc/XrayR/XrayR run -config /etc/XrayR/config.yml
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

        systemctl daemon-reload
        systemctl enable XrayR
    fi
}

start_service() {

    if [ "$OS" = "alpine" ]; then
        rc-service XrayR restart
    else
        systemctl restart XrayR
    fi
}

main() {

    check_root

    detect_os

    install_dep

    detect_arch

    get_latest_version

    download_xrayr

    install_xrayr

    install_service

    start_service

    echo
    echo "=========================="
    echo "XrayR 安装完成"
    echo "目录: /etc/XrayR"
    echo "配置: /etc/XrayR/config.yml"
    echo "=========================="
}

main