#!/bin/bash

RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
NC='\033[0m'

disable_option=false
enable_ech=false
listen_port=""
override_port=""
ip_v4=""
ip_v6=""
record_content=""
record_type=""
record_name=""
obfs_password=""
domain=""
domain_name=""
up_mbps=""
down_mbps=""
certificate_path=""
private_key_path=""
public_key=""
private_key=""
multiplex_config=""
brutal_config=""
ech_key=()
ech_config=()
user_names=()
user_passwords=()
user_uuids=()
ss_passwords=() 
stls_passwords=()
short_ids=()

function check_firewall_configuration() {
    local os_name=$(uname -s)
    local firewall
    if [[ $os_name == "Linux" ]]; then
        if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
            firewall="ufw"
        elif command -v ip6tables >/dev/null 2>&1 && ip6tables -S | grep -q "INPUT -j DROP"; then
            firewall="ip6tables"
        elif command -v iptables >/dev/null 2>&1 && iptables -S | grep -q "INPUT -j DROP"; then
            firewall="iptables"
        elif systemctl is-active --quiet netfilter-persistent; then
            firewall="iptables-persistent"
        elif systemctl is-active --quiet iptables.service; then
            firewall="iptables-service"            
        elif command -v firewalld >/dev/null 2>&1 && firewall-cmd --state | grep -q "running"; then
            firewall="firewalld"
        fi
    fi
    if [[ -z $firewall ]]; then
        echo "No firewall configuration detected or firewall is not enabled, skipping firewall configuration."
        return
    fi
    echo "Checking firewall configuration..."
    case $firewall in
        ufw)
            if ! ufw status | grep -q "Status: active" 2>/dev/null; then
                ufw enable > /dev/null 2>&1
            fi

            if ! ufw status | grep -q " $listen_port" 2>/dev/null; then
                ufw allow "$listen_port" > /dev/null 2>&1
            fi

            if ! ufw status | grep -q " $override_port" 2>/dev/null; then
                ufw allow "$override_port" > /dev/null 2>&1
            fi

            if ! ufw status | grep -q " $fallback_port" 2>/dev/null; then
                ufw allow "$fallback_port" > /dev/null 2>&1
            fi
            
            if ! ufw status | grep -q " 80" 2>/dev/null; then
                ufw allow 80 > /dev/null 2>&1
            fi
            echo "Firewall configuration has been updated."
            ;;
        iptables | iptables-persistent | iptables-service)
            if ! iptables -C INPUT -p tcp --dport "$listen_port" -j ACCEPT >/dev/null 2>&1; then
                iptables -A INPUT -p tcp --dport "$listen_port" -j ACCEPT > /dev/null 2>&1
            fi

            if ! iptables -C INPUT -p udp --dport "$listen_port" -j ACCEPT >/dev/null 2>&1; then
                iptables -A INPUT -p udp --dport "$listen_port" -j ACCEPT > /dev/null 2>&1
            fi

            if ! iptables -C INPUT -p tcp --dport "$override_port" -j ACCEPT >/dev/null 2>&1; then
                iptables -A INPUT -p tcp --dport "$override_port" -j ACCEPT > /dev/null 2>&1
            fi

            if ! iptables -C INPUT -p udp --dport "$override_port" -j ACCEPT >/dev/null 2>&1; then
                iptables -A INPUT -p udp --dport "$override_port" -j ACCEPT > /dev/null 2>&1
            fi

            if ! iptables -C INPUT -p tcp --dport "$fallback_port" -j ACCEPT >/dev/null 2>&1; then
                iptables -A INPUT -p tcp --dport "$fallback_port" -j ACCEPT > /dev/null 2>&1
            fi

            if ! iptables -C INPUT -p udp --dport "$fallback_port" -j ACCEPT >/dev/null 2>&1; then
                iptables -A INPUT -p udp --dport "$fallback_port" -j ACCEPT > /dev/null 2>&1
            fi

            if ! iptables -C INPUT -p tcp --dport 80 -j ACCEPT >/dev/null 2>&1; then
                iptables -A INPUT -p tcp --dport 80 -j ACCEPT > /dev/null 2>&1
            fi

            if ! iptables -C INPUT -p udp --dport 80 -j ACCEPT >/dev/null 2>&1; then
                iptables -A INPUT -p udp --dport 80 -j ACCEPT > /dev/null 2>&1
            fi

            if ! ip6tables -C INPUT -p tcp --dport "$listen_port" -j ACCEPT >/dev/null 2>&1; then
                ip6tables -A INPUT -p tcp --dport "$listen_port" -j ACCEPT > /dev/null 2>&1
            fi

            if ! ip6tables -C INPUT -p udp --dport "$listen_port" -j ACCEPT >/dev/null 2>&1; then
                ip6tables -A INPUT -p udp --dport "$listen_port" -j ACCEPT > /dev/null 2>&1
            fi

            if ! ip6tables -C INPUT -p tcp --dport "$override_port" -j ACCEPT >/dev/null 2>&1; then
                ip6tables -A INPUT -p tcp --dport "$override_port" -j ACCEPT > /dev/null 2>&1
            fi

            if ! ip6tables -C INPUT -p udp --dport "$override_port" -j ACCEPT >/dev/null 2>&1; then
                ip6tables -A INPUT -p udp --dport "$override_port" -j ACCEPT > /dev/null 2>&1
            fi

            if ! ip6tables -C INPUT -p tcp --dport "$fallback_port" -j ACCEPT >/dev/null 2>&1; then
                ip6tables -A INPUT -p tcp --dport "$fallback_port" -j ACCEPT > /dev/null 2>&1
            fi

            if ! ip6tables -C INPUT -p udp --dport "$fallback_port" -j ACCEPT >/dev/null 2>&1; then
                ip6tables -A INPUT -p udp --dport "$fallback_port" -j ACCEPT > /dev/null 2>&1
            fi

            if ! ip6tables -C INPUT -p tcp --dport 80 -j ACCEPT >/dev/null 2>&1; then
                ip6tables -A INPUT -p tcp --dport 80 -j ACCEPT > /dev/null 2>&1
            fi

            if ! ip6tables -C INPUT -p udp --dport 80 -j ACCEPT >/dev/null 2>&1; then
                ip6tables -A INPUT -p udp --dport 80 -j ACCEPT > /dev/null 2>&1
            fi

            if [[ -e /etc/iptables/rules.v4 ]]; then
                iptables-save > /etc/iptables/rules.v4
            elif [[ -e /etc/sysconfig/iptables ]]; then
                iptables-save > /etc/sysconfig/iptables
            fi

            if [[ -e /etc/iptables/rules.v6 ]]; then
                ip6tables-save > /etc/iptables/rules.v6
            elif [[ -e /etc/sysconfig/ip6tables ]]; then
                ip6tables-save > /etc/sysconfig/ip6tables
            fi
            echo "Firewall configuration has been updated."
            ;;
        firewalld)
            if ! firewall-cmd --zone=public --list-ports | grep -q "$listen_port/tcp" 2>/dev/null; then
                firewall-cmd --zone=public --add-port="$listen_port/tcp" --permanent > /dev/null 2>&1
            fi

            if ! firewall-cmd --zone=public --list-ports | grep -q "$listen_port/udp" 2>/dev/null; then
                firewall-cmd --zone=public --add-port="$listen_port/udp" --permanent > /dev/null 2>&1
            fi

            if ! firewall-cmd --zone=public --list-ports | grep -q "$override_port/tcp" 2>/dev/null; then
                firewall-cmd --zone=public --add-port="$override_port/tcp" --permanent > /dev/null 2>&1
            fi

            if ! firewall-cmd --zone=public --list-ports | grep -q "$override_port/udp" 2>/dev/null; then
                firewall-cmd --zone=public --add-port="$override_port/udp" --permanent > /dev/null 2>&1
            fi

            if ! firewall-cmd --zone=public --list-ports | grep -q "$fallback_port/tcp" 2>/dev/null; then
                firewall-cmd --zone=public --add-port="$fallback_port/tcp" --permanent > /dev/null 2>&1
            fi

            if ! firewall-cmd --zone=public --list-ports | grep -q "$fallback_port/udp" 2>/dev/null; then
                firewall-cmd --zone=public --add-port="$fallback_port/udp" --permanent > /dev/null 2>&1
            fi

            if ! firewall-cmd --zone=public --list-ports | grep -q "80/tcp" 2>/dev/null; then
                firewall-cmd --zone=public --add-port=80/tcp --permanent > /dev/null 2>&1
            fi

            if ! firewall-cmd --zone=public --list-ports | grep -q "80/udp" 2>/dev/null; then
                firewall-cmd --zone=public --add-port=80/udp --permanent > /dev/null 2>&1
            fi

            if ! firewall-cmd --zone=public --list-ports | grep -q "$listen_port/tcp" 2>/dev/null; then
                firewall-cmd --zone=public --add-port="$listen_port/tcp" --permanent > /dev/null 2>&1
            fi

            if ! firewall-cmd --zone=public --list-ports | grep -q "$listen_port/udp" 2>/dev/null; then
                firewall-cmd --zone=public --add-port="$listen_port/udp" --permanent > /dev/null 2>&1
            fi

            if ! firewall-cmd --zone=public --list-ports | grep -q "$override_port/tcp" 2>/dev/null; then
                firewall-cmd --zone=public --add-port="$override_port/tcp" --permanent > /dev/null 2>&1
            fi

            if ! firewall-cmd --zone=public --list-ports | grep -q "$override_port/udp" 2>/dev/null; then
                firewall-cmd --zone=public --add-port="$override_port/udp" --permanent > /dev/null 2>&1
            fi

            if ! firewall-cmd --zone=public --list-ports | grep -q "$fallback_port/tcp" 2>/dev/null; then
                firewall-cmd --zone=public --add-port="$fallback_port/tcp" --permanent > /dev/null 2>&1
            fi

            if ! firewall-cmd --zone=public --list-ports | grep -q "$fallback_port/udp" 2>/dev/null; then
                firewall-cmd --zone=public --add-port="$fallback_port/udp" --permanent > /dev/null 2>&1
            fi

            if ! firewall-cmd --zone=public --list-ports | grep -q "80/tcp" 2>/dev/null; then
                firewall-cmd --zone=public --add-port=80/tcp --permanent > /dev/null 2>&1
            fi

            if ! firewall-cmd --zone=public --list-ports | grep -q "80/udp" 2>/dev/null; then
                firewall-cmd --zone=public --add-port=80/udp --permanent > /dev/null 2>&1
            fi
            firewall-cmd --reload
            echo "Firewall configuration has been updated."
            ;;
    esac
}

function create_sing_box_folders() {
    local folders=("/usr/local/etc/sing-box" "/etc/ssl/private")
    for folder in "${folders[@]}"; do
        if [[ ! -d "$folder" ]]; then
            mkdir -p "$folder"
            [ "$folder" = "/usr/local/etc/sing-box" ] && touch "$folder/config.json"
        fi
    done
}

function create_juicity_folder() {
    local folders=("/usr/local/etc/juicity" "/etc/ssl/private")
    for folder in "${folders[@]}"; do
        if [[ ! -d "$folder" ]]; then
            mkdir -p "$folder"
            [ "$folder" = "/usr/local/etc/juicity" ] && touch "$folder/config.json"
        fi
    done
}

function ensure_clash_yaml() {
    local clash_yaml="/usr/local/etc/sing-box/clash.yaml"
    if [ ! -e "$clash_yaml" ]; then
        touch "$clash_yaml"
    fi
}

function check_config_file_existence() {
    local config_file="/usr/local/etc/sing-box/config.json"
    if [ ! -f "$config_file" ]; then
     echo -e "${RED}sing-box 配置文件不存在，请先搭建节点！${NC}"
      exit 1
    fi
}

function generate_naive_random_filename() {
    local dir="/usr/local/etc/sing-box"
    local filename=""    
    while true; do
        random_value=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 5 | head -n 1)        
        filename="naive_client_${random_value}.json"       
        if [ ! -e "${dir}/${filename}" ]; then
            touch "${dir}/${filename}"
            naive_client_filename="${dir}/${filename}"
            break
        fi
    done
}

function get_temp_config_file() {
    temp_file=$(mktemp)
    curl -sSL "https://api.zeroteam.top/warp?format=sing-box" > "$temp_file"
}

function install_sing_box() {
    if [[ -f "/usr/local/bin/sing-box" && -f "/usr/local/etc/sing-box/config.json" ]]; then
        return 1
    else
        get_local_ip
        configure_dns64
        select_sing_box_install_option
        configure_sing_box_service
        create_sing_box_folders
    fi
}

function configure_dns64() {
    if [[ -n $ip_v4 ]]; then
        return
    fi
    if [[ -n $ip_v6 ]]; then
        echo "Check that the machine is IPv6 single-stack network, configure DNS64..."
        sed -i '/^nameserver /s/^/#/' /etc/resolv.conf 
        echo "nameserver 2001:67c:2b0::4" >> /etc/resolv.conf
        echo "nameserver 2001:67c:2b0::6" >> /etc/resolv.conf
        echo "DNS64 configuration is complete."
    fi
}

function enable_bbr() {
    if grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf; then
        echo "BBR is already enabled, skipping configuration."
        return
    fi
    while true; do
        read -p "是否开启 BBR (Y/N，默认N)? " -i "N" response
        response=${response:-"N"}
        if [[ $response == "y" || $response == "Y" ]]; then
            echo "Enable BBR..."
            echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
            echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
            sysctl -p > /dev/null
            echo "BBR has been enabled"
            break
        elif [[ $response == "n" || $response == "N" ]]; then
            echo "BBR will not be enabled."
            break
        else
            echo -e "${RED}无效的输入，请重新输入！${NC}"
        fi
    done
}

function select_sing_box_install_option() {
    while true; do
        echo "请选择 sing-box 的安装方式（默认1）："
        echo "1). 下载安装 sing-box（Latest 版本）"
        echo "2). 下载安装 sing-box（Beta 版本）"
        echo "3). 编译安装 sing-box（完整功能版本）"
        read -p "请选择 [1-2]: " install_option
        install_option="${install_option:-1}"
        case $install_option in
            1)
                install_latest_sing_box
                break
                ;;
            2)
                install_Pre_release_sing_box
                break
                ;;
            3)
                install_go
                compile_install_sing_box
                break
                ;;
            *)
                echo -e "${RED}无效的选择，请重新输入！${NC}"
                ;;
        esac
    done
}

function install_go() {
    if ! command -v go &> /dev/null; then
        echo "Downloading Go..."
        local go_arch
        case $(uname -m) in
            x86_64)
                go_arch="amd64"
                ;;
            i686)
                go_arch="386"
                ;;
            aarch64)
                go_arch="arm64"
                ;;
            armv6l)
                go_arch="armv6l"
                ;;
            *)
                echo -e "${RED}不支持的架构: $(uname -m)${NC}"
                exit 1
                ;;
        esac
        local go_version
        go_version=$(curl -sL "https://golang.org/VERSION?m=text" | grep -o 'go[0-9]\+\.[0-9]\+\.[0-9]\+')
        local go_download_url="https://go.dev/dl/$go_version.linux-$go_arch.tar.gz"
        wget -qO- "$go_download_url" | tar -xz -C /usr/local
        echo 'export PATH=$PATH:/usr/local/go/bin' |  tee -a /etc/profile >/dev/null
        source /etc/profile
        go version
        echo "Go has been installed."
    else
        echo "Go is already installed, skipping installation."
    fi
}

function compile_install_sing_box() {
    local go_install_command="go install -v -tags \
with_quic,\
with_grpc,\
with_dhcp,\
with_wireguard,\
with_shadowsocksr,\
with_ech,\
with_utls,\
with_reality_server,\
with_acme,\
with_clash_api,\
with_v2ray_api,\
with_gvisor,\
with_lwip \
github.com/sagernet/sing-box/cmd/sing-box@latest"
    echo "Compiling and installing sing-box, please wait..."
    $go_install_command
    if [[ $? -eq 0 ]]; then
        mv ~/go/bin/sing-box /usr/local/bin/
        chmod +x /usr/local/bin/sing-box
        echo "sing-box has been compiled and installed successfully."
    else
        echo -e "${RED}sing-box compilation and installation failed.${NC}"
        exit 1
    fi
}

function install_latest_sing_box() {
    local arch=$(uname -m)
    local url="https://api.github.com/repos/SagerNet/sing-box/releases/latest"
    local download_url
    case $arch in
        x86_64|amd64)
            download_url=$(curl -s $url | grep -o "https://github.com[^\"']*linux-amd64.tar.gz")
            ;;
        armv7l)
            download_url=$(curl -s $url | grep -o "https://github.com[^\"']*linux-armv7.tar.gz")
            ;;
        aarch64|arm64)
            download_url=$(curl -s $url | grep -o "https://github.com[^\"']*linux-arm64.tar.gz")
            ;;
        amd64v3)
            download_url=$(curl -s $url | grep -o "https://github.com[^\"']*linux-amd64v3.tar.gz")
            ;;
        s390x)
            download_url=$(curl -s $url | grep -o "https://github.com[^\"']*linux-s390x.tar.gz")
            ;;            
        *)
            echo -e "${RED}不支持的架构：$arch${NC}"
            return 1
            ;;
    esac
    if [ -n "$download_url" ]; then
        echo "Downloading Sing-Box..."
        wget -qO sing-box.tar.gz "$download_url" 2>&1 >/dev/null
        tar -xzf sing-box.tar.gz -C /usr/local/bin --strip-components=1
        rm sing-box.tar.gz
        chmod +x /usr/local/bin/sing-box
        echo "Sing-Box installed successfully."
    else
        echo -e "${RED}Unable to retrieve the download URL for Sing-Box.${NC}"
        return 1
    fi
}

function install_Pre_release_sing_box() {
    local arch=$(uname -m)
    local url="https://api.github.com/repos/SagerNet/sing-box/releases"
    local download_url
    case $arch in
        x86_64|amd64)
            download_url=$(curl -s "$url" | jq -r '.[] | select(.prerelease == true) | .assets[] | select(.browser_download_url | contains("linux-amd64.tar.gz")) | .browser_download_url' | head -n 1)
            ;;
        armv7l)
            download_url=$(curl -s "$url" | jq -r '.[] | select(.prerelease == true) | .assets[] | select(.browser_download_url | contains("linux-armv7.tar.gz")) | .browser_download_url' | head -n 1)
            ;;
        aarch64|arm64)
            download_url=$(curl -s "$url" | jq -r '.[] | select(.prerelease == true) | .assets[] | select(.browser_download_url | contains("linux-arm64.tar.gz")) | .browser_download_url' | head -n 1)
            ;;
        amd64v3)
            download_url=$(curl -s "$url" | jq -r '.[] | select(.prerelease == true) | .assets[] | select(.browser_download_url | contains("linux-amd64v3.tar.gz")) | .browser_download_url' | head -n 1)
            ;;
        s390x)
            download_url=$(curl -s "$url" | jq -r '.[] | select(.prerelease == true) | .assets[] | select(.browser_download_url | contains("linux-s390x.tar.gz")) | .browser_download_url' | head -n 1)
            ;;            
        *)
            echo -e "${RED}不支持的架构：$arch${NC}"
            return 1
            ;;
    esac
    if [ -n "$download_url" ]; then
        echo "Downloading Sing-Box..."
        wget -qO sing-box.tar.gz "$download_url" 2>&1 >/dev/null
        tar -xzf sing-box.tar.gz -C /usr/local/bin --strip-components=1
        rm sing-box.tar.gz
        chmod +x /usr/local/bin/sing-box

        echo "Sing-Box installed successfully."
    else
        echo -e "${RED}Unable to get pre-release download link for Sing-Box.${NC}"
        return 1
    fi
}

function install_latest_juicity() {
    local arch=$(uname -m)
    case $arch in
        "arm64")
            arch_suffix="arm64"
            ;;
        "armv5")
            arch_suffix="armv5"
            ;;
        "armv6")
            arch_suffix="armv6"
            ;;
        "armv7")
            arch_suffix="armv7"
            ;;
        "mips")
            arch_suffix="mips32"
            ;;
        "mipsel")
            arch_suffix="mips32le"
            ;;
        "mips64")
            arch_suffix="mips64"
            ;;
        "mips64el")
            arch_suffix="mips64le"
            ;;
        "riscv64")
            arch_suffix="riscv64"
            ;;
        "i686")
            arch_suffix="x86_32"
            ;;
        "x86_64")
            if [ -n "$(grep avx2 /proc/cpuinfo)" ]; then
                arch_suffix="x86_64_v3_avx2"
            else
                arch_suffix="x86_64_v2_sse"
            fi
            ;;
        *)
            echo "Unsupported architecture: $arch"
            return 1
            ;;
    esac
    local github_api_url="https://api.github.com/repos/juicity/juicity/releases/latest"
    local download_url=$(curl -s "$github_api_url" | grep "browser_download_url.*$arch_suffix.zip\"" | cut -d '"' -f 4)
    local temp_dir=$(mktemp -d)
    local install_path="/usr/local/bin/juicity-server"
    echo "Downloading the latest version of juicity-server..."
    wget -P "$temp_dir" "$download_url" >/dev/null 2>&1
    unzip "$temp_dir/*.zip" -d "$temp_dir" >/dev/null 2>&1    
    mv "$temp_dir/juicity-server" "$install_path" >/dev/null 2>&1
    chmod +x /usr/local/bin/juicity-server
    echo "juicity-server has been downloaded."    
    rm -rf "$temp_dir"
}

function configure_sing_box_service() {
    echo "Configuring sing-box startup service..."
    local service_file="/etc/systemd/system/sing-box.service"
    if [[ -f $service_file ]]; then
        rm "$service_file"
    fi
    local service_config='[Unit]
Description=sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

[Service]
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
ExecStart=/usr/local/bin/sing-box run -c /usr/local/etc/sing-box/config.json
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=10s
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target'
    echo "$service_config" >"$service_file"
    echo "sing-box startup service has been configured."
}

function configure_juicity_service() {
    echo "Configuring juicity startup service..."
    local service_file="/etc/systemd/system/juicity.service"
    if [[ -f $service_file ]]; then
        rm "$service_file"
    fi
    local service_config='[Unit]
Description=juicity-server Service
Documentation=https://github.com/juicity/juicity
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
Environment=QUIC_GO_ENABLE_GSO=true
ExecStart=/usr/local/bin/juicity-server run -c /usr/local/etc/juicity/config.json --disable-timestamp
Restart=on-failure
LimitNPROC=512
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target'
    echo "$service_config" >"$service_file"
    echo "juicity startup service has been configured."
}

function set_listen_port() {
    while true; do
        read -p "请输入监听端口 (默认443): " new_listen_port
        new_listen_port=${new_listen_port:-443}
        if [[ $new_listen_port =~ ^[1-9][0-9]{0,4}$ && $new_listen_port -le 65535 ]]; then
            check_result=$(netstat -tulpn | grep -E "\b${new_listen_port}\b")
            if [ -z "$check_result" ]; then
                echo "监听端口：$new_listen_port"
                break
            else
                echo -e "${RED}错误：端口已被占用，请选择其他端口！${NC}" >&2
            fi
        else
            echo -e "${RED}错误：端口范围1-65535，请重新输入！${NC}" >&2
        fi
    done
    listen_port="$new_listen_port"
}

function set_user_name() {  
    while true; do
        read -p "请输入用户名 (默认随机生成): " new_user_name
        if [[ -z "$new_user_name" ]]; then
            new_user_name=$(sing-box generate rand --base64 6 2>/dev/null || openssl rand -base64 5)           
            echo "用户名：$new_user_name"
            break
        elif [[ ! -z "$new_user_name" ]]; then
            break
        fi
    done 
    user_names+=("$new_user_name")   
}

function set_user_password() { 
    while true; do
        read -p "请输入密码（默认随机生成）: " new_user_password
        if [[ -z "$new_user_password" ]]; then
            new_user_password=$(sing-box generate rand --base64 9 2>/dev/null || openssl rand -base64 9)
            echo "密码：$new_user_password"            
            break
        elif [[ ! -z "$new_user_password" ]]; then
            break
        fi
    done
    user_passwords+=("$new_user_password")    
}

function set_ss_password() {
    while true; do
        read -p "请输入 Shadowsocks 密码（默认随机生成）: " ss_user_password
        if [[ -z $ss_user_password ]]; then
            if [[ $encryption_choice == 1 || $encryption_choice == 2 ]]; then
                ss_password=$(sing-box generate rand --base64 32)
                echo "Shadowsocks 密码: $ss_password"
            else
                ss_password=$(sing-box generate rand --base64 16)
                echo "Shadowsocks 密码: $ss_password"
            fi
            ss_passwords+=("$ss_password")
            break
        elif [[ $encryption_choice == 1 || $encryption_choice == 2 ]] && [[ ${#ss_user_password} -eq 32 ]]; then
            ss_password="$ss_user_password"
            echo "Shadowsocks 密码: $ss_password"
            ss_passwords+=("$ss_password")
            break
        elif [[ $encryption_choice != 1 && $encryption_choice != 2 ]] && [[ ${#ss_user_password} -eq 16 ]]; then
            ss_password="$ss_user_password"
            echo "Shadowsocks 密码: $ss_password"
            ss_passwords+=("$ss_password")
            break
        else
            echo -e "${RED}错误：密码长度不符合要求，请重新输入！${NC}"
        fi
    done
}

function set_stls_password() {
    while true; do
        read -p "请输入 ShadowTLS 密码（默认随机生成）: " stls_user_password
        if [[ -z $stls_user_password ]]; then
            if [[ $encryption_choice == 1 || $encryption_choice == 2 ]]; then
                stls_password=$(sing-box generate rand --base64 32)
                echo "ShadowTLS 密码: $stls_password"
            else
                stls_password=$(sing-box generate rand --base64 16)
                echo "ShadowTLS 密码: $stls_password"
            fi
            stls_passwords+=("$stls_password")
            break
        elif [[ $encryption_choice == 1 || $encryption_choice == 2 ]] && [[ ${#stls_user_password} -eq 32 ]]; then
            stls_password="$stls_user_password"
            echo "ShadowTLS 密码: $stls_password"
            stls_passwords+=("$stls_password")
            break
        elif [[ $encryption_choice != 1 && $encryption_choice != 2 ]] && [[ ${#stls_user_password} -eq 16 ]]; then
            stls_password="$stls_user_password"
            echo "ShadowTLS 密码: $stls_password"
            stls_passwords+=("$stls_password")
            break
        else
            echo -e "${RED}错误：密码长度不符合要求，请重新输入！${NC}"
        fi
    done
}

function set_up_speed() { 
    while true; do
        read -p "请输入上行速率 (默认50): " new_up_mbps
        new_up_mbps=${new_up_mbps:-50}
        if [[ $new_up_mbps =~ ^[0-9]+$ ]]; then            
            echo "上行速率：$new_up_mbps Mbps"
            break
        else
            echo -e "${RED}错误：请输入数字作为上行速率！${NC}"
        fi
    done
    up_mbps="$new_up_mbps"
}

function set_down_speed() {
    while true; do
        read -p "请输入下行速率 (默认100): " new_down_mbps
        new_down_mbps=${new_down_mbps:-100}
        if [[ $new_down_mbps =~ ^[0-9]+$ ]]; then            
            echo "下行速率：$new_down_mbps Mbps"
            break
        else
            echo -e "${RED}错误：请输入数字作为下行速率！${NC}"
        fi
    done
    down_mbps="$new_down_mbps"
}

function set_uuid() {
    while true; do
        read -p "请输入UUID（默认随机生成）: " new_user_uuid
        if [ -z "$new_user_uuid" ]; then
            new_user_uuid=$(sing-box generate uuid 2>/dev/null || openssl rand -hex 16 | awk '{print substr($1,1,8) "-" substr($1,9,4) "-" substr($1,13,4) "-" substr($1,17,4) "-" substr($1,21)}')
        fi
        if [[ $new_user_uuid =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]; then           
            echo "UUID：$new_user_uuid"
            break
        else
            echo -e "${RED}无效的UUID格式，请重新输入！${NC}"
        fi
    done
    user_uuids+=("$new_user_uuid")
}

function set_override_port() {
    while true; do
        read -p "请输入目标端口 (默认443): " new_override_port
        new_override_port=${new_override_port:-443}
        if [[ $new_override_port =~ ^[1-9][0-9]{0,4}$ && $new_override_port -le 65535 ]]; then            
            echo "目标端口: $new_override_port"
            break
        else
            echo -e "${RED}错误：端口范围1-65535，请重新输入！${NC}"
        fi
    done
    override_port="$new_override_port"
}

function generate_unique_tag() {
    local config_file="/usr/local/etc/sing-box/config.json"
    while true; do
        random_tag=$(head /dev/urandom | tr -dc 'a-z0-9' | fold -w 8 | head -n 1)
        tag_label="${random_tag}-in"
        if ! grep -qE "\"tag\":\\s*\"$tag_label\"(,|$)" "$config_file"; then
            break
        fi
    done
}

function set_override_address() {
  while true; do
    read -p "请输入目标地址（IP或域名）: " target_address
    if [[ -z "$target_address" ]]; then
      echo -e "${RED}错误：目标地址不能为空！${NC}"
      continue
    fi
    if ( [[ $target_address =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && [[ $(grep -o '\.' <<< "$target_address" | wc -l) -eq 3 ]] ) || ( [[ $target_address =~ ^[a-fA-F0-9:]+$ ]] && [[ $(grep -o ':' <<< "$target_address" | wc -l) -ge 2 ]] ); then
      break
    else
      resolved_ips=$(host -t A "$target_address" | awk '/has address/ { print $4 }')

      if [[ -n "$resolved_ips" ]] && ( [[ "$resolved_ips" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || [[ "$resolved_ips" =~ ^[a-fA-F0-9:]+$ ]] ); then
        break
      else
        echo -e "${RED}错误：请输入有效的 IP 地址或域名！${NC}"
      fi
    fi
  done
}

function set_server_name() {
    while true; do
        read -p "请输入可用的 ServerName 列表 (默认为 nijigen-works.jp): " user_input
        if [[ -z "$user_input" ]]; then
            server_name="nijigen-works.jp"
            echo "ServerName：$server_name"
            break
        else
            server_name="$user_input"
            echo "ServerName：$server_name"
            echo "Verifying server's TLS version support..."
            if command -v openssl >/dev/null 2>&1; then
                local openssl_output=$(timeout 10s openssl s_client -connect "$server_name:443" -tls1_3 2>&1)
                if [[ $openssl_output == *"TLS_AES_256_GCM_SHA384"* || \
                      $openssl_output == *"TLS_AES_128_GCM_SHA256"* || \
                      $openssl_output == *"TLS_CHACHA20_POLY1305_SHA256"* || \
                      $openssl_output == *"TLS_AES_128_CCM_SHA256"* || \
                      $openssl_output == *"TLS_AES_128_CCM_8_SHA256"* ]]; then
                    break
                else
                    echo -e "${RED}该网址不支持 TLS 1.3，请重新输入！${NC}"
                fi
            else
                echo "OpenSSL is not installed, cannot verify TLS support."
                break
            fi
        fi
    done
}

function set_target_server() {
    while true; do
        read -p "请输入目标网站地址(默认为 nijigen-works.jp): " user_input
        if [[ -z "$user_input" ]]; then
            target_server="nijigen-works.jp"
            echo "目标网址：$target_server"
            break
        else
            target_server="$user_input"
            echo "目标网址：$target_server"
            echo "Verifying server's TLS version support..."
            if command -v openssl >/dev/null 2>&1; then
                local openssl_output=$(timeout 10s openssl s_client -connect "$target_server:443" -tls1_3 2>&1)
                if [[ $openssl_output == *"TLS_AES_256_GCM_SHA384"* || \
                      $openssl_output == *"TLS_AES_128_GCM_SHA256"* || \
                      $openssl_output == *"TLS_CHACHA20_POLY1305_SHA256"* || \
                      $openssl_output == *"TLS_AES_128_CCM_SHA256"* || \
                      $openssl_output == *"TLS_AES_128_CCM_8_SHA256"* ]]; then
                    break
                else
                    echo -e "${RED}该目标网站地址不支持 TLS 1.3，请重新输入！${NC}" 
                fi
            else
                echo "OpenSSL is not installed, cannot verify TLS support."
                break
            fi
        fi
    done
}

function get_local_ip() {
    local local_ip_v4
    local local_ip_v6
    local_ip_v4=$(curl -s4 https://api.myip.com | grep -o '"ip":"[^"]*' | awk -F ':"' '{print $2}')
    if [[ -n "$local_ip_v4" ]]; then
        ip_v4="$local_ip_v4"
    else
        local_ip_v4=$(curl -s4 icanhazip.com)
        if [[ -n "$local_ip_v4" ]]; then
            ip_v4="$local_ip_v4"
        fi
    fi
    local_ip_v6=$(curl -s6 https://api.myip.com | grep -o '"ip":"[^"]*' | awk -F ':"' '{print $2}')
    if [[ -n "$local_ip_v6" ]]; then
        ip_v6="$local_ip_v6"
    else
        local_ip_v6=$(curl -s6 icanhazip.com)
        if [[ -n "$local_ip_v6" ]]; then
            ip_v6="$local_ip_v6"
        fi
    fi
    if [[ -z "$ip_v4" && -z "$ip_v6" ]]; then
        echo -e "${RED}无法获取本机IP地址！${NC}"
    fi
}

function get_ech_keys() {
    local input_file="/etc/ssl/private/ech.tmp"
    local output_file="/etc/ssl/private/ech.pem"
    sing-box generate ech-keypair [--pq-signature-schemes-enabled] > "$input_file"
    IFS=$'\n' read -d '' -ra lines < "$input_file"
    exec 3>"$output_file"
    in_ech_keys_section=false
    in_ech_configs_section=false
    for line in "${lines[@]}"; do
        if [[ "$line" == *"BEGIN ECH KEYS"* ]]; then
            in_ech_keys_section=true
            ech_key+="            \"$line\",\n"
        elif [[ "$line" == *"END ECH KEYS"* ]]; then
            in_ech_keys_section=false
            ech_key+="            \"$line\""
        elif [[ "$line" == *"BEGIN ECH CONFIGS"* ]]; then
            in_ech_configs_section=true
            ech_config+="            \"$line\",\n"
        elif [[ "$line" == *"END ECH CONFIGS"* ]]; then
            in_ech_configs_section=false
            ech_config+="            \"$line\""
        elif [ "$in_ech_keys_section" = true ]; then
            ech_key+="            \"$line\",\n"
        elif [ "$in_ech_configs_section" = true ]; then
            ech_config+="            \"$line\",\n"
        else
            echo "\"$line\"," >&3
        fi
  done
  exec 3>&-
  rm "$input_file"
}

function get_domain() {
    while true; do
        read -p "请输入域名（关闭Cloudflare代理）： " user_domain
        resolved_ipv4=$(dig +short A "$user_domain" 2>/dev/null)
        resolved_ipv6=$(dig +short AAAA "$user_domain" 2>/dev/null)
        if [[ -z $user_domain ]]; then
            echo -e "${RED}错误：域名不能为空，请重新输入！${NC}"
        else
            if [[ ("$resolved_ipv4" == "$ip_v4" && ! -z "$resolved_ipv4") || ("$resolved_ipv6" == "$ip_v6" && ! -z "$resolved_ipv6") ]]; then
                break
            else
                if [[ -z "$resolved_ipv4" && -n "$ip_v4" ]]; then
                    resolved_ip_v4=$(ping -4 "$user_domain" -c 1 2>/dev/null | sed '1{s/[^(]*(//;s/).*//;q}')
                    if [[ ("$resolved_ip_v4" == "$ip_v4" && ! -z "$resolved_ip_v4") ]]; then
                        break
                    fi
                fi
                if [[ -z "$resolved_ipv6" && -n "$ip_v6" ]]; then
                    resolved_ip_v6=$(ping -6 "$user_domain" -c 1 2>/dev/null | sed '1{s/[^(]*(//;s/).*//;q}')
                    if [[ ("$resolved_ip_v6" == "$ip_v6" && ! -z "$resolved_ip_v6") ]]; then
                        break
                    fi
                fi
                echo -e "${RED}错误：域名未绑定本机IP，请重新输入！${NC}"
            fi
        fi
    done
    domain="$user_domain"
}

function verify_domain() {
    new_domain=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_id" \
    -H "Authorization: Bearer $api_token" | jq -r '.result.name')
    if [[ $new_domain =~ \.(tk|ml|ga|gq|cf)$ ]]; then
        echo -e "${RED}您的域名为$new_domain，该域名不支持使用 CloudFlare 的 API 申请证书，请选择其他方式申请证书！${NC}"
        domain_supported=false
    else
        while true; do
            read -p "请输入主域名前缀（若为空则使用主域名申请证书，不需要在 CloudFlare 添加 DNS 解析记录）: " domain_prefix

            if [ -z "$domain_prefix" ]; then
                domain="$new_domain"
                record_name="$domain_prefix"
                break
            else
                domain="$domain_prefix"."$new_domain"
                record_name="$domain_prefix"
                break
            fi
        done
        domain_supported=true
    fi
}

function set_dns_record() {
    if [[ -z "$record_name" ]]; then
        name_value="@"
    else
        name_value="$record_name"
    fi
    if [[ -n "$ip_v4" ]]; then
        record_content=" $ip_v4"
        record_type="A"
    elif [[ -z "$ip_v4" && -n "$ip_v6" ]]; then
        record_content=" $ip_v6"
        record_type="AAAA"
    fi
    curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CF_Zone_ID/dns_records" \
      -H "Authorization: Bearer $CF_Token" \
      -H "Content-Type: application/json" \
      --data "{\"type\":\"$record_type\",\"name\":\"$name_value\",\"content\":\"$record_content\",\"ttl\":120,\"proxied\":false}" >/dev/null
}

function get_api_token() {
    while true; do
        read -p "请输入 CloudFlare 的限制性 API 令牌: " api_token
        if [[ ! $api_token =~ ^[A-Za-z0-9_-]{40}$ ]]; then
            echo -e "${RED}API令牌格式不正确，请重新输入！${NC}"
        else
            export CF_Token="$api_token" 
            break 
        fi
    done
}

function get_zone_id() {
    while true; do
        read -p "请输入 CloudFlare 的区域 ID: " zone_id
        if [[ ! $zone_id =~ ^[a-z0-9]{32}$ ]]; then
            echo -e "${RED}CloudFlare 的区域 ID 格式不正确，请重新输入！${NC}"
        else
            export CF_Zone_ID="$zone_id"
            break
        fi
    done
}

function get_api_email() {
    while true; do
        read -p "请输入 CloudFlare 的登录邮箱: " api_email
        if [[ ! $api_email =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$ ]]; then
           echo -e "${RED}邮箱格式不正确，请重新输入！${NC}"
        else
            export CF_Email="$api_email"
            break
        fi
    done
}
   
function set_fake_domain() {
    while true; do
        read -p "请输入伪装网址（默认: www.fan-2000.com）: " fake_domain
        fake_domain=${fake_domain:-"www.fan-2000.com"}
        if curl --output /dev/null --silent --head --fail "$fake_domain"; then
            echo "伪装网址: $fake_domain"
            break
        else
            echo -e "${RED}伪装网址无效或不可用，请重新输入！${NC}"
        fi
    done
}

function set_certificate_path() {
    while true; do
        read -p "请输入 PEM 证书位置: " certificate_path_input
        if [[ ! -f "$certificate_path_input" ]]; then
            echo -e "${RED}错误：证书文件不存在，请重新输入！${NC}"
            continue
        fi
        certificate_file=$(basename "$certificate_path_input")
        allowed_extensions=("crt" "pem")
        if [[ ! "${allowed_extensions[@]}" =~ "${certificate_file##*.}" ]]; then
            echo -e "${RED}错误：不支持的证书格式，请配置.crt或.pem格式的证书文件！${NC}"
            continue
        fi
        certificate_path="$certificate_path_input" 
        break
    done
}

function set_private_key_path() {
    while true; do
        read -p "请输入 PEM 私钥位置: " private_key_path_input
        if [[ ! -f "$private_key_path_input" ]]; then
            echo -e "${RED}错误：私钥文件不存在，请重新输入！${NC}"
            continue
        fi
        private_key_file=$(basename "$private_key_path_input")
        allowed_extensions=("key" "pem")
        if [[ ! "${allowed_extensions[@]}" =~ "${private_key_file##*.}" ]]; then
            echo -e "${RED}错误：不支持的私钥格式，请配置.key或.pem格式的私钥文件！${NC}"
            continue
        fi
        private_key_path="$private_key_path_input"  
        break
    done
}

function apply_certificate() {
    certificate_path="/etc/ssl/private/"$domain".crt"
    private_key_path="/etc/ssl/private/"$domain".key"
    local has_ipv4=false
    local ca_servers=("letsencrypt" "zerossl")
    local return_to_menu=false
    if [[ -n "$ip_v4" ]]; then
        has_ipv4=true
    fi
    echo "Requesting a certificate..."        
    curl -s https://get.acme.sh | sh -s email=example@gmail.com 2>&1 | tail -n 1
    alias acme.sh=~/.acme.sh/acme.sh
    for ca_server in "${ca_servers[@]}"; do
        echo "Requesting a certificate from $ca_server..."
        ~/.acme.sh/acme.sh --set-default-ca --server "$ca_server"
        if $has_ipv4; then
            result=$(~/.acme.sh/acme.sh --issue -d "$domain" --standalone -k ec-256 2>&1)
        else
            result=$(~/.acme.sh/acme.sh --issue -d "$domain" --standalone -k ec-256 --listen-v6 2>&1)
        fi
        if [[ $result == *"force"* ]]; then
            if $has_ipv4; then
                result=$(~/.acme.sh/acme.sh --issue -d "$domain" --standalone -k ec-256 --force 2>&1)
            else
                result=$(~/.acme.sh/acme.sh --issue -d "$domain" --standalone -k ec-256 --listen-v6 --force 2>&1)
            fi
        fi
        if [[ $result == *"log"* || $result == *"debug"* || $result == *"error"* ]]; then
            echo -e "${RED}$result ${NC}" 
            continue  
        fi
        if [[ $? -eq 0 ]]; then
            echo "Installing the certificate..."
            ~/.acme.sh/acme.sh --install-cert -d "$domain" --ecc --key-file "$private_key_path" --fullchain-file "$certificate_path"
            break 
        else
            echo -e "${RED}Failed to obtain a certificate from $ca_server！${NC}"
            return_to_menu=true
        fi
    done
    if [ "$return_to_menu" = true ]; then
        echo -e "${RED}证书申请失败，请使用其它方法申请证书！${NC}"
        return 1
    fi
}

function Apply_api_certificate() {
    certificate_path="/etc/ssl/private/"$domain".crt"
    private_key_path="/etc/ssl/private/"$domain".key"
    local has_ipv4=false
    local ca_servers=("letsencrypt" "zerossl")
    if [[ -n "$ip_v4" ]]; then
        has_ipv4=true
    fi
    echo "Requesting a certificate..."        
    curl -s https://get.acme.sh | sh -s email=example@gmail.com 2>&1 | tail -n 1
    alias acme.sh=~/.acme.sh/acme.sh
    for ca_server in "${ca_servers[@]}"; do
        echo "Requesting a certificate from $ca_server..."
        ~/.acme.sh/acme.sh --set-default-ca --server "$ca_server"
        if $has_ipv4; then
            result=$(~/.acme.sh/acme.sh --issue --dns dns_cf -d "$domain" -k ec-256 2>&1)
        else
            result=$(~/.acme.sh/acme.sh --issue --dns dns_cf -d "$domain" -k ec-256 --listen-v6 2>&1)
        fi
        if [[ $result == *"log"* || $result == *"debug"* || $result == *"error"* || $result == *"force"* ]]; then
            echo -e "${RED}$result ${NC}"
            return_to_menu=true  
            continue  
        fi
        if [[ $? -eq 0 ]]; then
            echo "Installing the certificate..."
            ~/.acme.sh/acme.sh --install-cert -d "$domain" --ecc --key-file "$private_key_path" --fullchain-file "$certificate_path"
            break 
        else
            echo -e "${RED}Failed to obtain a certificate from $ca_server！${NC}"
            return_to_menu=true
        fi
    done
    if [ "$return_to_menu" = true ]; then
        echo -e "${RED}证书申请失败，请使用其它方法申请证书！${NC}"
        return 1
    fi
}

function Reapply_certificates() {
    local tls_info_file="/usr/local/etc/sing-box/tls_info.json"
    local has_ipv4=false
    if [ -n "$ip_v4" ]; then
        has_ipv4=true
    fi
    if ! command -v acme.sh &>/dev/null; then
        curl -s https://get.acme.sh | sh -s email=example@gmail.com
    fi
    alias acme.sh=~/.acme.sh/acme.sh
    echo "Setting CA server to Let's Encrypt..."
    ~/.acme.sh/acme.sh --set-default-ca --server "letsencrypt"
    jq -c '.[]' "$tls_info_file" | while read -r tls_info; do
        server_name=$(echo "$tls_info" | jq -r '.server_name')
        key_path=$(echo "$tls_info" | jq -r '.key_path')
        certificate_path=$(echo "$tls_info" | jq -r '.certificate_path')
        echo "Requesting certificate for $server_name..."
        result=$(
            if $has_ipv4; then
                ~/.acme.sh/acme.sh --issue --dns dns_cf -d "$server_name" -k ec-256 --force
            else
                ~/.acme.sh/acme.sh --issue --dns dns_cf -d "$server_name" -k ec-256 --listen-v6 --force
            fi
        )
        if [[ "$result" =~ "Cert success." ]]; then
            echo "Certificate for $server_name has been applied using Cloudflare DNS verification."
        else
            echo "Cloudflare DNS verification failed for $server_name. Trying standalone verification..."
            result=$(
                if $has_ipv4; then
                    ~/.acme.sh/acme.sh --issue -d "$server_name" --standalone --force
                else
                    ~/.acme.sh/acme.sh --issue -d "$server_name" --standalone --listen-v6 --force
                fi
            )
            if [[ "$result" =~ "BEGIN CERTIFICATE" && "$result" =~ "END CERTIFICATE" ]]; then
                echo "Certificate for $server_name has been applied using Let's Encrypt CA."
            else
                echo "Failed to obtain certificate for $server_name using standalone verification as well."
                return 1
            fi
        fi      
        ~/.acme.sh/acme.sh --install-cert -d "$server_name" --ecc --key-file "$key_path" --fullchain-file "$certificate_path"
        echo "Certificate for $server_name has been installed."
    done
    rm -f "$tls_info_file"
}

function generate_private_key() {
    while true; do
        read -p "请输入私钥 (默认随机生成私钥): " local_private_key
        if [[ -z "$local_private_key" ]]; then
            local keypair_output=$(sing-box generate reality-keypair)
            local_private_key=$(echo "$keypair_output" | awk -F: '/PrivateKey/{gsub(/ /, "", $2); print $2}')
            local_public_key=$(echo "$keypair_output" | awk -F: '/PublicKey/{gsub(/ /, "", $2); print $2}')
            echo "private_key：$local_private_key"
            echo "public_key：$local_public_key"
            break
        else
            if [[ "$local_private_key" =~ ^[A-Za-z0-9_\-]{43}$ ]]; then
                read -p "请输入公钥: " local_public_key
                if ! [[ "$local_public_key" =~ ^[A-Za-z0-9_\-]{43}$ ]]; then
                    echo -e "${RED}无效的公钥，请重新输入！${NC}" 
                else
                    break
                fi
            else
                echo -e "${RED}无效的私钥，请重新输入！${NC}"
            fi
        fi
    done
    public_key="$local_public_key"
    private_key="$local_private_key"
}

function create_self_signed_cert() {
    while true; do
        read -p "请输入要用于自签名证书的域名（默认为 bing.com）: " user_domain
        domain_name=${user_domain:-"bing.com"}
        if curl --output /dev/null --silent --head --fail "$domain_name"; then
            openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) -keyout /etc/ssl/private/$domain_name.key -out /etc/ssl/private/$domain_name.crt -subj "/CN=$domain_name" -days 36500
            chmod 777 /etc/ssl/private/$domain_name.key
            chmod 777 /etc/ssl/private/$domain_name.crt
            break 
        else
            echo -e "${RED}无效的域名或域名不可用，请输入有效的域名！${NC}"
        fi
    done
    certificate_path="/etc/ssl/private/$domain_name.crt"
    private_key_path="/etc/ssl/private/$domain_name.key"
}

function select_encryption_method() {
    while true; do
        read -p "请选择加密方式(默认1)：
1). 2022-blake3-chacha20-poly1305
2). 2022-blake3-aes-256-gcm
3). 2022-blake3-aes-128-gcm
4). xchacha20-ietf-poly1305
5). chacha20-ietf-poly1305
6). aes-256-gcm
7). aes-192-gcm
8). aes-128-gcm
请选择[1-8]: " encryption_choice
        encryption_choice=${encryption_choice:-1}
        case $encryption_choice in
            1)
                ss_method="2022-blake3-chacha20-poly1305"
                ss_password=$(sing-box generate rand --base64 32)
                shadowtls_password=$(sing-box generate rand --base64 32)
                break
                ;;
            2)
                ss_method="2022-blake3-aes-256-gcm"
                ss_password=$(sing-box generate rand --base64 32)
                shadowtls_password=$(sing-box generate rand --base64 32)
                break
                ;;                
            3)
                ss_method="2022-blake3-aes-128-gcm"
                ss_password=$(sing-box generate rand --base64 16)
                shadowtls_password=$(sing-box generate rand --base64 16)
                break
                ;;

            4)
                ss_method="xchacha20-ietf-poly1305"
                ss_password=$(sing-box generate rand --base64 16)
                shadowtls_password=$(sing-box generate rand --base64 16)
                break
                ;;
            5)
                ss_method="chacha20-ietf-poly1305"
                ss_password=$(sing-box generate rand --base64 16)
                shadowtls_password=$(sing-box generate rand --base64 16)
                break
                ;;
            6)
                ss_method="aes-256-gcm"
                ss_password=$(sing-box generate rand --base64 16)
                shadowtls_password=$(sing-box generate rand --base64 16)
                break
                ;;
            7)
                ss_method="aes-192-gcm"
                ss_password=$(sing-box generate rand --base64 16)
                shadowtls_password=$(sing-box generate rand --base64 16)
                break
                ;;
            8)
                ss_method="aes-128-gcm"
                ss_password=$(sing-box generate rand --base64 16)
                shadowtls_password=$(sing-box generate rand --base64 16)
                break
                ;;                                                                
            *)
                echo -e "${RED}错误：无效的选择，请重新输入！${NC}"
                ;;
        esac
    done
}

function select_unlocked_items() {
    while true; do
        read -p "请选择要解锁的项目（支持多选）：
1). ChatGPT
2). Netflix
3). Disney+
4). YouTube
请选择[1-4]: " choices
        if [[ "$choices" =~ ^[1234]+$ ]]; then
            selected=($(echo "$choices" | sed 's/./& /g'))
            break
        else
            echo -e "${RED}错误：无效的选择，请重新输入！${NC}"
        fi
    done
}

function update_geosite_array() {
    for choice in "${selected[@]}"; do
      case $choice in
        1)
          geosite+=("\"openai\"")
          ;;
        2)
          geosite+=("\"netflix\"")
          ;;
        3)
          geosite+=("\"disney\"")
          ;;
        4)
          geosite+=("\"youtube\"")
          ;;
        *)
          echo -e "${RED}无效的选择: $choice${NC}"
          ;;
      esac
    done
}

function select_outbound() {
    while true; do
    read -p "请选择出站网络 (默认1)
1). warp-IPv4
2). warp-IPv6
请选择[1-2]: " outbound_choice
      case $outbound_choice in
        1|"")
          outbound="warp-IPv4-out"
          break
          ;;
        2)
          outbound="warp-IPv6-out"
          break
          ;;
        *)
          echo -e "${RED}错误：无效的选项，请重新输入！${NC}"
          ;;
      esac
    done
}

function select_congestion_control() {
    local default_congestion_control="bbr"
    while true; do
        read -p "请选择拥塞控制算法 (默认$default_congestion_control):
1). bbr
2). cubic
3). new_reno
请选择[1-3]: " congestion_control

        case $congestion_control in
            1)
                congestion_control="bbr"
                break
                ;;
            2)
                congestion_control="cubic"
                break
                ;;
            3)
                congestion_control="new_reno"
                break
                ;;
            "")
                congestion_control=$default_congestion_control
                break
                ;;
            *)
                echo -e "${RED}错误：无效的选择，请重新输入！${NC}"
                ;;
        esac
    done
}

function select_certificate_option() {
    local certificate_option
    local domain_supported=false
    local return_to_menu=false
    while true; do
        read -p "请选择证书来源 (默认1)：
1). 自签证书
2). 监听80端口申请证书（standalone模式）
3). cloudflare API 申请证书（DNS API模式）
4). 自定义证书路径
请选择[1-4]: " certificate_option
        certificate_option=${certificate_option:-1}
        case $certificate_option in
            1)
                if $disable_option; then
                    echo -e "${RED}NaiveProxy节点不支持自签证书，请使用acme申请证书！${NC}"
                    continue
                fi
                check_firewall_configuration
                create_self_signed_cert
                break
                ;;        
            2)
                get_local_ip
                get_domain
                check_firewall_configuration
                apply_certificate
                if [ "$return_to_menu" == true ]; then
                    return_to_menu=false
                    continue
                fi
                break
                ;;
            3)
                get_local_ip
                get_api_token
                get_zone_id
                get_api_email
                verify_domain
                set_dns_record
                check_firewall_configuration
                if [ "$domain_supported" == "false" ]; then
                    continue
                else
                    Apply_api_certificate
                    if [ "$return_to_menu" == true ]; then
                        return_to_menu=false
                        continue
                    fi
                    break
                fi
                ;;
            4)
                get_local_ip
                get_domain 
                check_firewall_configuration
                set_certificate_path
                set_private_key_path
                break
                ;;       
            *)
                echo -e "${RED}错误：无效的选择，请重新输入！${NC}"
                ;;
        esac
    done
}

function select_vmess_type() {
    while true; do
        read -p "请选择节点类型（默认1）：
1). VMess+TCP
2). VMess+WebSocket
3). VMess+gRPC
4). VMess+HTTPUpgrade
5). VMess+TCP+TLS
6). VMess+WebSocket+TLS
7). VMess+H2C+TLS
8). VMess+gRPC+TLS
9). VMess+HTTPUpgrade+TLS
请选择 [1-9]: " node_type
        case $node_type in
            "" | 1)
                tls_enabled=false
                break
                ;;
            2)
                transport_ws=true
                tls_enabled=false
                break
                ;;
            3)
                transport_grpc=true
                tls_enabled=false
                break
                ;;
            4)
                transport_httpupgrade=true
                tls_enabled=false
                break
                ;;
            5)
                tls_enabled=true
                break
                ;; 
            6)
                transport_ws=true
                tls_enabled=true
                break
                ;; 
            7)
                transport_http=true
                tls_enabled=true
                break
                ;;
            8)
                transport_grpc=true
                tls_enabled=true
                break
                ;;
            9)
                transport_httpupgrade=true
                tls_enabled=true
                break
                ;;
            *)
                echo -e "${RED}无效的选择，请重新输入！${NC}"
                ;;
        esac
    done
}

function select_vless_type() {
    while true; do
        read -p "请选择节点类型 (默认1)：     
1). VLESS+TCP
2). VLESS+WebSocket
3). VLESS+gRPC
4). VLESS+HTTPUpgrade
5). VLESS+Vision+REALITY
6). VLESS+H2C+REALITY
7). VLESS+gRPC+REALITY
请选择[1-7]: " flow_option
        case $flow_option in
            "" | 1)
                flow_type=""
                break
                ;;
            2)
                flow_type=""
                transport_ws=true
                break
                ;;
            3)
                flow_type=""
                transport_grpc=true
                break
                ;;
            4)
                flow_type=""
                transport_httpupgrade=true
                break
                ;;
            5)
                flow_type="xtls-rprx-vision"
                reality_enabled=true
                break
                ;;
            6)
                flow_type=""
                transport_http=true
                reality_enabled=true
                break
                ;;
            7)
                flow_type=""
                transport_grpc=true
                reality_enabled=true
                break
                ;;            
            *)
                echo -e "${RED}错误的选项，请重新输入！${NC}" >&2
                ;;
        esac
    done
}

function select_trojan_type() {
    while true; do
        read -p "请选择节点类型（默认1）：
1). Trojan+TCP
2). Trojan+WebSocket
3). Trojan+gRPC
4). Trojan+HTTPUpgrade
5). Trojan+TCP+TLS
6). Trojan+WebSocket+TLS
7). Trojan+H2C+TLS
8). Trojan+gRPC+TLS
9). Trojan+HTTPUpgrade+TLS
请选择 [1-9]: " setup_type
        case $setup_type in
            "" | 1)
                tls_enabled=false
                break
                ;;
            2)
                transport_ws=true
                tls_enabled=false
                break
                ;;
            3)
                transport_grpc=true
                tls_enabled=false
                break
                ;;
            4)
                transport_httpupgrade=true
                tls_enabled=false
                break
                ;;
            5)
                tls_enabled=true
                break
                ;;
            6)
                transport_ws=true
                tls_enabled=true
                break
                ;;
            7)
                transport_http=true
                tls_enabled=true
                break
                ;;
            8)
                transport_grpc=true
                tls_enabled=true
                break
                ;;
            9)
                transport_httpupgrade=true
                tls_enabled=true
                break
                ;;
            *)
                echo -e "${RED}无效的选择，请重新输入！${NC}"
                ;;
        esac
    done
}

function set_short_id() {
    while true; do
        read -p "请输入 Short_Id (用于区分不同的客户端，默认随机生成): " short_id
        if [[ -z "$short_id" ]]; then
            short_id=$(openssl rand -hex 8)
            echo "Short_Id：$short_id"
            break
        elif [[ "$short_id" =~ ^[0-9a-fA-F]{2,16}$ ]]; then
            echo "Short_Id：$short_id"
            break
        else
            echo "错误：请输入两到八位的十六进制字符串！"
        fi
    done
    short_ids+=("$short_id")
}

function set_short_ids() {
    while true; do
        set_short_id
        for ((i=0; i<${#short_ids[@]}; i++)); do
            short_id="${short_ids[$i]}"
        done      
        read -p "是否继续添加 short id？(Y/N，默认N): " -e choice
        if [[ -z "$choice" ]]; then
            choice="N"
        fi
        if [[ "$choice" == "N" || "$choice" == "n" ]]; then
            short_Ids+="\n            \"$short_id\""
            break
        elif [[ "$choice" == "Y" || "$choice" == "y" ]]; then
            short_Ids+="\n            \"$short_id\","
            continue
        else
            echo -e "${RED}无效的输入，请重新输入！${NC}"
        fi
    done
}

function tuic_multiple_users() {
    while true; do
        set_user_name
        set_user_password
        set_uuid
        for ((i=0; i<${#user_names[@]}; i++)); do
            user_name="${user_names[$i]}"
            user_uuid="${user_uuids[$i]}"
            user_password="${user_passwords[$i]}"
        done
        read -p "是否继续添加用户？(Y/N，默认N): " -e add_multiple_users
        if [[ -z "$add_multiple_users" ]]; then
            add_multiple_users="N"
        fi
        if [[ "$add_multiple_users" == "N" || "$add_multiple_users" == "n" ]]; then
            users+="\n        {\n          \"name\": \"$user_name\",\n          \"uuid\": \"$user_uuid\",\n          \"password\": \"$user_password\"\n        }"
            break
        elif [[ "$add_multiple_users" == "Y" || "$add_multiple_users" == "y" ]]; then
            users+="\n        {\n          \"name\": \"$user_name\",\n          \"uuid\": \"$user_uuid\",\n          \"password\": \"$user_password\"\n        },"
            continue
        else
            echo -e "${RED}无效的输入，请重新输入！${NC}"
        fi
    done
}

function vmess_multiple_users() {
    while true; do
        set_uuid
        for ((i=0; i<${#user_uuids[@]}; i++)); do
            user_uuid="${user_uuids[$i]}"
        done
        read -p "是否继续添加用户？(Y/N，默认N): " -e add_multiple_users
        if [[ -z "$add_multiple_users" ]]; then
            add_multiple_users="N"
        fi
        if [[ "$add_multiple_users" == "N" || "$add_multiple_users" == "n" ]]; then
            users+="\n        {\n          \"uuid\": \"$user_uuid\",\n          \"alterId\": 0\n        }"
            break
        elif [[ "$add_multiple_users" == "Y" || "$add_multiple_users" == "y" ]]; then
            users+="\n        {\n          \"uuid\": \"$user_uuid\",\n          \"alterId\": 0\n        },"
            continue
        else
            echo -e "${RED}无效的输入，请重新输入！${NC}"
        fi
    done
}

function vless_multiple_users() {
    while true; do
        set_uuid
        for ((i=0; i<${#user_uuids[@]}; i++)); do
            user_uuid="${user_uuids[$i]}"
        done
        read -p "是否继续添加用户？(Y/N，默认N): " -e add_multiple_users
        if [[ -z "$add_multiple_users" ]]; then
            add_multiple_users="N"
        fi
        if [[ "$add_multiple_users" == "N" || "$add_multiple_users" == "n" ]]; then
            users+="\n        {\n          \"uuid\": \"$user_uuid\",\n          \"flow\": \"$flow_type\"\n        }"
            break
        elif [[ "$add_multiple_users" == "Y" || "$add_multiple_users" == "y" ]]; then
            users+="\n        {\n          \"uuid\": \"$user_uuid\",\n          \"flow\": \"$flow_type\"\n        },"
            continue
        else
            echo -e "${RED}无效的输入，请重新输入！${NC}"
        fi
    done
}

function socks_naive_multiple_users() {    
    while true; do
        set_user_name
        set_user_password
        for ((i=0; i<${#user_names[@]}; i++)); do
            user_name="${user_names[$i]}"
            user_password="${user_passwords[$i]}"
        done
        read -p "是否继续添加用户？(Y/N，默认N): " -e add_multiple_users
        if [[ -z "$add_multiple_users" ]]; then
            add_multiple_users="N"
        fi
        if [[ "$add_multiple_users" == "N" || "$add_multiple_users" == "n" ]]; then
            users+="\n        {\n          \"username\": \"$user_name\",\n          \"password\": \"$user_password\"\n        }"
            break
        elif [[ "$add_multiple_users" == "Y" || "$add_multiple_users" == "y" ]]; then
            users+="\n        {\n          \"username\": \"$user_name\",\n          \"password\": \"$user_password\"\n        },"
            continue
        else
            echo -e "${RED}无效的输入，请重新输入！${NC}"
        fi
    done
}

function hysteria_multiple_users() {
    while true; do
        set_user_name
        set_user_password
        for ((i=0; i<${#user_names[@]}; i++)); do
            user_name="${user_names[$i]}"
            user_password="${user_passwords[$i]}"
        done
        read -p "是否继续添加用户？(Y/N，默认N): " -e add_multiple_users

        if [[ -z "$add_multiple_users" ]]; then
            add_multiple_users="N"
        fi
        if [[ "$add_multiple_users" == "N" || "$add_multiple_users" == "n" ]]; then
            users+="\n        {\n          \"name\": \"$user_name\",\n          \"auth_str\": \"$user_password\"\n        }"
            break
        elif [[ "$add_multiple_users" == "Y" || "$add_multiple_users" == "y" ]]; then
            users+="\n        {\n          \"name\": \"$user_name\",\n          \"auth_str\": \"$user_password\"\n        },"
            continue
        else
            echo -e "${RED}无效的输入，请重新输入！${NC}"
        fi
    done
}

function hy2_multiple_users() {
    while true; do
        set_user_name
        set_user_password
        for ((i=0; i<${#user_names[@]}; i++)); do
            user_name="${user_names[$i]}"
            user_password="${user_passwords[$i]}"
        done
        read -p "是否继续添加用户？(Y/N，默认N): " -e add_multiple_users
        if [[ -z "$add_multiple_users" ]]; then
            add_multiple_users="N"
        fi
        if [[ "$add_multiple_users" == "N" || "$add_multiple_users" == "n" ]]; then
            users+="\n        {\n          \"name\": \"$user_name\",\n          \"password\": \"$user_password\"\n        }"
            break
        elif [[ "$add_multiple_users" == "Y" || "$add_multiple_users" == "y" ]]; then
            users+="\n        {\n          \"name\": \"$user_name\",\n          \"password\": \"$user_password\"\n        },"
            continue
        else
            echo -e "${RED}无效的输入，请重新输入！${NC}"
        fi
    done
}

function trojan_multiple_users() {
    while true; do
        set_user_password
        for ((i=0; i<${#user_passwords[@]}; i++)); do
            user_password="${user_passwords[$i]}"
        done
        read -p "是否继续添加用户？(Y/N，默认N): " -e add_multiple_users
        if [[ -z "$add_multiple_users" ]]; then
            add_multiple_users="N"
        fi
        if [[ "$add_multiple_users" == "N" || "$add_multiple_users" == "n" ]]; then
            users+="\n        {\n          \"password\": \"$user_password\"\n        }"
            break
        elif [[ "$add_multiple_users" == "Y" || "$add_multiple_users" == "y" ]]; then
            users+="\n        {\n          \"password\": \"$user_password\"\n        },"
            continue
        else
            echo -e "${RED}无效的输入，请重新输入！${NC}"
        fi
    done
}

function shadowtls_multiple_users() {
    while true; do
        set_user_name
        set_stls_password
        for ((i=0; i<${#user_names[@]}; i++)); do
            user_name="${user_names[$i]}"
            stls_password="${stls_passwords[$i]}"
        done
        read -p "是否继续添加用户？(Y/N，默认N): " -e add_multiple_users
        if [[ -z "$add_multiple_users" ]]; then
            add_multiple_users="N"
        fi
        if [[ "$add_multiple_users" == "N" || "$add_multiple_users" == "n" ]]; then
            users+="\n        {\n          \"name\": \"$user_name\",\n          \"password\": \"$stls_password\"\n        }"
            break
        elif [[ "$add_multiple_users" == "Y" || "$add_multiple_users" == "y" ]]; then
            users+="\n        {\n          \"name\": \"$user_name\",\n          \"password\": \"$stls_password\"\n        },"
            continue
        else
            echo -e "${RED}无效的输入，请重新输入！${NC}"
        fi
    done
}

function generate_transport_config() {    
    if [[ "$transport_ws" = true ]]; then
        read -p "请输入 ws 路径 (默认随机生成): " transport_path_input
        transport_path=${transport_path_input:-/$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 8)}
        if [[ ! "$transport_path" =~ ^/ ]]; then
            transport_path="/$transport_path"
        fi
        transport_config="\n      \"transport\": {\n        \"type\": \"ws\",\n        \"path\": \"$transport_path\",\n        \"max_early_data\": 2048,\n        \"early_data_header_name\": \"Sec-WebSocket-Protocol\"\n      },"
    elif [[ "$transport_httpupgrade" = true ]]; then
        transport_path=${transport_path_input:-/$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 8)}
        if [[ ! "$transport_path" =~ ^/ ]]; then
            transport_path="/$transport_path"
        fi
        transport_config="\n      \"transport\": {\n        \"type\": \"httpupgrade\",\n        \"path\": \"$transport_path\"\n      },"
    elif [[ "$transport_grpc" = true ]]; then
        service_name=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 8)
        transport_config="\n      \"transport\": {\n        \"type\": \"grpc\",\n        \"service_name\": \"$service_name\"\n      },"
    elif [[ "$transport_http" = true ]]; then
        transport_config="\n      \"transport\": {\n        \"type\": \"http\"\n      },"
    else
        transport_config=""    
    fi
}

function generate_tls_config() {
    if [[ "$tls_enabled" = true ]]; then
        set_ech_config
        select_certificate_option
    fi
    if [ -z "$domain_name" ]; then
        if [ -n "$domain" ]; then
            server_name="$domain"
        fi
    else
        server_name="$domain_name"
    fi
    
    if [[ "$tls_enabled" = true ]]; then
        tls_config=",\n      \"tls\": {\n        \"enabled\": true,\n        \"server_name\": \"$server_name\",\n        \"certificate_path\": \"$certificate_path\",\n        \"key_path\": \"$private_key_path\"$ech_server_config\n      }"
    fi
}

function set_ech_config() {
    while true; do
        read -p "是否开启 ECH?(Y/N，默认Y):" enable_ech
        enable_ech="${enable_ech:-Y}"
        if [[ "$enable_ech" == "y" || "$enable_ech" == "Y" ]]; then
            get_ech_keys
            enable_ech=true
            ech_server_config=",\n        \"ech\": {\n          \"enabled\": true,\n          \"pq_signature_schemes_enabled\": true,\n          \"dynamic_record_sizing_disabled\": false,\n          \"key\": [\n$ech_key\n          ]\n        }"
            break
        elif [[ "$enable_ech" == "n" || "$enable_ech" == "N" ]]; then
            enable_ech=false
            ech_server_config=""
            break
        else
            echo -e "${RED}无效的输入，请重新输入！${NC}"
        fi
    done
}
      
function generate_reality_config() {
    if [[ "$reality_enabled" = true ]]; then
        set_server_name
        set_target_server
        generate_private_key
        set_short_ids
        reality_config=",\n      \"tls\": {\n        \"enabled\": true,\n        \"server_name\": \"$server_name\",\n        \"reality\": {\n          \"enabled\": true,\n          \"handshake\": {\n            \"server\": \"$target_server\",\n            \"server_port\": 443\n          },\n          \"private_key\": \"$private_key\",\n          \"short_id\": [$short_Ids\n          ]\n        }\n      }"
    fi
}

function configure_quic_obfuscation() {
    while true; do
        read -p "是否开启QUIC流量混淆（如果你的网络屏蔽了 QUIC 或 HTTP/3 流量，请选择开启）？(Y/N，默认为N): " choice
        choice="${choice:-N}"
        if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
            read -p "请输入混淆密码（默认随机生成）: " new_obfs_password
            if [[ -z "$new_obfs_password" ]]; then
                new_obfs_password=$(sing-box generate rand --base64 9 2>/dev/null || openssl rand -base64 9)
            fi
            obfs_config="\n      \"obfs\": {\n        \"type\": \"salamander\",\n        \"password\": \"$new_obfs_password\"\n      },"
            obfs_password="$new_obfs_password"
            echo "混淆密码：$obfs_password"
            break
        elif [[ "$choice" == "n" || "$choice" == "N" ]]; then
            obfs_config=""
            break
        else
            echo -e "${RED}无效的输入，请重新输入！${NC}"
        fi
    done
}

function configure_obfuscation() {
    while true; do
        read -p "是否开启 obfs 混淆（用来绕过针对性的 DPI 屏蔽或者 QoS）？(Y/N，默认为N): " choice
        choice="${choice:-N}"
        if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
            read -p "请输入混淆密码（默认随机生成）: " new_obfs_password
            if [[ -z "$new_obfs_password" ]]; then
                new_obfs_password=$(sing-box generate rand --base64 9 2>/dev/null || openssl rand -base64 9)
            fi
            obfs_config="\n      \"obfs\": \"$new_obfs_password\","
            obfs_password="$new_obfs_password"
            echo "混淆密码：$obfs_password"
            break
        elif [[ "$choice" == "n" || "$choice" == "N" ]]; then
            obfs_config=""
            break
        else
            echo -e "${RED}无效的输入，请重新输入！${NC}"
        fi
    done
}

function configure_multiplex() {
    while true; do
        read -p "是否开启多路复用？(Y/N，默认为Y): " choice
        choice="${choice:-Y}"
        if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
            configure_brutal
            multiplex_config=",\n      \"multiplex\": {\n        \"enabled\": true,\n        \"padding\": false$brutal_config\n      }"
            break
        elif [[ "$choice" == "n" || "$choice" == "N" ]]; then
            multiplex_config=""
            break
        else
            echo -e "${RED}无效的输入，请重新输入！${NC}"
        fi
    done
}

function configure_brutal() {
    while true; do
        read -p "是否开启 TCP Brutal？(Y/N，默认为N): " choice
        choice="${choice:-N}"
        if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
            set_up_speed
            set_down_speed
            brutal_config=",\n        \"brutal\": {\n          \"enabled\": true,\n          \"up_mbps\": $up_mbps,\n          \"down_mbps\": $down_mbps\n        }"
            break
        elif [[ "$choice" == "n" || "$choice" == "N" ]]; then
            brutal_config=""
            break
        else
            echo -e "${RED}无效的输入，请重新输入！${NC}"
        fi
    done
}

function extract_tls_info() {
    local config_file="/usr/local/etc/sing-box/config.json"
    local tls_info_file="/usr/local/etc/sing-box/tls_info.json"
    jq '.inbounds[].tls | select(.server_name and .certificate_path and .key_path) | {server_name: .server_name, certificate_path: .certificate_path, key_path: .key_path}' "$config_file" | jq -s 'unique' > "$tls_info_file"
}

function validate_tls_info() {
    local tls_info_file="/usr/local/etc/sing-box/tls_info.json"
    local temp_tls_file="/usr/local/etc/sing-box/temp_tls_info.json"
    server_names=($(jq -r '.[].server_name' "$tls_info_file"))
    for server_name in "${server_names[@]}"; do
        local resolved_ipv4=$(dig +short A "$server_name" 2>/dev/null)
        local resolved_ipv6=$(dig +short AAAA "$server_name" 2>/dev/null)
        if [[ (-n "$resolved_ipv4" && "$resolved_ipv4" == "$ip_v4") || (-n "$resolved_ipv6" && "$resolved_ipv6" == "$ip_v6") ]]; then
            continue
        else
            jq 'map(select(.server_name != "'"$server_name"'"))' "$tls_info_file" > "$temp_tls_file"
            mv "$temp_tls_file" "$tls_info_file"
        fi
    done
}

function modify_route_rules() {
    local config_file="/usr/local/etc/sing-box/config.json"
    local temp_config_file="/usr/local/etc/sing-box/temp_config.json"
    if jq -e '.route.rules[] | select(.geosite != null)' "$config_file" >/dev/null; then
        jq '(.route.rules |= [.[] | select(.geosite != null)] + [.[] | select(.geosite == null)])' "$config_file" > "$temp_config_file"
        mv "$temp_config_file" "$config_file"
    fi
}

function extract_variables_and_cleanup() {
    server=$(jq -r '.server' "$temp_file")
    server_port=$(jq -r '.server_port' "$temp_file")
    local_address_ipv4=$(jq -r '.local_address[0]' "$temp_file")
    local_address_ipv6=$(jq -r '.local_address[1]' "$temp_file")
    private_key=$(jq -r '.private_key' "$temp_file")
    peer_public_key=$(jq -r '.peer_public_key' "$temp_file")
    reserved=$(jq -c '.reserved' "$temp_file")
    mtu=$(jq -r '.mtu' "$temp_file")
    rm "$temp_file"
}

function log_outbound_config() {
  local config_file="/usr/local/etc/sing-box/config.json"
  if ! grep -q '"log": {' "$config_file" || ! grep -q '"route": {' "$config_file"  || ! grep -q '"inbounds": \[' "$config_file" || ! grep -q '"outbounds": \[' "$config_file"; then
    echo -e '{\n  "log": {\n  },\n  "route": {\n  },\n  "inbounds": [\n  ],\n  "outbounds": [\n  ]\n}' > "$config_file"
    sed -i '/"log": {/!b;n;c\    "disabled": false,\n    "level": "info",\n    "timestamp": true\n  },' "$config_file"
    sed -i '/"route": {/!b;n;c\    "rules": [\n    ]\n  },' "$config_file"
    sed -i '/"outbounds": \[/!b;n;c\    {\n      "type": "direct",\n      "tag": "direct"\n    }\n  ]' "$config_file"
  fi
}

function modify_format_inbounds_and_outbounds() {
    file_path="/usr/local/etc/sing-box/config.json"
    start_line_inbounds=$(grep -n '"inbounds": \[' "$file_path" | cut -d: -f1)
    start_line_outbounds=$(grep -n '"outbounds": \[' "$file_path" | cut -d: -f1)
    if [ -n "$start_line_inbounds" ]; then
        line_to_modify_inbounds=$((start_line_inbounds - 3))
        if [ "$line_to_modify_inbounds" -ge 1 ]; then
            sed -i "$line_to_modify_inbounds s/,//" "$file_path"
        fi
    fi
    if [ -n "$start_line_outbounds" ]; then
        line_to_modify_outbounds_1=$((start_line_outbounds - 2))
        line_to_modify_outbounds_2=$((start_line_outbounds - 1))
        if [ "$line_to_modify_outbounds_1" -ge 1 ]; then
            sed -i "$line_to_modify_outbounds_1 s/.*/    }/" "$file_path"
            sed -i "$line_to_modify_outbounds_2 s/.*/  ],/" "$file_path"
        fi
    fi
}

function generate_http_config() {
    local config_file="/usr/local/etc/sing-box/config.json"
    local cert_path="$certificate_path"
    local key_path="$private_key_path"
    tls_enabled=true
    local tag_label
    generate_unique_tag      
    set_listen_port
    socks_naive_multiple_users
    get_local_ip
    generate_tls_config
    local found_rules=0
    local found_inbounds=0
    awk -v tag_label="$tag_label" -v listen_port="$listen_port" -v users="$users" -v tls_config="$tls_config" '
        /"rules": \[/{found_rules=1}
        /"inbounds": \[/{found_inbounds=1}
        {print}
        found_rules && /"rules": \[/{print "      {"; print "        \"inbound\": [\"" tag_label "\"],"; print "        \"outbound\": \"direct\""; print "      },"; found_rules=0}
        found_inbounds && /"inbounds": \[/{print "    {"; print "      \"type\": \"http\","; print "      \"tag\": \"" tag_label "\","; print "      \"listen\": \"::\","; print "      \"listen_port\": " listen_port ","; print "      \"sniff\": true,"; print "      \"sniff_override_destination\": true,"; print "      \"set_system_proxy\": false,"; print "      \"users\": [" users ""; print "      ]" tls_config ""; print "    },"; found_inbounds=0}
    ' "$config_file" > "$config_file.tmp"
    mv "$config_file.tmp" "$config_file"
}

function generate_Direct_config() {
    local config_file="/usr/local/etc/sing-box/config.json"
    local tag_label
    generate_unique_tag
    local found_rules=0
    local found_inbounds=0
    awk -v tag_label="$tag_label" -v listen_port="$listen_port" -v target_address="$target_address" -v override_port="$override_port" '
        /"rules": \[/{found_rules=1}
        /"inbounds": \[/{found_inbounds=1}
        {print}
        found_rules && /"rules": \[/{print "      {"; print "        \"inbound\": [\"" tag_label "\"],"; print "        \"outbound\": \"direct\""; print "      },"; found_rules=0}
        found_inbounds && /"inbounds": \[/{print "    {"; print "      \"type\": \"direct\","; print "      \"tag\": \"" tag_label "\","; print "      \"listen\": \"::\","; print "      \"listen_port\": " listen_port ","; print "      \"sniff\": true,"; print "      \"sniff_override_destination\": true,"; print "      \"sniff_timeout\": \"300ms\","; print "      \"proxy_protocol\": false,"; print "      \"override_address\": \"" target_address "\","; print "      \"override_port\": " override_port; print "    },"; found_inbounds=0}
    ' "$config_file" > "$config_file.tmp"
    mv "$config_file.tmp" "$config_file"
}

function generate_ss_config() {
    local config_file="/usr/local/etc/sing-box/config.json"
    local tag_label
    generate_unique_tag
    configure_multiplex
    local found_rules=0
    local found_inbounds=0
    awk -v tag_label="$tag_label" -v listen_port="$listen_port" -v ss_method="$ss_method" -v ss_password="$ss_password" -v multiplex_config="$multiplex_config" '
        /"rules": \[/{found_rules=1}
        /"inbounds": \[/{found_inbounds=1}
        {print}
        found_rules && /"rules": \[/{print "      {"; print "        \"inbound\": [\"" tag_label "\"],"; print "        \"outbound\": \"direct\""; print "      },"; found_rules=0}
        found_inbounds && /"inbounds": \[/{print "    {"; print "      \"type\": \"shadowsocks\","; print "      \"tag\": \"" tag_label "\","; print "      \"listen\": \"::\","; print "      \"listen_port\": " listen_port ","; print "      \"sniff\": true,"; print "      \"sniff_override_destination\": true,"; print "      \"method\": \"" ss_method "\","; print "      \"password\": \"" ss_password "\"" multiplex_config ""; print "    },"; found_inbounds=0}
    ' "$config_file" > "$config_file.tmp"
    mv "$config_file.tmp" "$config_file"
}

function generate_vmess_config() {
    local config_file="/usr/local/etc/sing-box/config.json"
    local cert_path="$certificate_path"
    local key_path="$private_key_path"         
    local tag_label
    generate_unique_tag
    select_vmess_type 
    set_listen_port  
    vmess_multiple_users     
    generate_transport_config
    if [ "$transport_grpc" != true ] && [ "$transport_http" != true ]; then
        configure_multiplex
    fi
    get_local_ip
    generate_tls_config
    check_firewall_configuration
    local found_rules=0
    local found_inbounds=0
    awk -v tag_label="$tag_label" -v listen_port="$listen_port" -v users="$users" -v transport_config="$transport_config" -v tls_config="$tls_config" -v multiplex_config="$multiplex_config" '
        /"rules": \[/{found_rules=1}
        /"inbounds": \[/{found_inbounds=1}
        {print}
        found_rules && /"rules": \[/{print "      {"; print "        \"inbound\": [\"" tag_label "\"],"; print "        \"outbound\": \"direct\""; print "      },"; found_rules=0}
        found_inbounds && /"inbounds": \[/{print "    {"; print "      \"type\": \"vmess\","; print "      \"tag\": \"" tag_label "\","; print "      \"listen\": \"::\","; print "      \"listen_port\": " listen_port ","; print "      \"sniff\": true,"; print "      \"sniff_override_destination\": true," transport_config ""; print "      \"users\": [" users ""; print "      ]" tls_config "" multiplex_config ""; print "    },"; found=0}
    ' "$config_file" > "$config_file.tmp"
    mv "$config_file.tmp" "$config_file"
} 

function generate_socks_config() {
    local config_file="/usr/local/etc/sing-box/config.json"
    local tag_label
    generate_unique_tag
    set_listen_port   
    socks_naive_multiple_users 
    local found_rules=0
    local found_inbounds=0
    awk -v tag_label="$tag_label" -v listen_port="$listen_port" -v users="$users" '
        /"rules": \[/{found_rules=1}
        /"inbounds": \[/{found_inbounds=1}
        {print}
        found_rules && /"rules": \[/{print "      {"; print "        \"inbound\": [\"" tag_label "\"],"; print "        \"outbound\": \"direct\""; print "      },"; found_rules=0}
        found_inbounds && /"inbounds": \[/{print "    {"; print "      \"type\": \"socks\","; print "      \"tag\": \"" tag_label "\","; print "      \"listen\": \"::\","; print "      \"listen_port\": " listen_port ","; print "      \"sniff\": true,"; print "      \"sniff_override_destination\": true,"; print "      \"users\": [" users ""; print "      ]"; print "    },"; found_inbounds=0}
    ' "$config_file" > "$config_file.tmp"
    mv "$config_file.tmp" "$config_file"
}

function generate_naive_config() {
    local config_file="/usr/local/etc/sing-box/config.json"
    disable_option=true
    local tag_label
    generate_unique_tag      
    set_listen_port  
    socks_naive_multiple_users
    get_local_ip
    select_certificate_option
    local cert_path="$certificate_path"
    local key_path="$private_key_path"  
    local found_rules=0
    local found_inbounds=0
    awk -v tag_label="$tag_label" -v listen_port="$listen_port" -v users="$users" -v domain="$domain" -v certificate_path="$certificate_path" -v private_key_path="$private_key_path" '
        /"rules": \[/{found_rules=1}
        /"inbounds": \[/{found_inbounds=1}
        {print}
        found_rules && /"rules": \[/{print "      {"; print "        \"inbound\": [\"" tag_label "\"],"; print "        \"outbound\": \"direct\""; print "      },"; found_rules=0}
        found_inbounds && /"inbounds": \[/{print "    {"; print "      \"type\": \"naive\","; print "      \"tag\": \"" tag_label "\","; print "      \"listen\": \"::\","; print "      \"listen_port\": " listen_port ","; print "      \"sniff\": true,"; print "      \"sniff_override_destination\": true,"; print "      \"users\": [" users ""; print "      ],"; print "      \"tls\": {"; print "        \"enabled\": true,"; print "        \"server_name\": \"" domain "\","; print "        \"certificate_path\": \"" certificate_path "\","; print "        \"key_path\": \"" private_key_path "\""; print "      }"; print "    },"; found_inbounds=0}
    ' "$config_file" > "$config_file.tmp"
    mv "$config_file.tmp" "$config_file"
}

function generate_tuic_config() {
    local config_file="/usr/local/etc/sing-box/config.json"
    local tag_label
    generate_unique_tag  
    set_listen_port
    tuic_multiple_users    
    select_congestion_control
    get_local_ip
    set_ech_config
    select_certificate_option
    local cert_path="$certificate_path"
    local key_path="$private_key_path"   
    local found_rules=0
    local found_inbounds=0
    local server_name="$domain"
    if [ -z "$domain" ]; then
        server_name="$domain_name"
    fi
    awk -v tag_label="$tag_label" -v listen_port="$listen_port" -v users="$users" -v congestion_control="$congestion_control" -v server_name="$server_name" -v certificate_path="$certificate_path" -v private_key_path="$private_key_path" -v ech_server_config="$ech_server_config" '
        /"rules": \[/{found_rules=1}
        /"inbounds": \[/{found_inbounds=1}
        {print}
        found_rules && /"rules": \[/{print "      {"; print "        \"inbound\": [\"" tag_label "\"],"; print "        \"outbound\": \"direct\""; print "      },"; found_rules=0}
        found_inbounds && /"inbounds": \[/{print "    {"; print "      \"type\": \"tuic\","; print "      \"tag\": \"" tag_label "\","; print "      \"listen\": \"::\","; print "      \"listen_port\": " listen_port ","; print "      \"sniff\": true,"; print "      \"sniff_override_destination\": true,"; print "      \"users\": [" users ""; print "      ],"; print "      \"congestion_control\": \"" congestion_control "\","; print "      \"auth_timeout\": \"3s\","; print "      \"zero_rtt_handshake\": false,"; print "      \"heartbeat\": \"10s\","; print "      \"tls\": {"; print "        \"enabled\": true,"; print "        \"server_name\": \"" server_name "\","; print "        \"alpn\": ["; print "          \"h3\""; print "        ],"; print "        \"certificate_path\": \"" certificate_path "\","; print "        \"key_path\": \"" private_key_path "\"" ech_server_config ""; print "      }"; print "    },"; found_inbounds=0}
    ' "$config_file" > "$config_file.tmp"
    mv "$config_file.tmp" "$config_file"
}

function generate_Hysteria_config() {
    local config_file="/usr/local/etc/sing-box/config.json"
    local tag_label
    generate_unique_tag    
    set_listen_port
    set_up_speed
    set_down_speed    
    hysteria_multiple_users
    configure_obfuscation 
    get_local_ip
    set_ech_config
    select_certificate_option
    local cert_path="$certificate_path"
    local key_path="$private_key_path"
    local found_rules=0
    local found_inbounds=0
    local server_name="$domain"
    if [ -z "$domain" ]; then
        server_name="$domain_name"
    fi
    awk -v tag_label="$tag_label" -v listen_port="$listen_port" -v up_mbps="$up_mbps" -v down_mbps="$down_mbps" -v obfs_config="$obfs_config" -v users="$users" -v server_name="$server_name" -v certificate_path="$certificate_path" -v private_key_path="$private_key_path" -v ech_server_config="$ech_server_config" '
        /"rules": \[/{found_rules=1}
        /"inbounds": \[/{found_inbounds=1}
        {print}
        found_rules && /"rules": \[/{print "      {"; print "        \"inbound\": [\"" tag_label "\"],"; print "        \"outbound\": \"direct\""; print "      },"; found_rules=0}
        found_inbounds && /"inbounds": \[/{print "    {"; print "      \"type\": \"hysteria\","; print "      \"tag\": \"" tag_label "\","; print "      \"listen\": \"::\","; print "      \"listen_port\": " listen_port ","; print "      \"sniff\": true,"; print "      \"sniff_override_destination\": true,"; print "      \"up_mbps\": " up_mbps ","; print "      \"down_mbps\": " down_mbps ","obfs_config""; print "      \"users\": [" users ""; print "      ],"; print "      \"tls\": {"; print "        \"enabled\": true,"; print "        \"server_name\": \"" server_name "\","; print "        \"alpn\": ["; print "          \"h3\""; print "        ],"; print "        \"certificate_path\": \"" certificate_path "\","; print "        \"key_path\": \"" private_key_path "\"" ech_server_config ""; print "      }"; print "    },"; found_inbounds=0}
    ' "$config_file" > "$config_file.tmp"
    mv "$config_file.tmp" "$config_file"
}

function generate_shadowtls_config() {
    local config_file="/usr/local/etc/sing-box/config.json"
    local tag_label
    generate_unique_tag
    tag_label1="$tag_label" 
    generate_unique_tag
    tag_label2="$tag_label"  
    set_listen_port
    select_encryption_method
    shadowtls_multiple_users
    set_ss_password
    set_target_server
    configure_multiplex
    local found_rules=0
    local found_inbounds=0
    awk -v tag_label1="$tag_label1" -v tag_label2="$tag_label2" -v listen_port="$listen_port" -v users="$users" -v target_server="$target_server" -v ss_method="$ss_method" -v ss_password="$ss_password" -v multiplex_config="$multiplex_config" '
        /"rules": \[/{found_rules=1}
        /"inbounds": \[/{found_inbounds=1}
        {print}
        found_rules && /"rules": \[/{print "      {"; print "        \"inbound\": [\"" tag_label1 "\"],"; print "        \"outbound\": \"direct\""; print "      },"; found_rules=0}
        found_inbounds && /"inbounds": \[/{print "    {"; print "      \"type\": \"shadowtls\","; print "      \"tag\": \"" tag_label1 "\","; print "      \"listen\": \"::\","; print "      \"listen_port\": " listen_port ","; print "      \"sniff\": true,"; print "      \"sniff_override_destination\": true,"; print "      \"version\": 3,"; print "      \"users\": [" users ""; print "      ],"; print "      \"handshake\": {"; print "        \"server\": \"" target_server "\","; print "        \"server_port\": 443"; print "      },"; print "      \"strict_mode\": true,"; print "      \"detour\": \"" tag_label2 "\""; print "    },"; print "    {"; print "      \"type\": \"shadowsocks\","; print "      \"tag\": \"" tag_label2 "\","; print "      \"listen\": \"127.0.0.1\","; print "      \"method\": \"" ss_method "\","; print "      \"password\": \"" ss_password "\"" multiplex_config ""; print "    },"; found=0}
    ' "$config_file" > "$config_file.tmp"
    mv "$config_file.tmp" "$config_file"
}

function generate_juicity_config() {
    local config_file="/usr/local/etc/juicity/config.json"
    set_listen_port
    set_uuid
    set_user_password
    select_congestion_control
    get_local_ip
    select_certificate_option
    local cert_path="$certificate_path"
    local key_path="$private_key_path"
    awk -v listen_port="$listen_port" -v user_uuids="$user_uuids" -v user_passwords="$user_passwords" -v certificate_path="$certificate_path" -v private_key_path="$private_key_path" -v congestion_control="$congestion_control" 'BEGIN { print "{"; printf "  \"listen\": \":%s\",\n", listen_port; printf "  \"users\": {\n"; printf "    \"%s\": \"%s\"\n", user_uuids, user_passwords; printf "  },\n"; printf "  \"certificate\": \"%s\",\n", certificate_path; printf "  \"private_key\": \"%s\",\n", private_key_path; printf "  \"congestion_control\": \"%s\",\n", congestion_control; printf "  \"disable_outbound_udp443\": true,\n"; print "  \"log_level\": \"info\""; print "}"}' > "$config_file"
}

function generate_vless_config() {
    local config_file="/usr/local/etc/sing-box/config.json"
    local tag_label 
    generate_unique_tag    
    select_vless_type 
    set_listen_port
    vless_multiple_users
    generate_transport_config    
    generate_reality_config
    if [[ "$flow_type" != xtls-rprx-vision ]] && [[ "$transport_grpc" != true ]] && [[ "$transport_http" != true ]]; then
        configure_multiplex
    fi
    local found_rules=0
    local found_inbounds=0    
    awk -v tag_label="$tag_label" -v listen_port="$listen_port" -v users="$users" -v transport_config="$transport_config" -v reality_config="$reality_config" -v multiplex_config="$multiplex_config" '
        /"rules": \[/{found_rules=1}
        /"inbounds": \[/{found_inbounds=1}
        {print}
        found_rules && /"rules": \[/{print "      {"; print "        \"inbound\": [\"" tag_label "\"],"; print "        \"outbound\": \"direct\""; print "      },"; found_rules=0}
        found_inbounds && /"inbounds": \[/{print "    {"; print "      \"type\": \"vless\","; print "      \"tag\": \"" tag_label "\","; print "      \"listen\": \"::\","; print "      \"listen_port\": " listen_port ","; print "      \"sniff\": true,"; print "      \"sniff_override_destination\": true," transport_config ""; print "      \"users\": [" users ""; print "      ]"reality_config"" multiplex_config ""; print "    },"; found=0}
    ' "$config_file" > "$config_file.tmp"
    mv "$config_file.tmp" "$config_file"
}

function generate_Hy2_config() {
    local config_file="/usr/local/etc/sing-box/config.json"
    local tag_label
    generate_unique_tag      
    set_listen_port
    set_up_speed
    set_down_speed    
    hy2_multiple_users
    configure_quic_obfuscation
    set_fake_domain
    get_local_ip
    set_ech_config
    select_certificate_option
    local cert_path="$certificate_path"
    local key_path="$private_key_path"
    local found_rules=0
    local found_inbounds=0
    local server_name="$domain"
    if [ -z "$domain" ]; then
        server_name="$domain_name"
    fi
    awk -v tag_label="$tag_label" -v listen_port="$listen_port" -v up_mbps="$up_mbps" -v down_mbps="$down_mbps" -v obfs_config="$obfs_config" -v users="$users" -v fake_domain="$fake_domain" -v server_name="$server_name" -v certificate_path="$certificate_path" -v private_key_path="$private_key_path" -v ech_server_config="$ech_server_config" '
        /"rules": \[/{found_rules=1}
        /"inbounds": \[/{found_inbounds=1}
        {print}
        found_rules && /"rules": \[/{print "      {"; print "        \"inbound\": [\"" tag_label "\"],"; print "        \"outbound\": \"direct\""; print "      },"; found_rules=0}
        found_inbounds && /"inbounds": \[/{print "    {"; print "      \"type\": \"hysteria2\","; print "      \"tag\": \"" tag_label "\","; print "      \"listen\": \"::\","; print "      \"listen_port\": " listen_port ","; print "      \"sniff\": true,"; print "      \"sniff_override_destination\": true,"; print "      \"up_mbps\": " up_mbps ","; print "      \"down_mbps\": " down_mbps ","obfs_config""; print "      \"users\": [" users ""; print "      ],"; print "      \"ignore_client_bandwidth\": false,"; print "      \"masquerade\": \"https://" fake_domain "\","; print "      \"tls\": {"; print "        \"enabled\": true,"; print "        \"server_name\": \"" server_name "\","; print "        \"alpn\": ["; print "          \"h3\""; print "        ],"; print "        \"certificate_path\": \"" certificate_path "\","; print "        \"key_path\": \"" private_key_path "\"" ech_server_config ""; print "      }"; print "    },"; found=0}
    ' "$config_file" > "$config_file.tmp"
    mv "$config_file.tmp" "$config_file"
}

function generate_trojan_config() {
    local config_file="/usr/local/etc/sing-box/config.json"    
    local tag_label
    generate_unique_tag
    select_trojan_type  
    set_listen_port
    trojan_multiple_users
    generate_transport_config
    if [ "$transport_grpc" != true ] && [ "$transport_http" != true ]; then
        configure_multiplex
    fi
    get_local_ip
    generate_tls_config
    local cert_path="$certificate_path"
    local key_path="$private_key_path"
    check_firewall_configuration
    local found_rules=0
    local found_inbounds=0              
    awk -v tag_label="$tag_label" -v listen_port="$listen_port" -v users="$users" -v transport_config="$transport_config" -v tls_config="$tls_config" -v multiplex_config="$multiplex_config" '
        /"rules": \[/{found_rules=1}
        /"inbounds": \[/{found_inbounds=1}
        {print}
        found_rules && /"rules": \[/{print "      {"; print "        \"inbound\": [\"" tag_label "\"],"; print "        \"outbound\": \"direct\""; print "      },"; found_rules=0}
        found_inbounds && /"inbounds": \[/{print "    {"; print "      \"type\": \"trojan\","; print "      \"tag\": \"" tag_label "\","; print "      \"listen\": \"::\","; print "      \"listen_port\": " listen_port ","; print "      \"sniff\": true,"; print "      \"sniff_override_destination\": true," transport_config ""; print "      \"users\": [" users ""; print "      ]" tls_config "" multiplex_config ""; print "    },"; found=0}
    ' "$config_file" > "$config_file.tmp"
    mv "$config_file.tmp" "$config_file"
} 
  
function update_route_file() {
    local config_file="/usr/local/etc/sing-box/config.json"
    local geosite_list=$(IFS=,; echo "${geosite[*]}") 
    local geosite_formatted=$(sed 's/,/,\\n          /g' <<< "$geosite_list") 
    echo "正在配置 WireGuard..."
    sed -i '/"rules": \[/!b;a\
      {\
        "geosite": [\
          '"$geosite_formatted"'\
        ],\
        "outbound": "'"$1"'"\
      },' "$config_file"
}

function update_outbound_file() {
    local config_file="/usr/local/etc/sing-box/config.json"
    awk -v server="$server" -v server_port="$server_port" -v local_address_ipv4="$local_address_ipv4" -v local_address_ipv6="$local_address_ipv6" -v private_key="$private_key" -v peer_public_key="$peer_public_key" -v reserved="$reserved" -v mtu="$mtu" '
        {
            if ($0 ~ /"outbounds": \[/) {
                print $0
                for (i=1; i<=4; i++) {
                    getline
                    if (i == 4) {
                        print "" $0 ","
                    } else {
                        print $0
                    }
                }
                print "    {"; print "      \"type\": \"direct\","; print "      \"tag\": \"warp-IPv4-out\","; print "      \"detour\": \"wireguard-out\","; print "      \"domain_strategy\": \"ipv4_only\""; print "    },"; print "    {"; print "      \"type\": \"direct\","; print "      \"tag\": \"warp-IPv6-out\","; print "      \"detour\": \"wireguard-out\","; print "      \"domain_strategy\": \"ipv6_only\""; print "    },"; print "    {"; print "      \"type\": \"wireguard\","; print "      \"tag\": \"wireguard-out\","; print "      \"server\": \"" server "\","; print "      \"server_port\": " server_port ","; print "      \"system_interface\": false,"; print "      \"interface_name\": \"wg0\","; print "      \"local_address\": ["; print "        \"" local_address_ipv4 "\","; print "        \"" local_address_ipv6 "\"" ; print "      ],"; print "      \"private_key\": \"" private_key "\","; print "      \"peer_public_key\": \"" peer_public_key "\","; print "      \"reserved\": " reserved ","; print "      \"mtu\": " mtu; print "    }"
            } else {
                print $0
            }
        }
    ' "$config_file" > "$config_file.tmp"
    mv "$config_file.tmp" "$config_file"
    echo "WireGuard 配置完成。"
}

function write_phone_client_file() {
    local dir="/usr/local/etc/sing-box"
    local phone_client="${dir}/phone_client.json"
    if [ ! -s "${phone_client}" ]; then
        awk 'BEGIN { print "{"; print "  \"log\": {"; print "    \"disabled\": false,"; print "    \"level\": \"warn\","; print "    \"timestamp\": true"; print "  },"; print "  \"dns\": {"; print "    \"servers\": ["; print "      {"; print "        \"tag\": \"dns_proxy\","; print "        \"address\": \"https://dns.google/dns-query\","; print "        \"address_resolver\": \"dns_local\","; print "        \"detour\": \"select\""; print "      },"; print "      {"; print "        \"tag\": \"dns_direct\","; print "        \"address\": \"https://dns.alidns.com/dns-query\","; print "        \"address_resolver\": \"dns_local\","; print "        \"detour\": \"direct\""; print "      },"; print "      {"; print "        \"tag\": \"dns_block\","; print "        \"address\": \"rcode://success\""; print "      },"; print "      {"; print "        \"tag\": \"dns_fakeip\","; print "        \"address\": \"fakeip\""; print "      },"; print "      {"; print "        \"tag\": \"dns_local\","; print "        \"address\": \"223.5.5.5\","; print "        \"detour\": \"direct\""; print "      }"; print "    ],"; print "    \"rules\": ["; print "      {"; print "        \"outbound\": \"any\","; print "        \"server\": \"dns_local\""; print "      },"; print "      {"; print "        \"geosite\": ["; print "          \"category-ads-all\""; print "          ],"; print "        \"server\": \"dns_block\","; print "        \"disable_cache\": true"; print "      },"; print "      {"; print "        \"query_type\": ["; print "          \"A\","; print "          \"AAAA\""; print "        ],"; print "        \"server\": \"dns_fakeip\""; print "      },"; print "      {"; print "        \"clash_mode\": \"Direct\","; print "        \"server\": \"dns_direct\""; print "      },"; print "      {"; print "        \"clash_mode\": \"Global\","; print "        \"server\": \"dns_proxy\""; print "      },"; print "      {"; print "        \"type\": \"logical\","; print "        \"mode\": \"and\","; print "        \"rules\": ["; print "          {"; print "            \"geosite\": \"geolocation-!cn\","; print "            \"invert\": true"; print "          },"; print "          {"; print "            \"geosite\": ["; print "              \"cn\","; print "              \"category-companies@cn\""; print "            ]"; print "          }"; print "        ],"; print "        \"server\": \"dns_direct\""; print "      }"; print "    ],"; print "    \"final\": \"dns_proxy\","; print "    \"strategy\": \"ipv4_only\","; print "    \"independent_cache\": true,"; print "    \"fakeip\": {"; print "      \"enabled\": true,"; print "      \"inet4_range\": \"198.18.0.0/15\","; print "      \"inet6_range\": \"fc00::/18\""; print "    }"; print "  },"; print "  \"route\": {"; print "    \"geoip\": {"; print "      \"download_url\": \"https://github.com/SagerNet/sing-geoip/releases/latest/download/geoip.db\","; print "      \"download_detour\": \"select\""; print "    },"; print "    \"geosite\": {"; print "      \"download_url\": \"https://github.com/SagerNet/sing-geosite/releases/latest/download/geosite.db\","; print "      \"download_detour\": \"select\""; print "    },"; print "    \"rules\": ["; print "      {"; print "        \"protocol\": \"dns\","; print "        \"outbound\": \"dns-out\""; print "      },"; print "      {"; print "        \"geoip\": \"private\","; print "        \"outbound\": \"direct\""; print "      },"; print "      {"; print "        \"clash_mode\": \"Direct\","; print "        \"outbound\": \"direct\""; print "      },"; print "      {"; print "        \"clash_mode\": \"Global\","; print "        \"outbound\": \"select\""; print "      },"; print "      {"; print "        \"type\": \"logical\","; print "        \"mode\": \"and\","; print "        \"rules\": ["; print "          {"; print "            \"geosite\": \"geolocation-!cn\","; print "            \"invert\": true"; print "          },"; print "          {"; print "            \"geosite\": ["; print "              \"cn\","; print "              \"category-companies@cn\""; print "            ],"; print "            \"geoip\": \"cn\""; print "          }"; print "        ],"; print "        \"outbound\": \"direct\""; print "      }"; print "    ],"; print "    \"final\": \"select\","; print "    \"auto_detect_interface\": true"; print "  },"; print "  \"inbounds\": ["; print "    {"; print "      \"type\": \"tun\","; print "      \"tag\": \"tun-in\","; print "      \"inet4_address\": \"172.19.0.1/30\","; print "      \"inet6_address\": \"fdfe:dcba:9876::1/126\","; print "      \"auto_route\": true,"; print "      \"strict_route\": true,"; print "      \"stack\": \"mixed\","; print "      \"sniff\": true,"; print "      \"sniff_override_destination\": false"; print "    }"; print "  ],"; print "  \"outbounds\": ["; print "    {"; print "      \"type\": \"urltest\","; print "      \"tag\": \"auto\","; print "      \"outbounds\": ["; print "      ],"; print "      \"url\": \"https://www.gstatic.com/generate_204\","; print "      \"interval\": \"1m\","; print "      \"tolerance\": 50,"; print "      \"interrupt_exist_connections\": false"; print "    },"; print "    {"; print "      \"type\": \"selector\","; print "      \"tag\": \"select\","; print "      \"outbounds\": ["; print "        \"auto\""; print "      ],"; print "      \"default\": \"auto\","; print "      \"interrupt_exist_connections\": false"; print "    },"; print "    {"; print "      \"type\": \"direct\","; print "      \"tag\": \"direct\""; print "    },"; print "    {"; print "      \"type\": \"block\","; print "      \"tag\": \"block\""; print "    },"; print "    {"; print "      \"type\": \"dns\","; print "      \"tag\": \"dns-out\""; print "    }"; print "  ],"; print "  \"experimental\": {"; print "    \"clash_api\": {"; print "      \"external_controller\": \"127.0.0.1:9090\","; print "      \"external_ui\": \"ui\","; print "      \"external_ui_download_detour\": \"direct\","; print "      \"store_fakeip\": true"; print "    }"; print "  },"; print "  \"ntp\": {"; print "    \"enabled\": true,"; print "    \"server\": \"time.apple.com\","; print "    \"server_port\": 123,"; print "    \"interval\": \"30m\","; print "    \"detour\": \"direct\""; print "  }"; print "}" }' > "${phone_client}"
    fi    
}

function write_win_client_file() {
    local dir="/usr/local/etc/sing-box"
    local win_client="${dir}/win_client.json"
    if [ ! -s "${win_client}" ]; then
        awk 'BEGIN { print "{"; print "  \"log\": {"; print "    \"disabled\": false,"; print "    \"level\": \"warn\","; print "    \"timestamp\": true"; print "  },"; print "  \"dns\": {"; print "    \"servers\": ["; print "      {"; print "        \"tag\": \"dns_proxy\","; print "        \"address\": \"https://dns.google/dns-query\","; print "        \"address_resolver\": \"dns_local\","; print "        \"detour\": \"select\""; print "      },"; print "      {"; print "        \"tag\": \"dns_direct\","; print "        \"address\": \"https://dns.alidns.com/dns-query\","; print "        \"address_resolver\": \"dns_local\","; print "        \"detour\": \"direct\""; print "      },"; print "      {"; print "        \"tag\": \"dns_block\","; print "        \"address\": \"rcode://success\""; print "      },"; print "      {"; print "        \"tag\": \"dns_fakeip\","; print "        \"address\": \"fakeip\""; print "      },"; print "      {"; print "        \"tag\": \"dns_local\","; print "        \"address\": \"223.5.5.5\","; print "        \"detour\": \"direct\""; print "      }"; print "    ],"; print "    \"rules\": ["; print "      {"; print "        \"outbound\": \"any\","; print "        \"server\": \"dns_local\""; print "      },"; print "      {"; print "        \"geosite\": ["; print "          \"category-ads-all\""; print "          ],"; print "        \"server\": \"dns_block\","; print "        \"disable_cache\": true"; print "      },"; print "      {"; print "        \"query_type\": ["; print "          \"A\","; print "          \"AAAA\""; print "        ],"; print "        \"server\": \"dns_fakeip\""; print "      },"; print "      {"; print "        \"clash_mode\": \"Direct\","; print "        \"server\": \"dns_direct\""; print "      },"; print "      {"; print "        \"clash_mode\": \"Global\","; print "        \"server\": \"dns_proxy\""; print "      },"; print "      {"; print "        \"type\": \"logical\","; print "        \"mode\": \"and\","; print "        \"rules\": ["; print "          {"; print "            \"geosite\": \"geolocation-!cn\","; print "            \"invert\": true"; print "          },"; print "          {"; print "            \"geosite\": ["; print "              \"cn\","; print "              \"category-companies@cn\""; print "            ]"; print "          }"; print "        ],"; print "        \"server\": \"dns_direct\""; print "      }"; print "    ],"; print "    \"final\": \"dns_proxy\","; print "    \"strategy\": \"ipv4_only\","; print "    \"independent_cache\": true,"; print "    \"fakeip\": {"; print "      \"enabled\": true,"; print "      \"inet4_range\": \"198.18.0.0/15\","; print "      \"inet6_range\": \"fc00::/18\""; print "    }"; print "  },"; print "  \"route\": {"; print "    \"geoip\": {"; print "      \"download_url\": \"https://github.com/SagerNet/sing-geoip/releases/latest/download/geoip.db\","; print "      \"download_detour\": \"select\""; print "    },"; print "    \"geosite\": {"; print "      \"download_url\": \"https://github.com/SagerNet/sing-geosite/releases/latest/download/geosite.db\","; print "      \"download_detour\": \"select\""; print "    },"; print "    \"rules\": ["; print "      {"; print "        \"protocol\": \"dns\","; print "        \"outbound\": \"dns-out\""; print "      },"; print "      {"; print "        \"geoip\": \"private\","; print "        \"outbound\": \"direct\""; print "      },"; print "      {"; print "        \"clash_mode\": \"Direct\","; print "        \"outbound\": \"direct\""; print "      },"; print "      {"; print "        \"clash_mode\": \"Global\","; print "        \"outbound\": \"select\""; print "      },"; print "      {"; print "        \"type\": \"logical\","; print "        \"mode\": \"and\","; print "        \"rules\": ["; print "          {"; print "            \"geosite\": \"geolocation-!cn\","; print "            \"invert\": true"; print "          },"; print "          {"; print "            \"geosite\": ["; print "              \"cn\","; print "              \"category-companies@cn\""; print "            ],"; print "            \"geoip\": \"cn\""; print "          }"; print "        ],"; print "        \"outbound\": \"direct\""; print "      }"; print "    ],"; print "    \"final\": \"select\","; print "    \"auto_detect_interface\": true"; print "  },"; print "  \"inbounds\": ["; print "    {"; print "      \"type\": \"mixed\","; print "      \"tag\": \"mixed-in\","; print "      \"listen\": \"::\","; print "      \"listen_port\": 1080,"; print "      \"sniff\": true,"; print "      \"set_system_proxy\": false"; print "    }"; print "  ],"; print "  \"outbounds\": ["; print "    {"; print "      \"type\": \"urltest\","; print "      \"tag\": \"auto\","; print "      \"outbounds\": ["; print "      ],"; print "      \"url\": \"https://www.gstatic.com/generate_204\","; print "      \"interval\": \"1m\","; print "      \"tolerance\": 50,"; print "      \"interrupt_exist_connections\": false"; print "    },"; print "    {"; print "      \"type\": \"selector\","; print "      \"tag\": \"select\","; print "      \"outbounds\": ["; print "        \"auto\""; print "      ],"; print "      \"default\": \"auto\","; print "      \"interrupt_exist_connections\": false"; print "    },"; print "    {"; print "      \"type\": \"direct\","; print "      \"tag\": \"direct\""; print "    },"; print "    {"; print "      \"type\": \"block\","; print "      \"tag\": \"block\""; print "    },"; print "    {"; print "      \"type\": \"dns\","; print "      \"tag\": \"dns-out\""; print "    }"; print "  ],"; print "  \"experimental\": {"; print "    \"clash_api\": {"; print "      \"external_controller\": \"127.0.0.1:9090\","; print "      \"external_ui\": \"ui\","; print "      \"external_ui_download_detour\": \"direct\","; print "      \"store_fakeip\": true"; print "    }"; print "  },"; print "  \"ntp\": {"; print "    \"enabled\": true,"; print "    \"server\": \"time.apple.com\","; print "    \"server_port\": 123,"; print "    \"interval\": \"30m\","; print "    \"detour\": \"direct\""; print "  }"; print "}" }' > "${win_client}"
    fi    
}

function write_clash_yaml() {
    local dir="/usr/local/etc/sing-box"
    local clash_yaml="${dir}/clash.yaml"
    if [ ! -s "${clash_yaml}" ]; then
        awk 'BEGIN { print "mixed-port: 10801"; print "allow-lan: true"; print "bind-address: \"*\""; print "find-process-mode: strict"; print "mode: rule"; print "geodata-mode: true"; print "geox-url:"; print "  geoip: \"https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip.dat\""; print "  geosite: \"https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geosite.dat\""; print "  mmdb: \"https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/country.mmdb\""; print "log-level: info"; print "ipv6: true"; print "global-client-fingerprint: chrome"; print "tun:"; print "  enable: true"; print "  stack: system"; print "  dns-hijack:"; print "    - 0.0.0.0:53"; print "  auto-detect-interface: true"; print "  auto-route: true"; print "  mtu: 9000"; print "profile:"; print "  store-selected: false"; print "  store-fake-ip: true"; print "sniffer:"; print "  enable: true"; print "  override-destination: false"; print "  sniff:"; print "    TLS:"; print "      ports: [443, 8443]"; print "    HTTP:"; print "      ports: [80, 8080-8880]"; print "      override-destination: true"; print "dns:"; print "  enable: true"; print "  prefer-h3: true"; print "  listen: 0.0.0.0:53"; print "  ipv6: true"; print "  ipv6-timeout: 300"; print "  default-nameserver:"; print "    - 223.5.5.5"; print "  enhanced-mode: fake-ip"; print "  fake-ip-range: 198.18.0.1/16"; print "  nameserver:"; print "    - https://doh.pub/dns-query"; print "    - https://dns.alidns.com/dns-query"; print "  fallback:"; print "    - https://dns.google/dns-query"; print "    - https://1.1.1.1/dns-query"; print "  fallback-filter:"; print "    geoip: true"; print "    geoip-code: CN"; print "    geosite:"; print "      - gfw"; print "    ipcidr:"; print "      - 240.0.0.0/4"; print "    domain:"; print "      - \"+.google.com\""; print "      - \"+.facebook.com\""; print "      - \"+.youtube.com\""; print "  nameserver-policy:"; print "    \"geosite:cn,private\":"; print "      - https://doh.pub/dns-query"; print "      - https://dns.alidns.com/dns-query"; print "    \"geosite:category-ads-all\": rcode://success"; print "proxies:"; print "proxy-groups:"; print "  - name: Proxy"; print "    type: select"; print "    proxies:"; print "      - auto"; print "  - name: auto"; print "    type: url-test"; print "    proxies:"; print "    url: \"https://cp.cloudflare.com/generate_204\""; print "    interval: 300"; print "rules:"; print "  - GEOSITE,private,DIRECT"; print "  - GEOSITE,category-ads-all,REJECT"; print "  - GEOSITE,cn,DIRECT"; print "  - GEOIP,cn,DIRECT"; print "  - MATCH,Proxy"; }' > "${clash_yaml}"
        sed -i'' -e '/^      - "+\.google\.com"/s/"/'\''/g' "${clash_yaml}"
        sed -i'' -e '/^      - "+\.facebook\.com"/s/"/'\''/g' "${clash_yaml}"
        sed -i'' -e '/^      - "+\.youtube\.com"/s/"/'\''/g' "${clash_yaml}" 
    fi
}

function write_naive_client_file() {
    local naive_client_file="$naive_client_filename"
    awk -v naive_client_file="$naive_client_file" 'BEGIN { print "{"; print "  \"listen\":  \"socks://127.0.0.1:1080\","; print "  \"proxy\": \"https://user_name:user_password@server_name:listen_port\""; print "}" }' > "$naive_client_file"
}

function generate_shadowsocks_win_client_config() {
    local win_client_file="/usr/local/etc/sing-box/win_client.json"
    local proxy_name
    if [ -n "$multiplex_config" ] && [ -n "$brutal_config" ]; then
        multiplex_client_config=",\n      \"multiplex\": {\n        \"enabled\": true,\n        \"protocol\": \"h2mux\",\n        \"max_connections\": 1,\n        \"min_streams\": 4,\n        \"padding\": false,\n        \"brutal\": {\n          \"enabled\": true,\n          \"up_mbps\": $down_mbps,\n          \"down_mbps\": $up_mbps\n        }\n      }"
    elif [ -n "$multiplex_config" ] && [ -z "$brutal_config" ]; then
        multiplex_client_config=",\n      \"multiplex\": {\n        \"enabled\": true,\n        \"protocol\": \"h2mux\",\n        \"max_connections\": 1,\n        \"min_streams\": 4,\n        \"padding\": false\n      }"
    fi
    while true; do
        proxy_name="ss-$(head /dev/urandom | tr -dc '0-9' | head -c 4)"
        if ! grep -q "name: $proxy_name" "$win_client_file"; then
            break
        fi
    done
    awk -v proxy_name="$proxy_name" -v local_ip="$local_ip" -v listen_port="$listen_port" -v ss_method="$ss_method" -v ss_password="$ss_password" -v multiplex_client_config="$multiplex_client_config" '
    /^  "outbounds": \[/ {print; getline; print "    {"; print "      \"type\": \"shadowsocks\","; print "      \"tag\": \"" proxy_name "\","; print "      \"server\": \"" local_ip "\", "; print "      \"server_port\": " listen_port ","; print "      \"method\": \"" ss_method "\", "; print "      \"password\": \"" ss_password "\"" multiplex_client_config ""; print "    },";} 
    /^      "outbounds": \[/ {print; getline; if ($0 ~ /^      \],$/) {print "        \"" proxy_name "\""} else {print "        \"" proxy_name "\", "} }    
    {print}' "$win_client_file" > "$win_client_file.tmp"
    mv "$win_client_file.tmp" "$win_client_file"
}

function generate_shadowsocks_phone_client_config() {
    local phone_client_file="/usr/local/etc/sing-box/phone_client.json"
    local proxy_name
    if [ -n "$multiplex_config" ] && [ -n "$brutal_config" ]; then
        multiplex_client_config=",\n      \"multiplex\": {\n        \"enabled\": true,\n        \"protocol\": \"h2mux\",\n        \"max_connections\": 1,\n        \"min_streams\": 4,\n        \"padding\": false,\n        \"brutal\": {\n          \"enabled\": true,\n          \"up_mbps\": $down_mbps,\n          \"down_mbps\": $up_mbps\n        }\n      }"
    elif [ -n "$multiplex_config" ] && [ -z "$brutal_config" ]; then
        multiplex_client_config=",\n      \"multiplex\": {\n        \"enabled\": true,\n        \"protocol\": \"h2mux\",\n        \"max_connections\": 1,\n        \"min_streams\": 4,\n        \"padding\": false\n      }"
    fi
    while true; do
        proxy_name="ss-$(head /dev/urandom | tr -dc '0-9' | head -c 4)"
        if ! grep -q "name: $proxy_name" "$phone_client_file"; then
            break
        fi
    done 
    awk -v proxy_name="$proxy_name" -v local_ip="$local_ip" -v listen_port="$listen_port" -v ss_method="$ss_method" -v ss_password="$ss_password" -v multiplex_client_config="$multiplex_client_config" '
    /^  "outbounds": \[/ {print; getline; print "    {"; print "      \"type\": \"shadowsocks\","; print "      \"tag\": \"" proxy_name "\","; print "      \"server\": \"" local_ip "\", "; print "      \"server_port\": " listen_port ","; print "      \"method\": \"" ss_method "\", "; print "      \"password\": \"" ss_password "\"" multiplex_client_config ""; print "    },";} 
    /^      "outbounds": \[/ {print; getline; if ($0 ~ /^      \],$/) {print "        \"" proxy_name "\""} else {print "        \"" proxy_name "\", "} }    
    {print}' "$phone_client_file" > "$phone_client_file.tmp"
    mv "$phone_client_file.tmp" "$phone_client_file"
}

function generate_shadowsocks_yaml() {
    local filename="/usr/local/etc/sing-box/clash.yaml"
    local proxy_name
    while true; do
        proxy_name="ss-$(head /dev/urandom | tr -dc '0-9' | head -c 4)"
        if ! grep -q "name: $proxy_name" "$filename"; then
            break
        fi
    done
    awk -v proxy_name="$proxy_name" -v local_ip="$local_ip" -v listen_port="$listen_port" -v ss_method="$ss_method" -v ss_password="$ss_password" '/^proxies:$/ {print; print "  - name: " proxy_name; print "    type: ss"; print "    server:", local_ip; print "    port:", listen_port; print "    cipher:", ss_method; print "    password:", "\"" ss_password "\""; print ""; next} /- name: Proxy/ { print; flag_proxy=1; next } flag_proxy && flag_proxy++ == 3 { print "      - " proxy_name } /- name: auto/ { print; flag_auto=1; next } flag_auto && flag_auto++ == 3 { print "      - " proxy_name } 1' "$filename" > temp_file && mv temp_file "$filename"
}

function generate_juicity_win_client_config() {
    local client_file="/usr/local/etc/juicity/client.json"
    local server_name="$domain"
    local server_value
    local tls_insecure
    if [ -z "$domain" ]; then
        server_name="$domain_name"
        server_value="$local_ip"
        tls_insecure="true"
    else
        server_value="$domain"
        tls_insecure="false"
    fi
    awk -v listen_port="$listen_port" -v server_value="$server_value" -v user_uuids="$user_uuids" -v user_passwords="$user_passwords" -v server_name="$server_name" -v tls_insecure="$tls_insecure" -v congestion_control="$congestion_control" 'BEGIN { print "{"; printf "  \"listen\": \":%s\",\n", 1080; printf "  \"server\": \"%s:%s\",\n", server_value, listen_port; printf "  \"uuid\": \"%s\",\n", user_uuids; printf "  \"password\": \"%s\",\n", user_passwords; printf "  \"sni\": \"%s\",\n", server_name; printf "  \"allow_insecure\": %s,\n", tls_insecure; printf "  \"congestion_control\": \"%s\",\n", congestion_control; printf "  \"log_level\": \"info\"\n"; print "}"}' > "$client_file"
    echo "客户端配置文件已保存至$client_file，请下载后使用！"
}

function generate_tuic_phone_client_config() {
    local phone_client_file="/usr/local/etc/sing-box/phone_client.json"
    local server_name="$domain"
    local proxy_name
    local server_value
    local tls_insecure
    if [ -z "$domain" ]; then
        server_name="$domain_name"
        server_value="$local_ip"
        tls_insecure="true"
    else
        server_value="$domain"
        tls_insecure="false"
    fi
    if [ -n "$ech_config" ]; then
        ech_client_config=",\n        \"ech\": {\n          \"enabled\": true,\n          \"pq_signature_schemes_enabled\": true,\n          \"dynamic_record_sizing_disabled\": false,\n          \"config\": [\n$ech_config\n          ]\n        }"
    fi
    while true; do
        proxy_name="tuic-$(head /dev/urandom | tr -dc '0-9' | head -c 4)"
        if ! grep -q "name: $proxy_name" "$phone_client_file"; then
            break
        fi
    done
    awk -v proxy_name="$proxy_name" -v server_value="$server_value" -v server_name="$server_name" -v listen_port="$listen_port" -v user_uuid="$user_uuid" -v user_password="$user_password" -v congestion_control="$congestion_control" -v tls_insecure="$tls_insecure" -v ech_client_config="$ech_client_config" '
    /^  "outbounds": \[/ {print; getline; print "    {"; print "      \"type\": \"tuic\","; print "      \"tag\": \"" proxy_name "\","; print "      \"server\": \"" server_value "\", "; print "      \"server_port\": " listen_port ","; print "      \"uuid\": \"" user_uuid "\", "; print "      \"password\": \"" user_password "\", "; print "      \"congestion_control\": \""congestion_control"\","; print "      \"udp_relay_mode\": \"native\","; print "      \"zero_rtt_handshake\": false,"; print "      \"heartbeat\": \"10s\","; print "      \"tls\": {"; print "        \"enabled\": true,"; print "        \"insecure\": " tls_insecure ","; print "        \"server_name\": \"" server_name "\", "; print "        \"alpn\": ["; print "          \"h3\""; print "        ]" ech_client_config ""; print "      }"; print "    },";} 
    /^      "outbounds": \[/ {print; getline; if ($0 ~ /^      \],$/) {print "        \"" proxy_name "\""} else {print "        \"" proxy_name "\", "} }    
    {print}' "$phone_client_file" > "$phone_client_file.tmp"
    mv "$phone_client_file.tmp" "$phone_client_file"
}

function generate_tuic_win_client_config() {
    local win_client_file="/usr/local/etc/sing-box/win_client.json"
    local server_name="$domain"
    local proxy_name
    local server_value
    local tls_insecure
    if [ -z "$domain" ]; then
        server_name="$domain_name"
        server_value="$local_ip"
        tls_insecure="true"
    else
        server_value="$domain"
        tls_insecure="false"
    fi
    if [ -n "$ech_config" ]; then
        ech_client_config=",\n        \"ech\": {\n          \"enabled\": true,\n          \"pq_signature_schemes_enabled\": true,\n          \"dynamic_record_sizing_disabled\": false,\n          \"config\": [\n$ech_config\n          ]\n        }"
    fi
    while true; do
        proxy_name="tuic-$(head /dev/urandom | tr -dc '0-9' | head -c 4)"
        if ! grep -q "name: $proxy_name" "$win_client_file"; then
            break
        fi
    done
    awk -v proxy_name="$proxy_name" -v server_value="$server_value" -v server_name="$server_name" -v listen_port="$listen_port" -v user_uuid="$user_uuid" -v user_password="$user_password" -v congestion_control="$congestion_control" -v tls_insecure="$tls_insecure" -v ech_client_config="$ech_client_config" '
    /^  "outbounds": \[/ {print; getline; print "    {"; print "      \"type\": \"tuic\","; print "      \"tag\": \"" proxy_name "\","; print "      \"server\": \"" server_value "\", "; print "      \"server_port\": " listen_port ","; print "      \"uuid\": \"" user_uuid "\", "; print "      \"password\": \"" user_password "\", "; print "      \"congestion_control\": \""congestion_control"\","; print "      \"udp_relay_mode\": \"native\","; print "      \"zero_rtt_handshake\": false,"; print "      \"heartbeat\": \"10s\","; print "      \"tls\": {"; print "        \"enabled\": true,"; print "        \"insecure\": " tls_insecure ","; print "        \"server_name\": \"" server_name "\", "; print "        \"alpn\": ["; print "          \"h3\""; print "        ]" ech_client_config ""; print "      }"; print "    },";} 
    /^      "outbounds": \[/ {print; getline; if ($0 ~ /^      \],$/) {print "        \"" proxy_name "\""} else {print "        \"" proxy_name "\", "} }    
    {print}' "$win_client_file" > "$win_client_file.tmp"
    mv "$win_client_file.tmp" "$win_client_file"
}

function generate_tuic_yaml() {
    local filename="/usr/local/etc/sing-box/clash.yaml"
    local server_name="$domain"
    local proxy_name
    local server_value
    local tls_insecure
    if [ -z "$domain" ]; then
        server_name="$domain_name"
        server_value="$local_ip"
        tls_insecure="true"
    else
        server_value="$domain"
        tls_insecure="false"
    fi
    while true; do
        proxy_name="tuic-$(head /dev/urandom | tr -dc '0-9' | head -c 4)"
        if ! grep -q "name: $proxy_name" "$filename"; then
            break
        fi
    done
    awk -v proxy_name="$proxy_name" -v server_value="$server_value" -v server_name="$server_name" -v listen_port="$listen_port" -v user_uuid="$user_uuid" -v user_password="$user_password" -v congestion_control="$congestion_control" -v tls_insecure="$tls_insecure" '/^proxies:$/ {print; print "  - name: " proxy_name; print "    server:", server_value; print "    port:", listen_port; print "    type: tuic"; print "    uuid:", user_uuid; print "    password:", user_password; print "    sni:", server_name; print "    alpn: [h3]"; print "    request-timeout: 8000"; print "    udp-relay-mode: native"; print "    skip-cert-verify:", tls_insecure; print "    congestion-controller:", congestion_control; print ""; next} /- name: Proxy/ { print; flag_proxy=1; next } flag_proxy && flag_proxy++ == 3 { print "      - " proxy_name } /- name: auto/ { print; flag_auto=1; next } flag_auto && flag_auto++ == 3 { print "      - " proxy_name } 1' "$filename" > temp_file && mv temp_file "$filename"
}

function generate_socks_win_client_config() {
    local win_client_file="/usr/local/etc/sing-box/win_client.json"
    local proxy_name
    while true; do
        proxy_name="socks-$(head /dev/urandom | tr -dc '0-9' | head -c 4)"
        if ! grep -q "name: $proxy_name" "$win_client_file"; then
            break
        fi
    done
    awk -v proxy_name="$proxy_name" -v local_ip="$local_ip" -v listen_port="$listen_port" -v user_name="$user_name" -v user_password="$user_password" '
    /^  "outbounds": \[/ {print; getline; print "    {"; print "      \"type\": \"socks\","; print "      \"tag\": \"" proxy_name "\","; print "      \"server\": \"" local_ip "\", "; print "      \"server_port\": " listen_port ","; print "      \"username\": \"" user_name "\", "; print "      \"password\": \"" user_password "\" "; print "    },";}
    /^      "outbounds": \[/ {print; getline; if ($0 ~ /^      \],$/) {print "        \"" proxy_name "\""} else {print "        \"" proxy_name "\", "} }
    {print}' "$win_client_file" > "$win_client_file.tmp"    
    mv "$win_client_file.tmp" "$win_client_file"
}

function generate_socks_phone_client_config() {
    local phone_client_file="/usr/local/etc/sing-box/phone_client.json"
    local proxy_name
    while true; do
        proxy_name="socks-$(head /dev/urandom | tr -dc '0-9' | head -c 4)"
        if ! grep -q "name: $proxy_name" "$phone_client_file"; then
            break
        fi
    done
    awk -v proxy_name="$proxy_name" -v local_ip="$local_ip" -v listen_port="$listen_port" -v user_name="$user_name" -v user_password="$user_password" '
    /^  "outbounds": \[/ {print; getline; print "    {"; print "      \"type\": \"socks\","; print "      \"tag\": \"" proxy_name "\","; print "      \"server\": \"" local_ip "\", "; print "      \"server_port\": " listen_port ","; print "      \"username\": \"" user_name "\", "; print "      \"password\": \"" user_password "\" "; print "    },";}
    /^      "outbounds": \[/ {print; getline; if ($0 ~ /^      \],$/) {print "        \"" proxy_name "\""} else {print "        \"" proxy_name "\", "} }
    {print}' "$phone_client_file" > "$phone_client_file.tmp" 
    mv "$phone_client_file.tmp" "$phone_client_file"
}

function generate_socks_yaml() {
    local filename="/usr/local/etc/sing-box/clash.yaml"
    local proxy_name
    while true; do
        proxy_name="socks-$(head /dev/urandom | tr -dc '0-9' | head -c 4)"
        if ! grep -q "name: $proxy_name" "$filename"; then
            break
        fi
    done
    awk -v proxy_name="$proxy_name" -v local_ip="$local_ip" -v listen_port="$listen_port" -v user_name="$user_name" -v user_password="$user_password" '/^proxies:$/ {print; print "  - name: " proxy_name; print "    type: socks5"; print "    server:", local_ip; print "    port:", listen_port; print "    username:", user_name; print "    password:", user_password; print ""; next} /- name: Proxy/ { print; flag_proxy=1; next } flag_proxy && flag_proxy++ == 3 { print "      - " proxy_name } /- name: auto/ { print; flag_auto=1; next } flag_auto && flag_auto++ == 3 { print "      - " proxy_name } 1' "$filename" > temp_file && mv temp_file "$filename"
}

function generate_Hysteria_win_client_config() {
    local win_client_file="/usr/local/etc/sing-box/win_client.json"
    local server_name="$domain"
    local proxy_name
    local server_value
    local tls_insecure
    if [ -z "$domain" ]; then
        server_name="$domain_name"
        server_value="$local_ip"
        tls_insecure="true"
    else
        server_value="$domain"
        tls_insecure="false"
    fi
    if [ -n "$obfs_password" ]; then
        obfs_config="\n      \"obfs\": \"$obfs_password\","
    fi
    if [ -n "$ech_config" ]; then
        ech_client_config=",\n        \"ech\": {\n          \"enabled\": true,\n          \"pq_signature_schemes_enabled\": true,\n          \"dynamic_record_sizing_disabled\": false,\n          \"config\": [\n$ech_config\n          ]\n        }"
    fi
    while true; do
        proxy_name="Hysteria-$(head /dev/urandom | tr -dc '0-9' | head -c 4)"
        if ! grep -q "name: $proxy_name" "$win_client_file"; then
            break
        fi
    done
    awk -v proxy_name="$proxy_name" -v server_value="$server_value" -v server_name="$server_name" -v listen_port="$listen_port" -v up_mbps="$up_mbps" -v down_mbps="$down_mbps" -v obfs_config="$obfs_config" -v user_password="$user_password" -v tls_insecure="$tls_insecure" -v ech_client_config="$ech_client_config" '
    /^  "outbounds": \[/ {print; getline; print "    {"; print "      \"type\": \"hysteria\","; print "      \"tag\": \"" proxy_name "\","; print "      \"server\": \"" server_value "\", "; print "      \"server_port\": " listen_port ","; print "      \"up_mbps\": " down_mbps ", "; print "      \"down_mbps\": " up_mbps ","obfs_config""; print "      \"auth_str\": \""user_password"\","; print "      \"tls\": {"; print "        \"enabled\": true,"; print "        \"insecure\": " tls_insecure ","; print "        \"server_name\": \"" server_name "\", "; print "        \"alpn\": ["; print "          \"h3\""; print "        ]" ech_client_config ""; print "      }"; print "    },";} 
    /^      "outbounds": \[/ {print; getline; if ($0 ~ /^      \],$/) {print "        \"" proxy_name "\""} else {print "        \"" proxy_name "\", "} }    
    {print}' "$win_client_file" > "$win_client_file.tmp"
    mv "$win_client_file.tmp" "$win_client_file"
}

function generate_Hysteria_phone_client_config() {
    local phone_client_file="/usr/local/etc/sing-box/phone_client.json"
    local server_name="$domain"
    local proxy_name
    local server_value
    local tls_insecure
    if [ -z "$domain" ]; then
        server_name="$domain_name"
        server_value="$local_ip"
        tls_insecure="true"
    else
        server_value="$domain"
        tls_insecure="false"
    fi
    if [ -n "$obfs_password" ]; then
        obfs_config="\n      \"obfs\": \"$obfs_password\","
    fi
    if [ -n "$ech_config" ]; then
        ech_client_config=",\n        \"ech\": {\n          \"enabled\": true,\n          \"pq_signature_schemes_enabled\": true,\n          \"dynamic_record_sizing_disabled\": false,\n          \"config\": [\n$ech_config\n          ]\n        }"
    fi
    while true; do
        proxy_name="Hysteria-$(head /dev/urandom | tr -dc '0-9' | head -c 4)"
        if ! grep -q "name: $proxy_name" "$phone_client_file"; then
            break
        fi
    done
    awk -v proxy_name="$proxy_name" -v server_value="$server_value" -v server_name="$server_name" -v listen_port="$listen_port" -v up_mbps="$up_mbps" -v down_mbps="$down_mbps" -v obfs_config="$obfs_config" -v user_password="$user_password" -v tls_insecure="$tls_insecure" -v ech_client_config="$ech_client_config" '
    /^  "outbounds": \[/ {print; getline; print "    {"; print "      \"type\": \"hysteria\","; print "      \"tag\": \"" proxy_name "\","; print "      \"server\": \"" server_value "\", "; print "      \"server_port\": " listen_port ","; print "      \"up_mbps\": " down_mbps ", "; print "      \"down_mbps\": " up_mbps ","obfs_config""; print "      \"auth_str\": \""user_password"\","; print "      \"tls\": {"; print "        \"enabled\": true,"; print "        \"insecure\": " tls_insecure ","; print "        \"server_name\": \"" server_name "\", "; print "        \"alpn\": ["; print "          \"h3\""; print "        ]" ech_client_config ""; print "      }"; print "    },";} 
    /^      "outbounds": \[/ {print; getline; if ($0 ~ /^      \],$/) {print "        \"" proxy_name "\""} else {print "        \"" proxy_name "\", "} }    
    {print}' "$phone_client_file" > "$phone_client_file.tmp"
    mv "$phone_client_file.tmp" "$phone_client_file"
}

function generate_Hysteria_yaml() {
    local filename="/usr/local/etc/sing-box/clash.yaml"
    local server_name="$domain"
    local proxy_name
    local server_value
    local tls_insecure
    if [ -z "$domain" ]; then
        server_name="$domain_name"
        server_value="$local_ip"
        tls_insecure="true"
    else
        server_value="$domain"
        tls_insecure="false"
    fi
    if [ -n "$obfs_password" ]; then
        obfs_config="
    obfs: $obfs_password"
    fi

    while true; do
        proxy_name="hysteria-$(head /dev/urandom | tr -dc '0-9' | head -c 4)"
        if ! grep -q "name: $proxy_name" "$filename"; then
            break
        fi
    done
    awk -v proxy_name="$proxy_name" -v server_value="$server_value" -v server_name="$server_name" -v listen_port="$listen_port" -v up_mbps="$up_mbps" -v down_mbps="$down_mbps" -v user_password="$user_password" -v obfs_config="$obfs_config" -v tls_insecure="$tls_insecure" '/^proxies:$/ {print; print "  - name: " proxy_name; print "    type: hysteria"; print "    server:", server_value; print "    port:", listen_port; print "    auth-str:", user_password obfs_config; print "    sni:", server_name; print "    skip-cert-verify:", tls_insecure; print "    alpn:"; print "      - h3"; print "    protocol: udp"; print "    up: \"" down_mbps " Mbps\""; print "    down: \"" up_mbps " Mbps\""; print ""; next} /- name: Proxy/ { print; flag_proxy=1; next } flag_proxy && flag_proxy++ == 3 { print "      - " proxy_name } /- name: auto/ { print; flag_auto=1; next } flag_auto && flag_auto++ == 3 { print "      - " proxy_name } 1' "$filename" > temp_file && mv temp_file "$filename"
}

function generate_vmess_win_client_config() {
    local win_client_file="/usr/local/etc/sing-box/win_client.json"
    local proxy_name
    local server_name="$domain"
    local server_value
    local tls_insecure
    if [[ -z "$domain" && -n "$domain_name" ]]; then
        server_name="$domain_name"
        server_value="$local_ip"
        tls_insecure="true"
    elif [[ -z "$domain" && -z "$domain_name" ]]; then
        server_value="$local_ip"
    elif [[ -z "$domain_name" && -n "$domain" ]]; then
        server_name="$domain"
        server_value="$domain"
        tls_insecure="false"
    fi
    if [ -n "$multiplex_config" ] && [ -n "$brutal_config" ]; then
        multiplex_client_config=",\n      \"multiplex\": {\n        \"enabled\": true,\n        \"protocol\": \"h2mux\",\n        \"max_connections\": 1,\n        \"min_streams\": 4,\n        \"padding\": false,\n        \"brutal\": {\n          \"enabled\": true,\n          \"up_mbps\": $down_mbps,\n          \"down_mbps\": $up_mbps\n        }\n      }"
    elif [ -n "$multiplex_config" ] && [ -z "$brutal_config" ]; then
        multiplex_client_config=",\n      \"multiplex\": {\n        \"enabled\": true,\n        \"protocol\": \"h2mux\",\n        \"max_connections\": 1,\n        \"min_streams\": 4,\n        \"padding\": false\n      }"
    fi
    if [ -n "$ech_config" ]; then
      ech_client_config=",\n        \"ech\": {\n          \"enabled\": true,\n          \"pq_signature_schemes_enabled\": true,\n          \"dynamic_record_sizing_disabled\": false,\n          \"config\": [\n$ech_config\n          ]\n        }"
    fi
    while true; do
        proxy_name="vmess-$(head /dev/urandom | tr -dc '0-9' | head -c 4)"
        if ! grep -q "name: $proxy_name" "$win_client_file"; then
            break
        fi
    done
    if  [[ -n "$domain" || -n "$domain_name" ]]; then
        awk -v proxy_name="$proxy_name" -v server_value="$server_value" -v server_name="$server_name" -v listen_port="$listen_port" -v user_uuid="$user_uuid" -v transport_config="$transport_config" -v tls_insecure="$tls_insecure" -v ech_client_config="$ech_client_config" -v multiplex_client_config="$multiplex_client_config" '
      /^  "outbounds": \[/ {print; getline; print "    {"; print "      \"type\": \"vmess\","; print "      \"tag\": \"" proxy_name "\","; print "      \"server\": \"" server_value "\", "; print "      \"server_port\": " listen_port ","; print "      \"uuid\": \"" user_uuid "\"," transport_config " "; print "      \"tls\": {"; print "        \"enabled\": true,"; print "        \"insecure\": " tls_insecure ","; print "        \"server_name\": \"" server_name "\"" ech_client_config ""; print "      },"; print "      \"security\": \"auto\","; print "      \"alter_id\": 0,"; print "      \"packet_encoding\": \"xudp\"" multiplex_client_config ""; print "    },";} 
    /^      "outbounds": \[/ {print; getline; if ($0 ~ /^      \],$/) {print "        \"" proxy_name "\""} else {print "        \"" proxy_name "\", "} }
    {print}' "$win_client_file" > "$win_client_file.tmp"
    else
        awk -v proxy_name="$proxy_name" -v local_ip="$local_ip" -v listen_port="$listen_port" -v user_uuid="$user_uuid" -v transport_config="$transport_config" -v multiplex_client_config="$multiplex_client_config" '
      /^  "outbounds": \[/ {print; getline; print "    {"; print "      \"type\": \"vmess\","; print "      \"tag\": \"" proxy_name "\","; print "      \"server\": \"" local_ip "\", "; print "      \"server_port\": " listen_port ","; print "      \"uuid\": \"" user_uuid "\"," transport_config " "; print "      \"security\": \"auto\","; print "      \"alter_id\": 0,"; print "      \"packet_encoding\": \"xudp\"" multiplex_client_config ""; print "    },";} 
    /^      "outbounds": \[/ {print; getline; if ($0 ~ /^      \],$/) {print "        \"" proxy_name "\""} else {print "        \"" proxy_name "\", "} }
    {print}' "$win_client_file" > "$win_client_file.tmp"       
    fi
    mv "$win_client_file.tmp" "$win_client_file"
}

function generate_vmess_phone_client_config() {
    local phone_client_file="/usr/local/etc/sing-box/phone_client.json"
    local proxy_name
    local server_name="$domain"
    local server_value
    local tls_insecure
    if [[ -z "$domain" && -n "$domain_name" ]]; then
        server_name="$domain_name"
        server_value="$local_ip"
        tls_insecure="true"
    elif [[ -z "$domain" && -z "$domain_name" ]]; then
        server_value="$local_ip"
    elif [[ -z "$domain_name" && -n "$domain" ]]; then
        server_name="$domain"
        server_value="$domain"
        tls_insecure="false"
    fi
    if [ -n "$multiplex_config" ] && [ -n "$brutal_config" ]; then
        multiplex_client_config=",\n      \"multiplex\": {\n        \"enabled\": true,\n        \"protocol\": \"h2mux\",\n        \"max_connections\": 1,\n        \"min_streams\": 4,\n        \"padding\": false,\n        \"brutal\": {\n          \"enabled\": true,\n          \"up_mbps\": $down_mbps,\n          \"down_mbps\": $up_mbps\n        }\n      }"
    elif [ -n "$multiplex_config" ] && [ -z "$brutal_config" ]; then
        multiplex_client_config=",\n      \"multiplex\": {\n        \"enabled\": true,\n        \"protocol\": \"h2mux\",\n        \"max_connections\": 1,\n        \"min_streams\": 4,\n        \"padding\": false\n      }"
    fi
    if [ -n "$ech_config" ]; then
        ech_client_config=",\n        \"ech\": {\n          \"enabled\": true,\n          \"pq_signature_schemes_enabled\": true,\n          \"dynamic_record_sizing_disabled\": false,\n          \"config\": [\n$ech_config\n          ]\n        }"
    fi
    while true; do
        proxy_name="vmess-$(head /dev/urandom | tr -dc '0-9' | head -c 4)"
        if ! grep -q "name: $proxy_name" "$phone_client_file"; then
            break
        fi
    done
    if  [[ -n "$domain" || -n "$domain_name" ]]; then
        awk -v proxy_name="$proxy_name" -v server_value="$server_value" -v server_name="$server_name" -v listen_port="$listen_port" -v user_uuid="$user_uuid" -v transport_config="$transport_config" -v tls_insecure="$tls_insecure" -v ech_client_config="$ech_client_config" -v multiplex_client_config="$multiplex_client_config" '
      /^  "outbounds": \[/ {print; getline; print "    {"; print "      \"type\": \"vmess\","; print "      \"tag\": \"" proxy_name "\","; print "      \"server\": \"" server_value "\", "; print "      \"server_port\": " listen_port ","; print "      \"uuid\": \"" user_uuid "\"," transport_config " "; print "      \"tls\": {"; print "        \"enabled\": true,"; print "        \"insecure\": " tls_insecure ","; print "        \"server_name\": \"" server_name "\"" ech_client_config ""; print "      },"; print "      \"security\": \"auto\","; print "      \"alter_id\": 0,"; print "      \"packet_encoding\": \"xudp\"" multiplex_client_config ""; print "    },";}       
    /^      "outbounds": \[/ {print; getline; if ($0 ~ /^      \],$/) {print "        \"" proxy_name "\""} else {print "        \"" proxy_name "\", "} }     
    {print}' "$phone_client_file" > "$phone_client_file.tmp"
    else
        awk -v proxy_name="$proxy_name" -v local_ip="$local_ip" -v listen_port="$listen_port" -v user_uuid="$user_uuid" -v transport_config="$transport_config" -v multiplex_client_config="$multiplex_client_config" '
      /^  "outbounds": \[/ {print; getline; print "    {"; print "      \"type\": \"vmess\","; print "      \"tag\": \"" proxy_name "\","; print "      \"server\": \"" local_ip "\", "; print "      \"server_port\": " listen_port ","; print "      \"uuid\": \"" user_uuid "\"," transport_config " "; print "      \"security\": \"auto\","; print "      \"alter_id\": 0,"; print "      \"packet_encoding\": \"xudp\"" multiplex_client_config ""; print "    },";} 
    /^      "outbounds": \[/ {print; getline; if ($0 ~ /^      \],$/) {print "        \"" proxy_name "\""} else {print "        \"" proxy_name "\", "} }
    {print}' "$phone_client_file" > "$phone_client_file.tmp"
    fi       
    mv "$phone_client_file.tmp" "$phone_client_file"
}

function generate_vmess_tcp_yaml() {
    local filename="/usr/local/etc/sing-box/clash.yaml"
    local proxy_name
    while true; do
        proxy_name="vmess-tcp-$(head /dev/urandom | tr -dc '0-9' | head -c 4)"
        if ! grep -q "name: $proxy_name" "$filename"; then
            break
        fi
    done
    awk -v proxy_name="$proxy_name" -v local_ip="$local_ip" -v listen_port="$listen_port" -v user_uuid="$user_uuid" '/^proxies:$/ {print; print "  - name: " proxy_name; print "    type: vmess"; print "    server:", local_ip; print "    port:", listen_port; print "    uuid:", user_uuid; print "    alterId: 0"; print "    cipher: auto"; print ""; next} /- name: Proxy/ { print; flag_proxy=1; next } flag_proxy && flag_proxy++ == 3 { print "      - " proxy_name } /- name: auto/ { print; flag_auto=1; next } flag_auto && flag_auto++ == 3 { print "      - " proxy_name } 1' "$filename" > temp_file && mv temp_file "$filename"
}

function generate_vmess_tcp_tls_yaml() {
    local filename="/usr/local/etc/sing-box/clash.yaml"
    local server_name="$domain"
    local proxy_name
    local server_value
    local tls_insecure
    if [ -z "$domain" ]; then
        server_name="$domain_name"
        server_value="$local_ip"
        tls_insecure="true"
    else
        server_value="$domain"
        tls_insecure="false"
    fi
    while true; do
        proxy_name="vmess-tcp-tls-$(head /dev/urandom | tr -dc '0-9' | head -c 4)"
        if ! grep -q "name: $proxy_name" "$filename"; then
            break
        fi
    done
    awk -v proxy_name="$proxy_name" -v server_value="$server_value" -v server_name="$server_name" -v listen_port="$listen_port" -v user_uuid="$user_uuid" -v tls_insecure="$tls_insecure" '/^proxies:$/ {print; print "  - name: " proxy_name; print "    type: vmess"; print "    server:", server_value; print "    port:", listen_port; print "    uuid:", user_uuid; print "    alterId: 0"; print "    cipher: auto"; print "    tls: true"; print "    skip-cert-verify:", tls_insecure; print "    servername: " server_name; print ""; next} /- name: Proxy/ { print; flag_proxy=1; next } flag_proxy && flag_proxy++ == 3 { print "      - " proxy_name } /- name: auto/ { print; flag_auto=1; next } flag_auto && flag_auto++ == 3 { print "      - " proxy_name } 1' "$filename" > temp_file && mv temp_file "$filename"
}

function generate_vmess_ws_yaml() {
    local filename="/usr/local/etc/sing-box/clash.yaml"
    local proxy_name
    while true; do
        proxy_name="vmess-ws-$(head /dev/urandom | tr -dc '0-9' | head -c 4)"
        if ! grep -q "name: $proxy_name" "$filename"; then
            break
        fi
    done
    awk -v proxy_name="$proxy_name" -v local_ip="$local_ip" -v listen_port="$listen_port" -v user_uuid="$user_uuid" -v transport_path="$transport_path" '/^proxies:$/ {print; print "  - name: " proxy_name; print "    type: vmess"; print "    server:", local_ip; print "    port:", listen_port; print "    uuid:", user_uuid; print "    alterId: 0"; print "    cipher: auto"; print "    network: ws"; print "    ws-opts:"; print "      path: " transport_path; print "      max-early-data: 2048"; print "      early-data-header-name: Sec-WebSocket-Protocol"; print ""; next} /- name: Proxy/ { print; flag_proxy=1; next } flag_proxy && flag_proxy++ == 3 { print "      - " proxy_name } /- name: auto/ { print; flag_auto=1; next } flag_auto && flag_auto++ == 3 { print "      - " proxy_name } 1' "$filename" > temp_file && mv temp_file "$filename"
}

function generate_vmess_ws_tls_yaml() {
    local filename="/usr/local/etc/sing-box/clash.yaml"
    local server_name="$domain"
    local proxy_name
    local server_value
    local tls_insecure
    if [ -z "$domain" ]; then
        server_name="$domain_name"
        server_value="$local_ip"
        tls_insecure="true"
    else
        server_value="$domain"
        tls_insecure="false"
    fi
    while true; do
        proxy_name="vmess-ws-tls-$(head /dev/urandom | tr -dc '0-9' | head -c 4)"
        if ! grep -q "name: $proxy_name" "$filename"; then
            break
        fi
    done
    awk -v proxy_name="$proxy_name" -v server_value="$server_value" -v server_name="$server_name" -v listen_port="$listen_port" -v user_uuid="$user_uuid" -v transport_path="$transport_path" -v tls_insecure="$tls_insecure" '/^proxies:$/ {print; print "  - name: " proxy_name; print "    type: vmess"; print "    server:", server_value; print "    port:", listen_port; print "    uuid:", user_uuid; print "    alterId: 0"; print "    cipher: auto"; print "    network: ws"; print "    tls: true"; print "    skip-cert-verify:", tls_insecure; print "    servername:", server_name; print "    ws-opts:"; print "      path: " transport_path; print "      max-early-data: 2048"; print "      early-data-header-name: Sec-WebSocket-Protocol"; print ""; next} /- name: Proxy/ { print; flag_proxy=1; next } flag_proxy && flag_proxy++ == 3 { print "      - " proxy_name } /- name: auto/ { print; flag_auto=1; next } flag_auto && flag_auto++ == 3 { print "      - " proxy_name } 1' "$filename" > temp_file && mv temp_file "$filename"
}

function generate_vmess_grpc_yaml() {
    local filename="/usr/local/etc/sing-box/clash.yaml"
    local proxy_name
    while true; do
        proxy_name="vmess-grpc-$(head /dev/urandom | tr -dc '0-9' | head -c 4)"
        if ! grep -q "name: $proxy_name" "$filename"; then
            break
        fi
    done
    awk -v proxy_name="$proxy_name" -v local_ip="$local_ip" -v listen_port="$listen_port" -v user_uuid="$user_uuid" -v transport_service_name="$transport_service_name" '/^proxies:$/ {print; print "  - name: " proxy_name; print "    type: vmess"; print "    server:", local_ip; print "    port:", listen_port; print "    uuid:", user_uuid; print "    alterId: 0"; print "    cipher: auto"; print "    network: grpc"; print "    grpc-opts:"; print "      grpc-service-name:", "\"" transport_service_name "\""; print ""; next} /- name: Proxy/ { print; flag_proxy=1; next } flag_proxy && flag_proxy++ == 3 { print "      - " proxy_name } /- name: auto/ { print; flag_auto=1; next } flag_auto && flag_auto++ == 3 { print "      - " proxy_name } 1' "$filename" > temp_file && mv temp_file "$filename"
}

function generate_vmess_grpc_tls_yaml() {
    local filename="/usr/local/etc/sing-box/clash.yaml"
    local server_name="$domain"
    local proxy_name
    local server_value
    local tls_insecure
    if [ -z "$domain" ]; then
        server_name="$domain_name"
        server_value="$local_ip"
        tls_insecure="true"
    else
        server_value="$domain"
        tls_insecure="false"
    fi
    while true; do
        proxy_name="vmess-grpc-tls-$(head /dev/urandom | tr -dc '0-9' | head -c 4)"
        if ! grep -q "name: $proxy_name" "$filename"; then
            break
        fi
    done
    awk -v proxy_name="$proxy_name" -v server_value="$server_value" -v server_name="$server_name" -v listen_port="$listen_port" -v user_uuid="$user_uuid" -v transport_service_name="$transport_service_name" -v tls_insecure="$tls_insecure" '/^proxies:$/ {print; print "  - name: " proxy_name; print "    type: vmess"; print "    server:", server_value; print "    port:", listen_port; print "    uuid:", user_uuid; print "    alterId: 0"; print "    cipher: auto"; print "    network: grpc"; print "    tls: true"; print "    skip-cert-verify:", tls_insecure; print "    servername:", server_name; print "    grpc-opts:"; print "      grpc-service-name:", "\"" transport_service_name "\""; print ""; next} /- name: Proxy/ { print; flag_proxy=1; next } flag_proxy && flag_proxy++ == 3 { print "      - " proxy_name } /- name: auto/ { print; flag_auto=1; next } flag_auto && flag_auto++ == 3 { print "      - " proxy_name } 1' "$filename" > temp_file && mv temp_file "$filename"
}

function generate_http_phone_client_config() {
    local phone_client_file="/usr/local/etc/sing-box/phone_client.json"
    local server_name="$domain"
    local proxy_name
    local server_value
    local tls_insecure
    if [ -z "$domain" ]; then
        server_name="$domain_name"
        server_value="$local_ip"
        tls_insecure="true"
    else
        server_value="$domain"
        tls_insecure="false"
    fi
    if [ -n "$ech_config" ]; then
        ech_client_config=",\n        \"ech\": {\n          \"enabled\": true,\n          \"pq_signature_schemes_enabled\": true,\n          \"dynamic_record_sizing_disabled\": false,\n          \"config\": [\n$ech_config\n          ]\n        }"
    fi
    while true; do
        proxy_name="http-$(head /dev/urandom | tr -dc '0-9' | head -c 4)"
        if ! grep -q "name: $proxy_name" "$phone_client_file"; then
            break
        fi
    done
    awk -v proxy_name="$proxy_name" -v server_value="$server_value" -v server_name="$server_name" -v listen_port="$listen_port" -v user_name="$user_name" -v user_password="$user_password" -v tls_insecure="$tls_insecure" -v ech_client_config="$ech_client_config" '
    /^  "outbounds": \[/ {print; getline; print "    {"; print "      \"type\": \"http\","; print "      \"tag\": \"" proxy_name "\","; print "      \"server\": \"" server_value "\", "; print "      \"server_port\": " listen_port ","; print "      \"username\": \"" user_name "\", "; print "      \"password\": \"" user_password "\","; print "      \"tls\": {"; print "        \"enabled\": true,"; print "        \"insecure\": " tls_insecure ","; print "        \"server_name\": \"" server_name "\"" ech_client_config ""; print "      }"; print "    },";} 
   /^      "outbounds": \[/ {print; getline; if ($0 ~ /^      \],$/) {print "        \"" proxy_name "\""} else {print "        \"" proxy_name "\", "} }    
    {print}' "$phone_client_file" > "$phone_client_file.tmp"
    mv "$phone_client_file.tmp" "$phone_client_file"
}

function generate_http_win_client_config() {
    local win_client_file="/usr/local/etc/sing-box/win_client.json"
    local server_name="$domain"
    local proxy_name
    local server_value
    local tls_insecure
    if [ -z "$domain" ]; then
        server_name="$domain_name"
        server_value="$local_ip"
        tls_insecure="true"
    else
        server_value="$domain"
        tls_insecure="false"
    fi
    if [ -n "$ech_config" ]; then
        ech_client_config=",\n        \"ech\": {\n          \"enabled\": true,\n          \"pq_signature_schemes_enabled\": true,\n          \"dynamic_record_sizing_disabled\": false,\n          \"config\": [\n$ech_config\n          ]\n        }"
    fi
    while true; do
        proxy_name="http-$(head /dev/urandom | tr -dc '0-9' | head -c 4)"
        if ! grep -q "name: $proxy_name" "$win_client_file"; then
            break
        fi
    done
    awk -v proxy_name="$proxy_name" -v server_value="$server_value" -v server_name="$server_name" -v listen_port="$listen_port" -v user_name="$user_name" -v user_password="$user_password" -v tls_insecure="$tls_insecure" -v ech_client_config="$ech_client_config" '
    /^  "outbounds": \[/ {print; getline; print "    {"; print "      \"type\": \"http\","; print "      \"tag\": \"" proxy_name "\","; print "      \"server\": \"" server_value "\", "; print "      \"server_port\": " listen_port ","; print "      \"username\": \"" user_name "\", "; print "      \"password\": \"" user_password "\","; print "      \"tls\": {"; print "        \"enabled\": true,"; print "        \"insecure\": " tls_insecure ","; print "        \"server_name\": \"" server_name "\"" ech_client_config ""; print "      }"; print "    },";} 
   /^      "outbounds": \[/ {print; getline; if ($0 ~ /^      \],$/) {print "        \"" proxy_name "\""} else {print "        \"" proxy_name "\", "} }    
    {print}' "$win_client_file" > "$win_client_file.tmp"
    mv "$win_client_file.tmp" "$win_client_file"
}

function generate_http_yaml() {
    local filename="/usr/local/etc/sing-box/clash.yaml"
    local server_name="$domain"
    local proxy_name
    local server_value
    local tls_insecure
    if [ -z "$domain" ]; then
        server_name="$domain_name"
        server_value="$local_ip"
        tls_insecure="true"
    else
        server_value="$domain"
        tls_insecure="false"
    fi
    while true; do
        proxy_name="http-$(head /dev/urandom | tr -dc '0-9' | head -c 4)"
        if ! grep -q "name: $proxy_name" "$filename"; then
            break
        fi
    done
    awk -v proxy_name="$proxy_name" -v server_value="$server_value" -v server_name="$server_name" -v listen_port="$listen_port" -v user_name="$user_name" -v user_password="$user_password" -v tls_insecure="$tls_insecure" '/^proxies:$/ {print; print "  - name: " proxy_name; print "    type: http"; print "    server:", server_value; print "    port:", listen_port; print "    username:", user_name; print "    password:", user_password; print "    tls: true"; print "    sni:", server_name; print "    skip-cert-verify:", tls_insecure; print ""; next} /- name: Proxy/ { print; flag_proxy=1; next } flag_proxy && flag_proxy++ == 3 { print "      - " proxy_name } /- name: auto/ { print; flag_auto=1; next } flag_auto && flag_auto++ == 3 { print "      - " proxy_name } 1' "$filename" > temp_file && mv temp_file "$filename"
}

function generate_Hysteria2_phone_client_config() {
    local phone_client_file="/usr/local/etc/sing-box/phone_client.json"
    local server_name="$domain"
    local proxy_name
    local server_value
    local tls_insecure
    if [ -z "$domain" ]; then
        server_name="$domain_name"
        server_value="$local_ip"
        tls_insecure="true"
    else
        server_value="$domain"
        tls_insecure="false"
    fi
    if [ -n "$obfs_password" ]; then
        obfs_config="\n      \"obfs\": {\n        \"type\": \"salamander\",\n        \"password\": \"$obfs_password\"\n      },"
    fi
    if [ -n "$ech_config" ]; then
        ech_client_config=",\n        \"ech\": {\n          \"enabled\": true,\n          \"pq_signature_schemes_enabled\": true,\n          \"dynamic_record_sizing_disabled\": false,\n          \"config\": [\n$ech_config\n          ]\n        }"
    fi
    while true; do
        proxy_name="Hysteria2-$(head /dev/urandom | tr -dc '0-9' | head -c 4)"
        if ! grep -q "name: $proxy_name" "$phone_client_file"; then
            break
        fi
    done
    awk -v proxy_name="$proxy_name" -v server_value="$server_value" -v server_name="$server_name" -v listen_port="$listen_port" -v up_mbps="$up_mbps" -v down_mbps="$down_mbps" -v obfs_config="$obfs_config" -v user_password="$user_password" -v tls_insecure="$tls_insecure" -v ech_client_config="$ech_client_config" '
    /^  "outbounds": \[/ {print; getline; print "    {"; print "      \"type\": \"hysteria2\","; print "      \"tag\": \"" proxy_name "\","; print "      \"server\": \"" server_value "\", "; print "      \"server_port\": " listen_port ","; print "      \"up_mbps\": " down_mbps ", "; print "      \"down_mbps\": " up_mbps ","obfs_config""; print "      \"password\": \"" user_password "\","; print "      \"tls\": {"; print "        \"enabled\": true,"; print "        \"insecure\": " tls_insecure ","; print "        \"server_name\": \"" server_name "\", "; print "        \"alpn\": ["; print "          \"h3\""; print "        ]" ech_client_config ""; print "      }"; print "    },";} 
   /^      "outbounds": \[/ {print; getline; if ($0 ~ /^      \],$/) {print "        \"" proxy_name "\""} else {print "        \"" proxy_name "\", "} }    
    {print}' "$phone_client_file" > "$phone_client_file.tmp"
    mv "$phone_client_file.tmp" "$phone_client_file"
}

function generate_Hysteria2_win_client_config() {
    local win_client_file="/usr/local/etc/sing-box/win_client.json"
    local server_name="$domain"
    local proxy_name
    local server_value
    local tls_insecure
    if [ -z "$domain" ]; then
        server_name="$domain_name"
        server_value="$local_ip"
        tls_insecure="true"
    else
        server_value="$domain"
        tls_insecure="false"
    fi
    if [ -n "$obfs_password" ]; then
        obfs_config="\n      \"obfs\": {\n        \"type\": \"salamander\",\n        \"password\": \"$obfs_password\"\n      },"
    fi
    if [ -n "$ech_config" ]; then
        ech_client_config=",\n        \"ech\": {\n          \"enabled\": true,\n          \"pq_signature_schemes_enabled\": true,\n          \"dynamic_record_sizing_disabled\": false,\n          \"config\": [\n$ech_config\n          ]\n        }"
    fi
    while true; do
        proxy_name="Hysteria2-$(head /dev/urandom | tr -dc '0-9' | head -c 4)"
        if ! grep -q "name: $proxy_name" "$win_client_file"; then
            break
        fi
    done
    awk -v proxy_name="$proxy_name" -v server_value="$server_value" -v server_name="$server_name" -v listen_port="$listen_port" -v up_mbps="$up_mbps" -v down_mbps="$down_mbps" -v obfs_config="$obfs_config" -v user_password="$user_password" -v tls_insecure="$tls_insecure" -v ech_client_config="$ech_client_config" '
    /^  "outbounds": \[/ {print; getline; print "    {"; print "      \"type\": \"hysteria2\","; print "      \"tag\": \"" proxy_name "\","; print "      \"server\": \"" server_value "\", "; print "      \"server_port\": " listen_port ","; print "      \"up_mbps\": " down_mbps ", "; print "      \"down_mbps\": " up_mbps ","obfs_config""; print "      \"password\": \"" user_password "\","; print "      \"tls\": {"; print "        \"enabled\": true,"; print "        \"insecure\": " tls_insecure ","; print "        \"server_name\": \"" server_name "\", "; print "        \"alpn\": ["; print "          \"h3\""; print "        ]" ech_client_config ""; print "      }"; print "    },";} 
    /^      "outbounds": \[/ {print; getline; if ($0 ~ /^      \],$/) {print "        \"" proxy_name "\""} else {print "        \"" proxy_name "\", "} }    
    {print}' "$win_client_file" > "$win_client_file.tmp"
    mv "$win_client_file.tmp" "$win_client_file"
}

function generate_Hysteria2_yaml() {
    local filename="/usr/local/etc/sing-box/clash.yaml"
    local server_name="$domain"
    local proxy_name
    local server_value
    local tls_insecure
    if [ -z "$domain" ]; then
        server_name="$domain_name"
        server_value="$local_ip"
        tls_insecure="true"
    else
        server_value="$domain"
        tls_insecure="false"
    fi
    if [ -n "$obfs_password" ]; then
        obfs_config="
    obfs: salamander
    obfs-password: $obfs_password"
    fi
    while true; do
        proxy_name="hysteria2-$(head /dev/urandom | tr -dc '0-9' | head -c 4)"
        if ! grep -q "name: $proxy_name" "$filename"; then
            break
        fi
    done
    awk -v proxy_name="$proxy_name" -v server_value="$server_value" -v server_name="$server_name" -v listen_port="$listen_port" -v up_mbps="$up_mbps" -v down_mbps="$down_mbps" -v user_password="$user_password" -v obfs_config="$obfs_config" -v tls_insecure="$tls_insecure" '/^proxies:$/ {print; print "  - name: " proxy_name; print "    type: hysteria2"; print "    server:", server_value; print "    port:", listen_port; print "    password:", user_password obfs_config; print "    alpn:"; print "      - h3"; print "    sni:", server_name; print "    skip-cert-verify:", tls_insecure; print "    up: \"" down_mbps " Mbps\""; print "    down: \"" up_mbps " Mbps\""; print ""; next} /- name: Proxy/ { print; flag_proxy=1; next } flag_proxy && flag_proxy++ == 3 { print "      - " proxy_name } /- name: auto/ { print; flag_auto=1; next } flag_auto && flag_auto++ == 3 { print "      - " proxy_name } 1' "$filename" > temp_file && mv temp_file "$filename"
}

function generate_vless_win_client_config() {
    local win_client_file="/usr/local/etc/sing-box/win_client.json"
    local proxy_name
    local server_name_in_config=$(jq -r '.inbounds[0].tls.server_name' "$config_file")
    if [ -n "$multiplex_config" ] && [ -n "$brutal_config" ]; then
        multiplex_client_config=",\n      \"multiplex\": {\n        \"enabled\": true,\n        \"protocol\": \"h2mux\",\n        \"max_connections\": 1,\n        \"min_streams\": 4,\n        \"padding\": false,\n        \"brutal\": {\n          \"enabled\": true,\n          \"up_mbps\": $down_mbps,\n          \"down_mbps\": $up_mbps\n        }\n      }"
    elif [ -n "$multiplex_config" ] && [ -z "$brutal_config" ]; then
        multiplex_client_config=",\n      \"multiplex\": {\n        \"enabled\": true,\n        \"protocol\": \"h2mux\",\n        \"max_connections\": 1,\n        \"min_streams\": 4,\n        \"padding\": false\n      }"
    fi
    while true; do
        proxy_name="vless-$(head /dev/urandom | tr -dc '0-9' | head -c 4)"
        if ! grep -q "name: $proxy_name" "$win_client_file"; then
            break
        fi
    done
    if [ "$server_name_in_config" != "null" ]; then
    awk -v proxy_name="$proxy_name" -v local_ip="$local_ip" -v server_name="$server_name" -v listen_port="$listen_port" -v user_uuid="$user_uuid" -v flow_type="$flow_type" -v public_key="$public_key" -v short_id="$short_id" -v transport_config="$transport_config" -v multiplex_client_config="$multiplex_client_config" '
    /^  "outbounds": \[/ {print; getline; print "    {"; print "      \"type\": \"vless\","; print "      \"tag\": \"" proxy_name "\","; print "      \"server\": \"" local_ip "\", "; print "      \"server_port\": " listen_port ","; print "      \"uuid\": \"" user_uuid "\", "; print "      \"flow\": \"" flow_type "\"," transport_config ""; print "      \"tls\": {"; print "        \"enabled\": true,"; print "        \"server_name\": \"" server_name "\", "; print "        \"utls\": {"; print "          \"enabled\": true,"; print "          \"fingerprint\": \"chrome\""; print "        },"; print "        \"reality\": {"; print "          \"enabled\": true,"; print "          \"public_key\": \"" public_key "\","; print "          \"short_id\": \"" short_id "\""; print "        }"; print "      }" multiplex_client_config ""; print "    },";} 
    /^      "outbounds": \[/ {print; getline; if ($0 ~ /^      \],$/) {print "        \"" proxy_name "\""} else {print "        \"" proxy_name "\", "} }    
    {print}' "$win_client_file" > "$win_client_file.tmp"
    else
    awk -v proxy_name="$proxy_name" -v local_ip="$local_ip" -v listen_port="$listen_port" -v user_uuid="$user_uuid" -v flow_type="$flow_type" -v transport_config="$transport_config" -v multiplex_client_config="$multiplex_client_config" '
    /^  "outbounds": \[/ {print; getline; print "    {"; print "      \"type\": \"vless\","; print "      \"tag\": \"" proxy_name "\","; print "      \"server\": \"" local_ip "\", "; print "      \"server_port\": " listen_port ","; print "      \"uuid\": \"" user_uuid "\"," transport_config ""; print "      \"flow\": \"" flow_type "\"" multiplex_client_config ""; print "    },";} 
    /^      "outbounds": \[/ {print; getline; if ($0 ~ /^      \],$/) {print "        \"" proxy_name "\""} else {print "        \"" proxy_name "\", "} }    
    {print}' "$win_client_file" > "$win_client_file.tmp"
    fi
    mv "$win_client_file.tmp" "$win_client_file"
}

function generate_vless_phone_client_config() {
    local phone_client_file="/usr/local/etc/sing-box/phone_client.json"
    local proxy_name
    local server_name_in_config=$(jq -r '.inbounds[0].tls.server_name' "$config_file")
    if [ -n "$multiplex_config" ] && [ -n "$brutal_config" ]; then
        multiplex_client_config=",\n      \"multiplex\": {\n        \"enabled\": true,\n        \"protocol\": \"h2mux\",\n        \"max_connections\": 1,\n        \"min_streams\": 4,\n        \"padding\": false,\n        \"brutal\": {\n          \"enabled\": true,\n          \"up_mbps\": $down_mbps,\n          \"down_mbps\": $up_mbps\n        }\n      }"
    elif [ -n "$multiplex_config" ] && [ -z "$brutal_config" ]; then
        multiplex_client_config=",\n      \"multiplex\": {\n        \"enabled\": true,\n        \"protocol\": \"h2mux\",\n        \"max_connections\": 1,\n        \"min_streams\": 4,\n        \"padding\": false\n      }"
    fi
    while true; do
        proxy_name="vless-$(head /dev/urandom | tr -dc '0-9' | head -c 4)"
        if ! grep -q "name: $proxy_name" "$phone_client_file"; then
            break
        fi
    done
    if [ "$server_name_in_config" != "null" ]; then
    awk -v proxy_name="$proxy_name" -v local_ip="$local_ip" -v server_name="$server_name" -v listen_port="$listen_port" -v user_uuid="$user_uuid" -v flow_type="$flow_type" -v public_key="$public_key" -v short_id="$short_id" -v transport_config="$transport_config" -v multiplex_client_config="$multiplex_client_config" '
    /^  "outbounds": \[/ {print; getline; print "    {"; print "      \"type\": \"vless\","; print "      \"tag\": \"" proxy_name "\","; print "      \"server\": \"" local_ip "\", "; print "      \"server_port\": " listen_port ","; print "      \"uuid\": \"" user_uuid "\", "; print "      \"flow\": \"" flow_type "\"," transport_config ""; print "      \"tls\": {"; print "        \"enabled\": true,"; print "        \"server_name\": \"" server_name "\", "; print "        \"utls\": {"; print "          \"enabled\": true,"; print "          \"fingerprint\": \"chrome\""; print "        },"; print "        \"reality\": {"; print "          \"enabled\": true,"; print "          \"public_key\": \"" public_key "\","; print "          \"short_id\": \"" short_id "\""; print "        }"; print "      }" multiplex_client_config ""; print "    },";} 
    /^      "outbounds": \[/ {print; getline; if ($0 ~ /^      \],$/) {print "        \"" proxy_name "\""} else {print "        \"" proxy_name "\", "} }    
    {print}' "$phone_client_file" > "$phone_client_file.tmp"
    else
    awk -v proxy_name="$proxy_name" -v local_ip="$local_ip" -v listen_port="$listen_port" -v user_uuid="$user_uuid" -v flow_type="$flow_type" -v transport_config="$transport_config" -v multiplex_client_config="$multiplex_client_config" '
    /^  "outbounds": \[/ {print; getline; print "    {"; print "      \"type\": \"vless\","; print "      \"tag\": \"" proxy_name "\","; print "      \"server\": \"" local_ip "\", "; print "      \"server_port\": " listen_port ","; print "      \"uuid\": \"" user_uuid "\"," transport_config ""; print "      \"flow\": \"" flow_type "\"" multiplex_client_config ""; print "    },";} 
    /^      "outbounds": \[/ {print; getline; if ($0 ~ /^      \],$/) {print "        \"" proxy_name "\""} else {print "        \"" proxy_name "\", "} }    
    {print}' "$phone_client_file" > "$phone_client_file.tmp"
    fi
    mv "$phone_client_file.tmp" "$phone_client_file"
}

function generate_vless_tcp_yaml() {
    local filename="/usr/local/etc/sing-box/clash.yaml"
    local proxy_name
    while true; do
        proxy_name="vless-tcp-$(head /dev/urandom | tr -dc '0-9' | head -c 4)"
        if ! grep -q "name: $proxy_name" "$filename"; then
            break
        fi
    done
    awk -v proxy_name="$proxy_name" -v local_ip="$local_ip" -v listen_port="$listen_port" -v user_uuid="$user_uuid" '/^proxies:$/ {print; print "  - name: " proxy_name; print "    type: vless"; print "    server:", local_ip; print "    port:", listen_port; print "    uuid:", user_uuid; print "    network: tcp"; print "    udp: true"; print ""; next} /- name: Proxy/ { print; flag_proxy=1; next } flag_proxy && flag_proxy++ == 3 { print "      - " proxy_name } /- name: auto/ { print; flag_auto=1; next } flag_auto && flag_auto++ == 3 { print "      - " proxy_name } 1' "$filename" > temp_file && mv temp_file "$filename"
}

function generate_vless_ws_yaml() {
    local filename="/usr/local/etc/sing-box/clash.yaml"
    local proxy_name
    while true; do
        proxy_name="vless-ws-$(head /dev/urandom | tr -dc '0-9' | head -c 4)"
        if ! grep -q "name: $proxy_name" "$filename"; then
            break
        fi
    done
    awk -v proxy_name="$proxy_name" -v local_ip="$local_ip" -v listen_port="$listen_port" -v user_uuid="$user_uuid" -v transport_path="$transport_path" '/^proxies:$/ {print; print "  - name: " proxy_name; print "    type: vless"; print "    server:", local_ip; print "    port:", listen_port; print "    uuid:", user_uuid; print "    network: ws"; print "    udp: true"; print "    ws-opts:"; print "      path: " transport_path; print "      max-early-data: 2048"; print "      early-data-header-name: Sec-WebSocket-Protocol"; print ""; next} /- name: Proxy/ { print; flag_proxy=1; next } flag_proxy && flag_proxy++ == 3 { print "      - " proxy_name } /- name: auto/ { print; flag_auto=1; next } flag_auto && flag_auto++ == 3 { print "      - " proxy_name } 1' "$filename" > temp_file && mv temp_file "$filename"
}

function generate_vless_grpc_yaml() {
    local filename="/usr/local/etc/sing-box/clash.yaml"
    local proxy_name
    while true; do
        proxy_name="vless-grpc-$(head /dev/urandom | tr -dc '0-9' | head -c 4)"
        if ! grep -q "name: $proxy_name" "$filename"; then
            break
        fi
    done
    awk -v proxy_name="$proxy_name" -v local_ip="$local_ip" -v listen_port="$listen_port" -v user_uuid="$user_uuid" -v transport_service_name="$transport_service_name" '/^proxies:$/ {print; print "  - name: " proxy_name; print "    type: vless"; print "    server:", local_ip; print "    port:", listen_port; print "    uuid:", user_uuid; print "    network: grpc"; print "    udp: true"; print "    grpc-opts:"; print "      grpc-service-name:", "\"" transport_service_name "\""; print ""; next} /- name: Proxy/ { print; flag_proxy=1; next } flag_proxy && flag_proxy++ == 3 { print "      - " proxy_name } /- name: auto/ { print; flag_auto=1; next } flag_auto && flag_auto++ == 3 { print "      - " proxy_name } 1' "$filename" > temp_file && mv temp_file "$filename"
}

function generate_vless_reality_vision_yaml() {
    local filename="/usr/local/etc/sing-box/clash.yaml"
    local proxy_name
    while true; do
        proxy_name="vless-reality-vision-$(head /dev/urandom | tr -dc '0-9' | head -c 4)"
        if ! grep -q "name: $proxy_name" "$filename"; then
            break
        fi
    done
    awk -v proxy_name="$proxy_name" -v local_ip="$local_ip" -v server_name="$server_name" -v listen_port="$listen_port" -v user_uuid="$user_uuid" -v public_key="$public_key" -v short_id="$short_id" '/^proxies:$/ {print; print "  - name: " proxy_name; print "    type: vless"; print "    server:", local_ip; print "    port:", listen_port; print "    uuid:", user_uuid; print "    network: tcp"; print "    udp: true"; print "    tls: true"; print "    flow: xtls-rprx-vision"; print "    servername:", server_name; print "    reality-opts:"; print "      public-key:", public_key; print "      short-id:", short_id; print ""; next} /- name: Proxy/ { print; flag_proxy=1; next } flag_proxy && flag_proxy++ == 3 { print "      - " proxy_name } /- name: auto/ { print; flag_auto=1; next } flag_auto && flag_auto++ == 3 { print "      - " proxy_name } 1' "$filename" > temp_file && mv temp_file "$filename"
}

function generate_vless_reality_grpc_yaml() {
    local filename="/usr/local/etc/sing-box/clash.yaml"
    local proxy_name 
    while true; do
        proxy_name="vless-reality-grpc-$(head /dev/urandom | tr -dc '0-9' | head -c 4)"
        if ! grep -q "name: $proxy_name" "$filename"; then
            break
        fi
    done
    awk -v proxy_name="$proxy_name" -v local_ip="$local_ip" -v server_name="$server_name" -v listen_port="$listen_port" -v user_uuid="$user_uuid" -v public_key="$public_key" -v short_id="$short_id" -v transport_service_name="$transport_service_name" '/^proxies:$/ {print; print "  - name: " proxy_name; print "    type: vless"; print "    server:", local_ip; print "    port:", listen_port; print "    uuid:", user_uuid; print "    network: grpc"; print "    udp: true"; print "    tls: true"; print "    flow: "; print "    servername:", server_name; print "    reality-opts:"; print "      public-key:", public_key; print "      short-id:", short_id; print "    grpc-opts:"; print "      grpc-service-name:", "\"" transport_service_name "\""; print ""; next} /- name: Proxy/ { print; flag_proxy=1; next } flag_proxy && flag_proxy++ == 3 { print "      - " proxy_name } /- name: auto/ { print; flag_auto=1; next } flag_auto && flag_auto++ == 3 { print "      - " proxy_name } 1' "$filename" > temp_file && mv temp_file "$filename"
}

function generate_trojan_phone_client_config() {
    local phone_client_file="/usr/local/etc/sing-box/phone_client.json"
    local proxy_name
    local server_name="$domain"
    local server_value
    local tls_insecure
    if [[ -z "$domain" && -n "$domain_name" ]]; then
        server_name="$domain_name"
        server_value="$local_ip"
        tls_insecure="true"
    elif [[ -z "$domain" && -z "$domain_name" ]]; then
        server_value="$local_ip"
    elif [[ -z "$domain_name" && -n "$domain" ]]; then
        server_name="$domain"
        server_value="$domain"
        tls_insecure="false"
    fi
    if [ -n "$multiplex_config" ] && [ -n "$brutal_config" ]; then
        multiplex_client_config=",\n      \"multiplex\": {\n        \"enabled\": true,\n        \"protocol\": \"h2mux\",\n        \"max_connections\": 1,\n        \"min_streams\": 4,\n        \"padding\": false,\n        \"brutal\": {\n          \"enabled\": true,\n          \"up_mbps\": $down_mbps,\n          \"down_mbps\": $up_mbps\n        }\n      }"
    elif [ -n "$multiplex_config" ] && [ -z "$brutal_config" ]; then
        multiplex_client_config=",\n      \"multiplex\": {\n        \"enabled\": true,\n        \"protocol\": \"h2mux\",\n        \"max_connections\": 1,\n        \"min_streams\": 4,\n        \"padding\": false\n      }"
    fi
    if [ -n "$ech_config" ]; then
        ech_client_config=",\n        \"ech\": {\n          \"enabled\": true,\n          \"pq_signature_schemes_enabled\": true,\n          \"dynamic_record_sizing_disabled\": false,\n          \"config\": [\n$ech_config\n          ]\n        }"
    fi
    while true; do
        proxy_name="trojan-$(head /dev/urandom | tr -dc '0-9' | head -c 4)"
        if ! grep -q "name: $proxy_name" "$phone_client_file"; then
            break
        fi
    done
    if  [[ -n "$domain" || -n "$domain_name" ]]; then
    awk -v proxy_name="$proxy_name" -v server_value="$server_value" -v server_name="$server_name" -v listen_port="$listen_port" -v user_password="$user_password" -v transport_config="$transport_config" -v tls_insecure="$tls_insecure" -v ech_client_config="$ech_client_config" -v multiplex_client_config="$multiplex_client_config" '
    /^  "outbounds": \[/ {print; getline; print "    {"; print "      \"type\": \"trojan\","; print "      \"tag\": \"" proxy_name "\","; print "      \"server\": \"" server_value "\", "; print "      \"server_port\": " listen_port ","; print "      \"password\": \"" user_password "\"," transport_config " "; print "      \"tls\": {"; print "        \"enabled\": true,"; print "        \"insecure\": " tls_insecure ","; print "        \"server_name\": \"" server_name "\"" ech_client_config ""; print "      }"multiplex_client_config""; print "    },";} 
   /^      "outbounds": \[/ {print; getline; if ($0 ~ /^      \],$/) {print "        \"" proxy_name "\""} else {print "        \"" proxy_name "\", "} }    
    {print}' "$phone_client_file" > "$phone_client_file.tmp"
    else
    awk -v proxy_name="$proxy_name" -v local_ip="$local_ip" -v listen_port="$listen_port" -v user_password="$user_password" -v transport_config="$transport_config" -v multiplex_client_config="$multiplex_client_config" '
    /^  "outbounds": \[/ {print; getline; print "    {"; print "      \"type\": \"trojan\","; print "      \"tag\": \"" proxy_name "\","; print "      \"server\": \"" local_ip "\", "; print "      \"server_port\": " listen_port "," transport_config " "; print "      \"password\": \"" user_password "\""multiplex_client_config""; print "    },";} 
   /^      "outbounds": \[/ {print; getline; if ($0 ~ /^      \],$/) {print "        \"" proxy_name "\""} else {print "        \"" proxy_name "\", "} }    
    {print}' "$phone_client_file" > "$phone_client_file.tmp"
    fi
    mv "$phone_client_file.tmp" "$phone_client_file"
}

function generate_trojan_win_client_config() {
    local win_client_file="/usr/local/etc/sing-box/win_client.json"
    local proxy_name
    local server_name="$domain"
    local server_value
    local tls_insecure
    if [[ -z "$domain" && -n "$domain_name" ]]; then
        server_name="$domain_name"
        server_value="$local_ip"
        tls_insecure="true"
    elif [[ -z "$domain" && -z "$domain_name" ]]; then
        server_value="$local_ip"
    elif [[ -z "$domain_name" && -n "$domain" ]]; then
        server_name="$domain"
        server_value="$domain"
        tls_insecure="false"
    fi
    if [ -n "$multiplex_config" ] && [ -n "$brutal_config" ]; then
        multiplex_client_config=",\n      \"multiplex\": {\n        \"enabled\": true,\n        \"protocol\": \"h2mux\",\n        \"max_connections\": 1,\n        \"min_streams\": 4,\n        \"padding\": false,\n        \"brutal\": {\n          \"enabled\": true,\n          \"up_mbps\": $down_mbps,\n          \"down_mbps\": $up_mbps\n        }\n      }"
    elif [ -n "$multiplex_config" ] && [ -z "$brutal_config" ]; then
        multiplex_client_config=",\n      \"multiplex\": {\n        \"enabled\": true,\n        \"protocol\": \"h2mux\",\n        \"max_connections\": 1,\n        \"min_streams\": 4,\n        \"padding\": false\n      }"
    fi
    if [ -n "$ech_config" ]; then
        ech_client_config=",\n        \"ech\": {\n          \"enabled\": true,\n          \"pq_signature_schemes_enabled\": true,\n          \"dynamic_record_sizing_disabled\": false,\n          \"config\": [\n$ech_config\n          ]\n        }"
    fi
    while true; do
        proxy_name="trojan-$(head /dev/urandom | tr -dc '0-9' | head -c 4)"
        if ! grep -q "name: $proxy_name" "$win_client_file"; then
            break
        fi
    done
    if  [[ -n "$domain" || -n "$domain_name" ]]; then
    awk -v proxy_name="$proxy_name" -v server_value="$server_value" -v server_name="$server_name" -v listen_port="$listen_port" -v user_password="$user_password" -v transport_config="$transport_config" -v tls_insecure="$tls_insecure" -v ech_client_config="$ech_client_config" -v multiplex_client_config="$multiplex_client_config" '
    /^  "outbounds": \[/ {print; getline; print "    {"; print "      \"type\": \"trojan\","; print "      \"tag\": \"" proxy_name "\","; print "      \"server\": \"" server_value "\", "; print "      \"server_port\": " listen_port ","; print "      \"password\": \"" user_password "\"," transport_config " "; print "      \"tls\": {"; print "        \"enabled\": true,"; print "        \"insecure\": " tls_insecure ","; print "        \"server_name\": \"" server_name "\"" ech_client_config ""; print "      }"multiplex_client_config""; print "    },";} 
   /^      "outbounds": \[/ {print; getline; if ($0 ~ /^      \],$/) {print "        \"" proxy_name "\""} else {print "        \"" proxy_name "\", "} }    
    {print}' "$win_client_file" > "$win_client_file.tmp"
    else
    awk -v proxy_name="$proxy_name" -v local_ip="$local_ip" -v listen_port="$listen_port" -v user_password="$user_password" -v transport_config="$transport_config" -v multiplex_client_config="$multiplex_client_config" '
    /^  "outbounds": \[/ {print; getline; print "    {"; print "      \"type\": \"trojan\","; print "      \"tag\": \"" proxy_name "\","; print "      \"server\": \"" local_ip "\", "; print "      \"server_port\": " listen_port "," transport_config " "; print "      \"password\": \"" user_password "\""multiplex_client_config""; print "    },";} 
   /^      "outbounds": \[/ {print; getline; if ($0 ~ /^      \],$/) {print "        \"" proxy_name "\""} else {print "        \"" proxy_name "\", "} }    
    {print}' "$win_client_file" > "$win_client_file.tmp"
    fi
    mv "$win_client_file.tmp" "$win_client_file"
}

function generate_trojan_tcp_tls_yaml() {
    local filename="/usr/local/etc/sing-box/clash.yaml"
    local server_name="$domain"
    local proxy_name
    local server_value
    local tls_insecure
    if [ -z "$domain" ]; then
        server_name="$domain_name"
        server_value="$local_ip"
        tls_insecure="true"
    else
        server_value="$domain"
        tls_insecure="false"
    fi
    while true; do
        proxy_name="trojan-tcp-tls-$(head /dev/urandom | tr -dc '0-9' | head -c 4)"
        if ! grep -q "name: $proxy_name" "$filename"; then
            break
       fi
    done
    awk -v proxy_name="$proxy_name" -v server_value="$server_value" -v server_name="$server_name" -v listen_port="$listen_port" -v user_password="$user_password" -v tls_insecure="$tls_insecure" '/^proxies:$/ {print; print "  - name: " proxy_name; print "    type: trojan"; print "    server:", server_value; print "    port:", listen_port; print "    password:", user_password; print "    udp: true"; print "    sni:", server_name; print "    skip-cert-verify:", tls_insecure; print "    alpn:"; print "      - h2"; print "      - http/1.1"; print ""; next} /- name: Proxy/ { print; flag_proxy=1; next } flag_proxy && flag_proxy++ == 3 { print "      - " proxy_name } /- name: auto/ { print; flag_auto=1; next } flag_auto && flag_auto++ == 3 { print "      - " proxy_name } 1' "$filename" > temp_file && mv temp_file "$filename"
}

function generate_trojan_ws_tls_yaml() {
    local filename="/usr/local/etc/sing-box/clash.yaml"
    local server_name="$domain"
    local proxy_name
    local server_value
    local tls_insecure
    if [ -z "$domain" ]; then
        server_name="$domain_name"
        server_value="$local_ip"
        tls_insecure="true"
    else
        server_value="$domain"
        tls_insecure="false"
    fi
    while true; do
        proxy_name="trojan-ws-tls-$(head /dev/urandom | tr -dc '0-9' | head -c 4)"
        if ! grep -q "name: $proxy_name" "$filename"; then
            break
        fi
    done
    awk -v proxy_name="$proxy_name" -v server_value="$server_value" -v server_name="$server_name" -v listen_port="$listen_port" -v user_password="$user_password" -v transport_path="$transport_path" -v tls_insecure="$tls_insecure" '/^proxies:$/ {print; print "  - name: " proxy_name; print "    type: trojan"; print "    server:", server_value; print "    port:", listen_port; print "    password:", "\"" user_password "\""; print "    network: ws"; print "    sni:", server_name; print "    skip-cert-verify:", tls_insecure; print "    udp: true"; print "    ws-opts:"; print "      path:", transport_path; print ""; next} /- name: Proxy/ { print; flag_proxy=1; next } flag_proxy && flag_proxy++ == 3 { print "      - " proxy_name } /- name: auto/ { print; flag_auto=1; next } flag_auto && flag_auto++ == 3 { print "      - " proxy_name } 1' "$filename" > temp_file && mv temp_file "$filename"
}

function generate_trojan_grpc_tls_yaml() {
    local filename="/usr/local/etc/sing-box/clash.yaml"
    local server_name="$domain"
    local proxy_name
    local server_value
    local tls_insecure
    if [ -z "$domain" ]; then
        server_name="$domain_name"
        server_value="$local_ip"
        tls_insecure="true"
    else
        server_value="$domain"
        tls_insecure="false"
    fi
    while true; do
        proxy_name="trojan-grpc-tls-$(head /dev/urandom | tr -dc '0-9' | head -c 4)"
        if ! grep -q "name: $proxy_name" "$filename"; then
            break
        fi
    done
    awk -v proxy_name="$proxy_name" -v server_value="$server_value" -v server_name="$server_name" -v listen_port="$listen_port" -v user_password="$user_password" -v transport_service_name="$transport_service_name" -v tls_insecure="$tls_insecure" '/^proxies:$/ {print; print "  - name: " proxy_name; print "    type: trojan"; print "    server:", server_value; print "    port:", listen_port; print "    password:", "\"" user_password "\""; print "    network: grpc"; print "    sni:", server_name; print "    udp: true"; print "    skip-cert-verify:", tls_insecure; print "    grpc-opts:"; print "      grpc-service-name:", "\"" transport_service_name "\""; print ""; next} /- name: Proxy/ { print; flag_proxy=1; next } flag_proxy && flag_proxy++ == 3 { print "      - " proxy_name } /- name: auto/ { print; flag_auto=1; next } flag_auto && flag_auto++ == 3 { print "      - " proxy_name } 1' "$filename" > temp_file && mv temp_file "$filename"
}

function generate_shadowtls_win_client_config() {
    local win_client_file="/usr/local/etc/sing-box/win_client.json"
    local proxy_name
    local shadowtls_out
    if [ -n "$multiplex_config" ] && [ -n "$brutal_config" ]; then
        multiplex_client_config=",\n      \"multiplex\": {\n        \"enabled\": true,\n        \"protocol\": \"h2mux\",\n        \"max_connections\": 1,\n        \"min_streams\": 4,\n        \"padding\": false,\n        \"brutal\": {\n          \"enabled\": true,\n          \"up_mbps\": $down_mbps,\n          \"down_mbps\": $up_mbps\n        }\n      }"
    elif [ -n "$multiplex_config" ] && [ -z "$brutal_config" ]; then
        multiplex_client_config=",\n      \"multiplex\": {\n        \"enabled\": true,\n        \"protocol\": \"h2mux\",\n        \"max_connections\": 1,\n        \"min_streams\": 4,\n        \"padding\": false\n      }"
    fi
    while true; do
        proxy_name="shadowtls-$(head /dev/urandom | tr -dc '0-9' | head -c 4)"
        shadowtls_out="stl-$(head /dev/urandom | tr -dc '0-9' | head -c 4)"
        if ! grep -q "name: $proxy_name" "$win_client_file" && ! grep -q "name: $shadowtls_out" "$win_client_file" && [ "$proxy_name" != "$shadowtls_out" ]; then
            break
        fi
    done
    awk -v shadowtls_out="$shadowtls_out" -v proxy_name="$proxy_name" -v method="$method" -v ss_password="$ss_password" -v local_ip="$local_ip" -v listen_port="$listen_port" -v stls_password="$stls_password" -v user_input="$user_input" -v multiplex_client_config="$multiplex_client_config" '
    /^  "outbounds": \[/ {print; getline; print "    {"; print "      \"type\": \"shadowsocks\","; print "      \"tag\": \"" proxy_name "\","; print "      \"method\": \"" method "\", "; print "      \"password\": \"" ss_password "\","; print "      \"detour\": \"" shadowtls_out "\""multiplex_client_config""; print "    },"; print "    {"; print "      \"type\": \"shadowtls\","; print "      \"tag\": \"" shadowtls_out "\","; print "      \"server\": \"" local_ip "\", "; print "      \"server_port\": " listen_port ","; print "      \"version\": 3, "; print "      \"password\": \""stls_password"\", "; print "      \"tls\": {"; print "        \"enabled\": true,"; print "        \"server_name\": \"" user_input "\", "; print "        \"utls\": {"; print "          \"enabled\": true,"; print "          \"fingerprint\": \"chrome\" "; print "        }"; print "      }"; print "    },";} 
    /^      "outbounds": \[/ {print; getline; if ($0 ~ /^      \],$/) {print "        \"" proxy_name "\""} else {print "        \"" proxy_name "\", "} }    
    {print}' "$win_client_file" > "$win_client_file.tmp"
    mv "$win_client_file.tmp" "$win_client_file"
}

function generate_shadowtls_phone_client_config() {
    local phone_client_file="/usr/local/etc/sing-box/phone_client.json"
    local proxy_name
    local shadowtls_out
    if [ -n "$multiplex_config" ] && [ -n "$brutal_config" ]; then
        multiplex_client_config=",\n      \"multiplex\": {\n        \"enabled\": true,\n        \"protocol\": \"h2mux\",\n        \"max_connections\": 1,\n        \"min_streams\": 4,\n        \"padding\": false,\n        \"brutal\": {\n          \"enabled\": true,\n          \"up_mbps\": $down_mbps,\n          \"down_mbps\": $up_mbps\n        }\n      }"
    elif [ -n "$multiplex_config" ] && [ -z "$brutal_config" ]; then
        multiplex_client_config=",\n      \"multiplex\": {\n        \"enabled\": true,\n        \"protocol\": \"h2mux\",\n        \"max_connections\": 1,\n        \"min_streams\": 4,\n        \"padding\": false\n      }"
    fi
    while true; do
        proxy_name="shadowtls-$(head /dev/urandom | tr -dc '0-9' | head -c 4)"
        shadowtls_out="stl-$(head /dev/urandom | tr -dc '0-9' | head -c 4)"
        if ! grep -q "name: $proxy_name" "$phone_client_file" && ! grep -q "name: $shadowtls_out" "$phone_client_file" && [ "$proxy_name" != "$shadowtls_out" ]; then
            break
        fi
    done 
    awk -v shadowtls_out="$shadowtls_out" -v proxy_name="$proxy_name" -v method="$method" -v ss_password="$ss_password" -v local_ip="$local_ip" -v listen_port="$listen_port" -v stls_password="$stls_password" -v user_input="$user_input" -v multiplex_client_config="$multiplex_client_config" '
    /^  "outbounds": \[/ {print; getline; print "    {"; print "      \"type\": \"shadowsocks\","; print "      \"tag\": \"" proxy_name "\","; print "      \"method\": \"" method "\", "; print "      \"password\": \"" ss_password "\","; print "      \"detour\": \"" shadowtls_out "\""multiplex_client_config""; print "    },"; print "    {"; print "      \"type\": \"shadowtls\","; print "      \"tag\": \"" shadowtls_out "\","; print "      \"server\": \"" local_ip "\", "; print "      \"server_port\": " listen_port ","; print "      \"version\": 3, "; print "      \"password\": \""stls_password"\", "; print "      \"tls\": {"; print "        \"enabled\": true,"; print "        \"server_name\": \"" user_input "\", "; print "        \"utls\": {"; print "          \"enabled\": true,"; print "          \"fingerprint\": \"chrome\" "; print "        }"; print "      }"; print "    },";} 
    /^      "outbounds": \[/ {print; getline; if ($0 ~ /^      \],$/) {print "        \"" proxy_name "\""} else {print "        \"" proxy_name "\", "} }    
    {print}' "$phone_client_file" > "$phone_client_file.tmp"
  mv "$phone_client_file.tmp" "$phone_client_file"
}

function generate_shadowtls_yaml() {
    local filename="/usr/local/etc/sing-box/clash.yaml"
    local proxy_name
    while true; do
        proxy_name="shadowtls-$(head /dev/urandom | tr -dc '0-9' | head -c 4)"
        if ! grep -q "name: $proxy_name" "$filename"; then
            break
        fi
    done
    awk -v proxy_name="$proxy_name" -v method="$method" -v ss_password="$ss_password" -v local_ip="$local_ip" -v listen_port="$listen_port" -v stls_password="$stls_password" -v user_input="$user_input" '/^proxies:$/ {print; print "  - name: " proxy_name; print "    type: ss"; print "    server:", local_ip; print "    port:", listen_port; print "    cipher:", method; print "    password:", "\"" ss_password "\""; print "    plugin: shadow-tls"; print "    plugin-opts:"; print "      host: \"" user_input "\""; print "      password:", "\"" stls_password "\""; print "      version: 3"; print ""; next} /- name: Proxy/ { print; flag_proxy=1; next } flag_proxy && flag_proxy++ == 3 { print "      - " proxy_name } /- name: auto/ { print; flag_auto=1; next } flag_auto && flag_auto++ == 3 { print "      - " proxy_name } 1' "$filename" > temp_file && mv temp_file "$filename"
}

function generate_naive_win_client_config() {
    local naive_client_file="$naive_client_filename"
    sed -i -e "s,user_name,$user_name," -e "s,user_password,$user_password," -e "s,listen_port,$listen_port," -e "s,server_name,$domain," "$naive_client_file"
    echo "电脑端配置文件已保存至$naive_client_file，请下载后使用！"
}

function extract_types_tags() {
    local config_file="/usr/local/etc/sing-box/config.json"
    filtered_tags=()
    types=()
    tags=($(jq -r '.inbounds[] | select(.tag != null) | .tag' "$config_file"))
    detour_tag=$(jq -r '.inbounds[] | select(.type == "shadowtls") | .detour' "$config_file")
    wireguard_type=$(jq -r '.outbounds[] | select(.type == "wireguard" and .tag == "wireguard-out") | .type' "$config_file")
    if [ -z "$tags" ] && [ -z "$wireguard_type" ]; then
        echo "未检测到节点配置，请搭建节点后再使用本选项！"
        exit 0
    fi
    filtered_tags=()
    for tag in "${tags[@]}"; do
        if [ "$tag" != "$detour_tag" ]; then
            filtered_tags+=("$tag")
        fi
    done
    max_length=0
    for tag in "${filtered_tags[@]}"; do
        tag_length=${#tag}
        if ((tag_length > max_length)); then
            max_length=$tag_length
        fi
    done
    for ((i=0; i<${#filtered_tags[@]}; i++)); do
        type=$(jq -r --arg tag "${filtered_tags[$i]}" '.inbounds[] | select(.tag == $tag) | .type' "$config_file")
        types[$i]=$type
        printf "%d).协议类型: %-20s 入站标签: %s\n" "$((i+1))" "$type" "${filtered_tags[$i]}"
    done
    if [ ! -z "$wireguard_type" ]; then
        types[$i]=$wireguard_type
        printf "%d).协议类型: %-20s 出站标签: %s\n" "$((i+1))" "$wireguard_type" "wireguard-out"
    fi
}

function delete_choice() {
    local config_file="/usr/local/etc/sing-box/config.json"
    local phone_client_file="/usr/local/etc/sing-box/phone_client.json"
    local win_client_file="/usr/local/etc/sing-box/win_client.json"
    local clash_yaml="/usr/local/etc/sing-box/clash.yaml"
    local output_file="/usr/local/etc/sing-box/output.txt"
    local temp_json="/usr/local/etc/sing-box/temp.json"
    local temp_yaml="/usr/local/etc/sing-box/temp.yaml"
    extract_types_tags
    valid_choice=false
    while [ "$valid_choice" == false ]; do
        read -p "请选择要删除的节点配置（输入对应的数字）: " choice
        if [[ ! $choice =~ ^[0-9]+$ || $choice -lt 1 || $choice -gt ${#types[@]} ]]; then
            echo -e "${RED}错误：无效的选择，请重新输入！${NC}"
        else
            valid_choice=true
        fi
    done
    selected_tag="${filtered_tags[$choice-1]}"
    selected_type="${types[$choice-1]}"
    listen_port=$(jq -r --arg selected_tag "$selected_tag" '.inbounds[] | select(.tag == $selected_tag) | .listen_port' "$config_file" | awk '{print int($0)}')
    if [ "$selected_type" == "wireguard" ]; then
        jq '.outbounds |= map(select(.tag != "warp-IPv4-out" and .tag != "warp-IPv6-out" and .tag != "wireguard-out"))' "$config_file" > "$temp_json"
        mv "$temp_json" "$config_file"
        jq '.route.rules |= map(select(.outbound != "warp-IPv4-out" and .outbound != "warp-IPv6-out"))' "$config_file" > "$temp_json"
        mv "$temp_json" "$config_file"
    else
        detour_tag=$(jq -r --arg selected_tag "$selected_tag" '.inbounds[] | select(.type == "shadowtls" and .tag == $selected_tag) | .detour' "$config_file")
        jq --arg selected_tag "$selected_tag" --arg detour_tag "$detour_tag" '.inbounds |= map(select(.tag != $selected_tag and .tag != $detour_tag))' "$config_file" > "$temp_json"
        mv "$temp_json" "$config_file"
        jq --arg selected_tag "$selected_tag" '.route.rules |= map(select(.inbound[0] != $selected_tag))' "$config_file" > "$temp_json"
        mv "$temp_json" "$config_file"
    fi
    if [ "$selected_type" != "wireguard" ]; then
        awk -v port="$listen_port" '$0 ~ "监听端口: " port {print; in_block=1; next} in_block && NF == 0 {in_block=0} !in_block' "$output_file" > "$output_file.tmp1"
        mv "$output_file.tmp1" "$output_file"
        awk -v port="$listen_port" '$0 ~ "监听端口: " port {start=NR; next} {lines[NR]=$0} END {for (i=1; i<=NR; i++) if (i < start - 4 || i > start) print lines[i]}' "$output_file" > "$output_file.tmp2"
        mv "$output_file.tmp2" "$output_file"
        sed -i '/./,$!d' "$output_file"
    fi
    if [ -f "$clash_yaml" ]; then
    get_clash_tags=$(awk '/proxies:/ {in_proxies_block=1} in_proxies_block && /- name:/ {name = $3} in_proxies_block && /port:/ {port = $2; print "Name:", name, "Port:", port}' "$clash_yaml" > "$temp_yaml")
    matching_clash_tag=$(grep "Port: $listen_port" "$temp_yaml" | awk '{print $2}')
    fi
    if [ -n "$listen_port" ]; then
        phone_matching_tag=$(jq -r --argjson listen_port "$listen_port" '.outbounds[] | select(.server_port == $listen_port) | .tag' "$phone_client_file")
        win_matching_tag=$(jq -r --argjson listen_port "$listen_port" '.outbounds[] | select(.server_port == $listen_port) | .tag' "$win_client_file")
    fi
    jq --arg tag "$phone_matching_tag" '.outbounds |= map(select(.tag != $tag))' "$phone_client_file" > "$temp_json"
    mv "$temp_json" "$phone_client_file"
    jq --arg tag "$win_matching_tag" '.outbounds |= map(select(.tag != $tag))' "$win_client_file" > "$temp_json"
    mv "$temp_json" "$win_client_file"
    if [ -n "$matching_clash_tag" ] && [ "$selected_type" != "wireguard" ]; then
      sed -i "/^  - name: $matching_clash_tag$/,/^\s*$/d" "$clash_yaml"
      sed -i "/proxy-groups:/,/^\s*$/ {/      - $matching_clash_tag/d}" "$clash_yaml"
    fi
    phone_matching_detour=$(jq -r --arg phone_matching_tag "$phone_matching_tag" '.outbounds[] | select(.detour == $phone_matching_tag) | .detour' "$phone_client_file")
    win_matching_detour=$(jq -r --arg win_matching_tag "$win_matching_tag" '.outbounds[] | select(.detour == $win_matching_tag) | .detour' "$win_client_file")
    phone_matching_detour_tag=$(jq -r --arg phone_matching_detour "$phone_matching_detour" '.outbounds[] | select(.detour == $phone_matching_detour) | .tag' "$phone_client_file")
    win_matching_detour_tag=$(jq -r --arg win_matching_detour "$win_matching_detour" '.outbounds[] | select(.detour == $win_matching_detour) | .tag' "$win_client_file")
    awk -v phone_matching_tag="$phone_matching_tag" '!/^      "outbounds": \[$/,/^\s*]/{if (!($0 ~ "^ * \"" phone_matching_tag "\"")) print; else next; }' "$phone_client_file" > "$phone_client_file.tmp"
    mv "$phone_client_file.tmp" "$phone_client_file"
    awk -v win_matching_tag="$win_matching_tag" '!/^      "outbounds": \[$/,/^\s*]/{if (!($0 ~ "^ * \"" win_matching_tag "\"")) print; else next; }' "$win_client_file" > "$win_client_file.tmp"
    mv "$win_client_file.tmp" "$win_client_file"
    if [ "$phone_matching_tag" == "$phone_matching_detour" ]; then
        jq --arg phone_matching_detour "$phone_matching_detour" '.outbounds |= map(select(.detour != $phone_matching_detour))' "$phone_client_file" > "$temp_json"
        mv "$temp_json" "$phone_client_file"
        awk -v phone_matching_detour_tag="$phone_matching_detour_tag" '!/^      "outbounds": \[$/,/^\s*]/{if (!($0 ~ "^ * \"" phone_matching_detour_tag "\"")) print; else next; }' "$phone_client_file" > "$phone_client_file.tmp"
        mv "$phone_client_file.tmp" "$phone_client_file"
    fi
    if [ "$win_matching_tag" == "$win_matching_detour" ]; then
        jq --arg win_matching_detour "$win_matching_detour" '.outbounds |= map(select(.detour != $win_matching_detour))' "$win_client_file" > "$temp_json"
        mv "$temp_json" "$win_client_file"
        awk -v win_matching_detour_tag="$win_matching_detour_tag" '!/^      "outbounds": \[$/,/^\s*]/{if (!($0 ~ "^ * \"" win_matching_detour_tag "\"")) print; else next; }' "$win_client_file" > "$win_client_file.tmp"
        mv "$win_client_file.tmp" "$win_client_file"
    fi
    awk '{if ($0 ~ /],$/ && p ~ /,$/) sub(/,$/, "", p); if (NR > 1) print p; p = $0;}END{print p;}' "$phone_client_file" > "$phone_client_file.tmp"
    mv "$phone_client_file.tmp" "$phone_client_file"
    awk '{if ($0 ~ /],$/ && p ~ /,$/) sub(/,$/, "", p); if (NR > 1) print p; p = $0;}END{print p;}' "$win_client_file" > "$win_client_file.tmp"
    mv "$win_client_file.tmp" "$win_client_file"
    [ -f "$temp_yaml" ] && rm "$temp_yaml"
    if ! jq -e 'select(.inbounds[] | .listen == "::")' "$config_file" > /dev/null; then
        sed -i 's/"rules": \[\]/"rules": [\n    ]/' "$config_file"
        sed -i 's/^  "inbounds": \[\],/  "inbounds": [\n  ],/' "$config_file"
        sed -i 's/^      "outbounds": \[\],/      "outbounds": [\n      ],/' "$win_client_file"
        sed -i 's/^      "outbounds": \[\],/      "outbounds": [\n      ],/' "$phone_client_file"
    fi
    systemctl restart sing-box
    echo "已删除 $selected_type 的配置信息，服务端及客户端配置信息已更新，请下载新的配置文件使用！"
}

function display_naive_config_info() {
    local config_file="/usr/local/etc/sing-box/config.json"
    local output_file="/usr/local/etc/sing-box/output.txt" 
    local num_users=${#user_names[@]}
    echo -e "${CYAN}NaiveProxy 节点配置信息：${NC}"  | tee -a "$output_file"
    echo -e "${CYAN}==============================================================================${NC}"  | tee -a "$output_file"
    echo "服务器地址: $domain"  | tee -a "$output_file"
    echo -e "${CYAN}------------------------------------------------------------------------------${NC}"  | tee -a "$output_file"        
    echo "监听端口: $listen_port"  | tee -a "$output_file"
    echo -e "${CYAN}------------------------------------------------------------------------------${NC}"  | tee -a "$output_file"
    echo "用 户 名                                  密  码"  | tee -a "$output_file"
    echo "------------------------------------------------------------------------------"  | tee -a "$output_file"
    for ((i=0; i<num_users; i++)); do
        local user_name="${user_names[i]}"
        local user_password="${user_passwords[i]}"       
        printf "%-38s %s\n" "$user_name" "$user_password" | tee -a "$output_file"
    done      
    echo -e "${CYAN}==============================================================================${NC}"  | tee -a "$output_file"
    echo "" >> "$output_file"
    echo "配置信息已保存至 $output_file" 
}

function generate_naive_config_files() {
    local config_file="/usr/local/etc/sing-box/config.json"
    local naive_client_file="$naive_client_filename"
    local num_users=${#user_names[@]}     
    for ((i=0; i<num_users; i++)); do
        local user_name="${user_names[i]}"
        local user_password="${user_passwords[i]}"        
        generate_naive_random_filename
        write_naive_client_file
        generate_naive_win_client_config "$user_name" "$user_password" "$listen_port" "$domain"        
    done
}

function display_Direct_config() {
    local config_file="/usr/local/etc/sing-box/config.json"
    local output_file="/usr/local/etc/sing-box/output.txt"
    local override_address=$(jq -r '.inbounds[0].override_address' "$config_file")    
    if [[ -n "$ip_v4" ]]; then
        local_ip="$ip_v4"
    elif [[ -n "$ip_v6" ]]; then
        local_ip="$ip_v6"
    fi
    echo -e "${CYAN}Direct 节点配置信息：${NC}" | tee -a "$output_file"
    echo -e "${CYAN}==============================================================================${NC}"  | tee -a "$output_file"
    echo "中转地址: $local_ip" | tee -a "$output_file"
    echo -e "${CYAN}------------------------------------------------------------------------------${NC}"  | tee -a "$output_file"
    echo "监听端口: $listen_port" | tee -a "$output_file"
    echo -e "${CYAN}------------------------------------------------------------------------------${NC}"  | tee -a "$output_file"
    echo "目标地址: $override_address" | tee -a "$output_file"
    echo -e "${CYAN}------------------------------------------------------------------------------${NC}"  | tee -a "$output_file"
    echo "目标端口: $override_port" | tee -a "$output_file"
    echo -e "${CYAN}==============================================================================${NC}"  | tee -a "$output_file"
    echo "" >> "$output_file"
    echo "配置信息已保存至 $output_file"
}

function display_juicity_config() {
    local config_file="/usr/local/etc/juicity/config.json"
    local output_file="/usr/local/etc/juicity/output.txt"
    local server_address
    local congestion_control=$(jq -r '.congestion_control' "$config_file")
    if [[ -n "$ip_v4" ]]; then
        local_ip="$ip_v4"
    elif [[ -n "$ip_v6" ]]; then
        local_ip="$ip_v6"
    fi
    if [ -z "$domain" ]; then
        server_address="$local_ip"
    else
        server_address="$domain"
    fi
    echo -e "${CYAN}Juicity 节点配置信息：${NC}"  | tee -a "$output_file"     
    echo -e "${CYAN}==============================================================================${NC}"  | tee -a "$output_file"
    echo "服务器地址: $server_address"  | tee -a "$output_file"
    echo -e "${CYAN}------------------------------------------------------------------------------${NC}"  | tee -a "$output_file"
    echo "监听端口: $listen_port"  | tee -a "$output_file" 
    echo -e "${CYAN}------------------------------------------------------------------------------${NC}"  | tee -a "$output_file"  
    echo "UUID：$user_uuids         密码：$user_passwords      "  | tee -a "$output_file" 
    echo -e "${CYAN}------------------------------------------------------------------------------${NC}"  | tee -a "$output_file" 
    echo "拥塞控制算法: $congestion_control"  | tee -a "$output_file" 
    echo -e "${CYAN}==============================================================================${NC}"  | tee -a "$output_file"
    echo "" >> "$output_file"
    echo "分享链接："
    juicity-server generate-sharelink -c "$config_file"
    generate_juicity_win_client_config
    echo "配置信息已保存至 $output_file"
}

function display_http_config_info() {
    local config_file="/usr/local/etc/sing-box/config.json"
    local output_file="/usr/local/etc/sing-box/output.txt"
    local num_users=${#user_names[@]}
    local server_address
    if [[ -n "$ip_v4" ]]; then
        local_ip="$ip_v4"
    elif [[ -n "$ip_v6" ]]; then
        local_ip="$ip_v6"
    fi
    if [ -z "$domain" ]; then
        server_address="$local_ip"
    else
        server_address="$domain"
    fi
    echo -e "${CYAN}HTTP 节点配置信息：${NC}"  | tee -a "$output_file"     
    echo -e "${CYAN}==============================================================================${NC}"  | tee -a "$output_file"
    echo "服务器地址: $server_address"  | tee -a "$output_file"
    echo -e "${CYAN}------------------------------------------------------------------------------${NC}"  | tee -a "$output_file"        
    echo "监听端口: $listen_port"  | tee -a "$output_file"
    echo -e "${CYAN}------------------------------------------------------------------------------${NC}"  | tee -a "$output_file"
    echo "用 户 名                                  密  码"  | tee -a "$output_file"
    echo "------------------------------------------------------------------------------"  | tee -a "$output_file"
    for ((i=0; i<num_users; i++)); do
        local user_name="${user_names[i]}"
        local user_password="${user_passwords[i]}"       
        printf "%-38s %s\n" "$user_name" "$user_password" | tee -a "$output_file"
    done      
    echo -e "${CYAN}==============================================================================${NC}"  | tee -a "$output_file"
    echo "" >> "$output_file"
    echo "配置信息已保存至 $output_file" 
}

function display_http_config_files() {
    local config_file="/usr/local/etc/sing-box/config.json"
    local clash_file="/usr/local/etc/sing-box/clash.yaml" 
    local phone_client_file="/usr/local/etc/sing-box/phone_client.json" 
    local win_client_file="/usr/local/etc/sing-box/win_client.json" 
    for ((i=0; i<${#user_passwords[@]}; i++)); do
        user_password="${user_passwords[$i]}"
        if [ "$enable_ech" = true ]; then
            write_phone_client_file
            write_win_client_file
            generate_http_win_client_config "$user_password"
            generate_http_phone_client_config "$user_password"
        else
            write_phone_client_file
            write_win_client_file
            generate_http_win_client_config "$user_password"
            generate_http_phone_client_config "$user_password"
            ensure_clash_yaml
            write_clash_yaml
            generate_http_yaml
        fi
    done
    if [ "$enable_ech" = true ]; then
        echo "手机端配置文件已保存至$phone_client_file，请下载后使用！"
        echo "电脑端配置文件已保存至$win_client_file，请下载后使用！"
    else
        echo "手机端配置文件已保存至$phone_client_file，请下载后使用！"
        echo "电脑端配置文件已保存至$win_client_file，请下载后使用！"
        echo "Clash配置文件已保存至 $clash_file ,请下载使用！"
    fi
}

function display_tuic_config_info() {
    local config_file="/usr/local/etc/sing-box/config.json"
    local output_file="/usr/local/etc/sing-box/output.txt"
    local server_address
    local congestion_control=$(jq -r '.inbounds[0].congestion_control' "$config_file")
    local alpn=$(jq -r '.inbounds[0].tls.alpn[0]' "$config_file")
    if [[ -n "$ip_v4" ]]; then
        local_ip="$ip_v4"
    elif [[ -n "$ip_v6" ]]; then
        local_ip="$ip_v6"
    fi
    if [ -z "$domain" ]; then
        server_address="$local_ip"
    else
        server_address="$domain"
    fi
    echo -e "${CYAN}TUIC 节点配置信息：${NC}"  | tee -a "$output_file"     
    echo -e "${CYAN}==============================================================================${NC}"  | tee -a "$output_file"  
    echo "服务器地址: $server_address"  | tee -a "$output_file"
    echo -e "${CYAN}------------------------------------------------------------------------------${NC}"  | tee -a "$output_file"      
    echo "监听端口: $listen_port"  | tee -a "$output_file" 
    echo -e "${CYAN}------------------------------------------------------------------------------${NC}"  | tee -a "$output_file"  
    echo "用户密码列表:"  | tee -a "$output_file" 
    echo "------------------------------------------------------------------------------"  | tee -a "$output_file"
    echo "  用户名                    UUID                             密码"  | tee -a "$output_file" 
    echo "------------------------------------------------------------------------------"  | tee -a "$output_file" 
    for ((i=0; i<${#user_names[@]}; i++)); do
        user_name="${user_names[$i]}"
        user_uuid="${user_uuids[$i]}"
        user_password="${user_passwords[$i]}"
        printf "%-13s %-42s %s\n" "$user_name" "$user_uuid" "$user_password" | tee -a "$output_file"
    done 
    echo -e "${CYAN}------------------------------------------------------------------------------${NC}"  | tee -a "$output_file" 
    echo "拥塞控制算法: $congestion_control"  | tee -a "$output_file" 
    echo -e "${CYAN}------------------------------------------------------------------------------${NC}"  | tee -a "$output_file" 
    echo "ALPN: $alpn"  | tee -a "$output_file"     
    echo -e "${CYAN}==============================================================================${NC}"  | tee -a "$output_file"
    echo "" >> "$output_file"
    echo "配置信息已保存至 $output_file" 
}

function display_tuic_config_files() {
    local config_file="/usr/local/etc/sing-box/config.json"
    local clash_file="/usr/local/etc/sing-box/clash.yaml" 
    local phone_client_file="/usr/local/etc/sing-box/phone_client.json" 
    local win_client_file="/usr/local/etc/sing-box/win_client.json"        
    local congestion_control=$(jq -r '.inbounds[0].congestion_control' "$config_file")
    local alpn=$(jq -r '.inbounds[0].tls.alpn[0]' "$config_file")
    local num_users=${#user_uuids[@]} 
    for ((i=0; i<num_users; i++)); do
        local user_uuid="${user_uuids[i]}"
        local user_password="${user_passwords[i]}"
        if [ "$enable_ech" = true ]; then
            write_phone_client_file
            write_win_client_file        
            generate_tuic_win_client_config "$user_uuid" "$user_password"
            generate_tuic_phone_client_config "$user_uuid" "$user_password"
        else
            write_phone_client_file
            write_win_client_file        
            generate_tuic_win_client_config "$user_uuid" "$user_password"
            generate_tuic_phone_client_config "$user_uuid" "$user_password"
            ensure_clash_yaml
            write_clash_yaml
            generate_tuic_yaml
        fi
    done
    if [ "$enable_ech" = true ]; then
        echo "手机端配置文件已保存至$phone_client_file，请下载后使用！"
        echo "电脑端配置文件已保存至$win_client_file，请下载后使用！"
    else
        echo "手机端配置文件已保存至$phone_client_file，请下载后使用！"
        echo "电脑端配置文件已保存至$win_client_file，请下载后使用！"
        echo "Clash配置文件已保存至 $clash_file ,请下载使用！"
    fi
}

function display_Shadowsocks_config_info() {
    local config_file="/usr/local/etc/sing-box/config.json"
    local output_file="/usr/local/etc/sing-box/output.txt"        
    local ss_method=$(jq -r '.inbounds[0].method' "$config_file")
    if [[ -n "$ip_v4" ]]; then
        local_ip="$ip_v4"
    elif [[ -n "$ip_v6" ]]; then
        local_ip="$ip_v6"
    fi
    echo -e "${CYAN}Shadowsocks 节点配置信息：${NC}"  | tee -a "$output_file"
    echo -e "${CYAN}==============================================================================${NC}"  | tee -a "$output_file"
    echo "服务器地址: $local_ip"  | tee -a "$output_file"
    echo -e "${CYAN}------------------------------------------------------------------------------${NC}"  | tee -a "$output_file"
    echo "监听端口: $listen_port"  | tee -a "$output_file"
    echo -e "${CYAN}------------------------------------------------------------------------------${NC}"  | tee -a "$output_file"
    echo "加密方式: $ss_method"  | tee -a "$output_file"
    echo -e "${CYAN}------------------------------------------------------------------------------${NC}"  | tee -a "$output_file"
    echo "密码: $ss_passwords"  | tee -a "$output_file"
    echo -e "${CYAN}==============================================================================${NC}"  | tee -a "$output_file"
    echo "" >> "$output_file"
    echo "配置信息已保存至 $output_file"  
}

function display_Shadowsocks_config_files() {
    local config_file="/usr/local/etc/sing-box/config.json"
    local clash_file="/usr/local/etc/sing-box/clash.yaml" 
    local phone_client_file="/usr/local/etc/sing-box/phone_client.json" 
    local win_client_file="/usr/local/etc/sing-box/win_client.json"         
    local ss_method=$(jq -r '.inbounds[0].method' "$config_file")
    if [[ -n "$ip_v4" ]]; then
        local_ip="$ip_v4"
    elif [[ -n "$ip_v6" ]]; then
        local_ip="$ip_v6"
    fi 
    write_phone_client_file
    write_win_client_file
    generate_shadowsocks_win_client_config
    generate_shadowsocks_phone_client_config
    ensure_clash_yaml
    write_clash_yaml
    generate_shadowsocks_yaml 
    echo "手机端配置文件已保存至$phone_client_file，请下载后使用！"
    echo "电脑端配置文件已保存至$win_client_file，请下载后使用！"
    echo "Clash配置文件已保存至 $clash_file ,请下载使用！"  
}

function display_socks_config_info() {
    local config_file="/usr/local/etc/sing-box/config.json"
    local output_file="/usr/local/etc/sing-box/output.txt"        
    if [[ -n "$ip_v4" ]]; then
        local_ip="$ip_v4"
    elif [[ -n "$ip_v6" ]]; then
        local_ip="$ip_v6"
    fi
    echo -e "${CYAN}SOCKS 节点配置信息：${NC}"  | tee -a "$output_file"     
    echo -e "${CYAN}==============================================================================${NC}"  | tee -a "$output_file"  
    echo "服务器地址: $local_ip"  | tee -a "$output_file"
    echo -e "${CYAN}------------------------------------------------------------------------------${NC}"  | tee -a "$output_file"      
    echo "监听端口: $listen_port"  | tee -a "$output_file" 
    echo -e "${CYAN}------------------------------------------------------------------------------${NC}"  | tee -a "$output_file"  
    echo "用户密码列表:"  | tee -a "$output_file" 
    echo "------------------------------------------------------------------------------"  | tee -a "$output_file"
    echo "用户名                                 密码"  | tee -a "$output_file" 
    for ((i=0; i<${#user_names[@]}; i++)); do
        user_name="${user_names[$i]}"
        user_password="${user_passwords[$i]}"
        printf "%-35s %s\n" "$user_name" "$user_password" | tee -a "$output_file"
    done 
    echo -e "${CYAN}==============================================================================${NC}"  | tee -a "$output_file"
    echo "" >> "$output_file"
    echo "节点配置信息已保存至 $output_file"    
}

function display_socks_config_files() {
    local config_file="/usr/local/etc/sing-box/config.json"
    local clash_file="/usr/local/etc/sing-box/clash.yaml" 
    local phone_client_file="/usr/local/etc/sing-box/phone_client.json" 
    local win_client_file="/usr/local/etc/sing-box/win_client.json" 
    local num_users=${#user_names[@]}            
    if [[ -n "$ip_v4" ]]; then
        local_ip="$ip_v4"
    elif [[ -n "$ip_v6" ]]; then
        local_ip="$ip_v6"
    fi
    for ((i=0; i<num_users; i++)); do
      local user_name="${user_names[i]}"
      local user_password="${user_passwords[i]}"    
      write_phone_client_file
      write_win_client_file
      generate_socks_win_client_config "$user_name" "$user_password"
      generate_socks_phone_client_config "$user_name" "$user_password"
      ensure_clash_yaml
      write_clash_yaml
      generate_socks_yaml   
    done
    echo "手机端配置文件已保存至$phone_client_file，请下载后使用！"
    echo "电脑端配置文件已保存至$win_client_file，请下载后使用！"
    echo "Clash配置文件已保存至 $clash_file ,请下载使用！"   
}

function display_Hysteria_config_info() {
    local config_file="/usr/local/etc/sing-box/config.json"
    local output_file="/usr/local/etc/sing-box/output.txt"        
    local server_address   
    local alpn=$(jq -r '.inbounds[0].tls.alpn[0]' "$config_file")
    if [[ -n "$ip_v4" ]]; then
        local_ip="$ip_v4"
    elif [[ -n "$ip_v6" ]]; then
        local_ip="$ip_v6"
    fi
    if [ -z "$domain" ]; then
        server_address="$local_ip"
    else
        server_address="$domain"
    fi
    echo -e "${CYAN}Hysteria 节点配置信息：${NC}"  | tee -a "$output_file"
    echo -e "${CYAN}==============================================================================${NC}"  | tee -a "$output_file" 
    echo "服务器地址：$server_address"  | tee -a "$output_file"
    echo -e "${CYAN}------------------------------------------------------------------------------${NC}"  | tee -a "$output_file" 
    echo "监听端口：$listen_port"  | tee -a "$output_file"
    echo -e "${CYAN}------------------------------------------------------------------------------${NC}"  | tee -a "$output_file" 
    echo "上行速度：${up_mbps}Mbps"  | tee -a "$output_file"
    echo -e "${CYAN}------------------------------------------------------------------------------${NC}"  | tee -a "$output_file" 
    echo "下行速度：${down_mbps}Mbps"  | tee -a "$output_file"
    echo -e "${CYAN}------------------------------------------------------------------------------${NC}"  | tee -a "$output_file" 
    echo "ALPN：$alpn"  | tee -a "$output_file"
    echo -e "${CYAN}------------------------------------------------------------------------------${NC}"  | tee -a "$output_file"
    echo "用户名                                   密码"  | tee -a "$output_file" 
    echo "------------------------------------------------------------------------------"  | tee -a "$output_file"    
    for ((i=0; i<${#user_names[@]}; i++)); do
        user_name="${user_names[$i]}"
        user_password="${user_passwords[$i]}"
        printf "%-35s %s\n" "$user_name" "$user_password" | tee -a "$output_file"
    done
    if [ -n "$obfs_password" ]; then
    echo -e "${CYAN}------------------------------------------------------------------------------${NC}"  | tee -a "$output_file"
        echo "obfs混淆密码：$obfs_password"  | tee -a "$output_file"
    fi
    echo -e "${CYAN}==============================================================================${NC}"  | tee -a "$output_file"
    echo "" >> "$output_file"
    echo "配置信息已保存至 $output_file"   
}

function display_Hysteria_config_files() {
    local config_file="/usr/local/etc/sing-box/config.json"
    local clash_file="/usr/local/etc/sing-box/clash.yaml" 
    local phone_client_file="/usr/local/etc/sing-box/phone_client.json" 
    local win_client_file="/usr/local/etc/sing-box/win_client.json"              
    local alpn=$(jq -r '.inbounds[0].tls.alpn[0]' "$config_file")
    for ((i=0; i<${#user_passwords[@]}; i++)); do
        user_password="${user_passwords[$i]}"
        if [ "$enable_ech" = true ]; then
            write_phone_client_file
            write_win_client_file
            generate_Hysteria_win_client_config "$user_password"
            generate_Hysteria_phone_client_config "$user_password"
        else
            write_phone_client_file
            write_win_client_file
            generate_Hysteria_win_client_config "$user_password"
            generate_Hysteria_phone_client_config "$user_password"
            ensure_clash_yaml
            write_clash_yaml
            generate_Hysteria_yaml
        fi        
    done
    if [ "$enable_ech" = true ]; then
        echo "手机端配置文件已保存至$phone_client_file，请下载后使用！"
        echo "电脑端配置文件已保存至$win_client_file，请下载后使用！"
    else
        echo "手机端配置文件已保存至$phone_client_file，请下载后使用！"
        echo "电脑端配置文件已保存至$win_client_file，请下载后使用！"
        echo "Clash配置文件已保存至 $clash_file ,请下载使用！"
    fi 
}

function display_Hy2_config_info() {
    local config_file="/usr/local/etc/sing-box/config.json"
    local output_file="/usr/local/etc/sing-box/output.txt"         
    local server_address
    local alpn=$(jq -r '.inbounds[0].tls.alpn[0]' "$config_file")
    if [[ -n "$ip_v4" ]]; then
        local_ip="$ip_v4"
    elif [[ -n "$ip_v6" ]]; then
        local_ip="$ip_v6"
    fi
    if [ -z "$domain" ]; then
        server_address="$local_ip"
    else
        server_address="$domain"
    fi
    echo -e "${CYAN}Hysteria2 节点配置信息：${NC}"  | tee -a "$output_file"
    echo -e "${CYAN}==============================================================================${NC}"  | tee -a "$output_file" 
    echo "服务器地址：$server_address"  | tee -a "$output_file"
    echo -e "${CYAN}------------------------------------------------------------------------------${NC}"  | tee -a "$output_file" 
    echo "监听端口：$listen_port"  | tee -a "$output_file"
    echo -e "${CYAN}------------------------------------------------------------------------------${NC}"  | tee -a "$output_file" 
    echo "上行速度：${up_mbps}Mbps"  | tee -a "$output_file"
    echo -e "${CYAN}------------------------------------------------------------------------------${NC}"  | tee -a "$output_file" 
    echo "下行速度：${down_mbps}Mbps"  | tee -a "$output_file"
    echo -e "${CYAN}------------------------------------------------------------------------------${NC}"  | tee -a "$output_file" 
    echo "ALPN：$alpn"  | tee -a "$output_file"
    echo -e "${CYAN}------------------------------------------------------------------------------${NC}"  | tee -a "$output_file" 
    echo "用户名                                  密码"  | tee -a "$output_file" 
    echo "------------------------------------------------------------------------------"  | tee -a "$output_file"    
    for ((i=0; i<${#user_names[@]}; i++)); do
        user_name="${user_names[$i]}"
        user_password="${user_passwords[$i]}"
        printf "%-35s %s\n" "$user_name" "$user_password" | tee -a "$output_file"
    done
    if [ -n "$obfs_password" ]; then
    echo -e "${CYAN}------------------------------------------------------------------------------${NC}"  | tee -a "$output_file"
        echo "QUIC 流量混淆器密码：$obfs_password"  | tee -a "$output_file"
    fi
    echo -e "${CYAN}==============================================================================${NC}"  | tee -a "$output_file"
    echo "" >> "$output_file"
    echo "配置信息已保存至 $output_file"       
}

function display_Hy2_config_files() {
    local config_file="/usr/local/etc/sing-box/config.json"
    local clash_file="/usr/local/etc/sing-box/clash.yaml"  
    local phone_client_file="/usr/local/etc/sing-box/phone_client.json" 
    local win_client_file="/usr/local/etc/sing-box/win_client.json"
    local alpn=$(jq -r '.inbounds[0].tls.alpn[0]' "$config_file")
    for ((i=0; i<${#user_passwords[@]}; i++)); do
        user_password="${user_passwords[$i]}"
        if [ "$enable_ech" = true ]; then
            write_phone_client_file
            write_win_client_file
            generate_Hysteria2_win_client_config "$user_password"
            generate_Hysteria2_phone_client_config "$user_password"
        else
            write_phone_client_file
            write_win_client_file
            generate_Hysteria2_win_client_config "$user_password"
            generate_Hysteria2_phone_client_config "$user_password"
            ensure_clash_yaml
            write_clash_yaml
            generate_Hysteria2_yaml
        fi
    done
    if [ "$enable_ech" = true ]; then
        echo "手机端配置文件已保存至$phone_client_file，请下载后使用！"
        echo "电脑端配置文件已保存至$win_client_file，请下载后使用！"
    else
        echo "手机端配置文件已保存至$phone_client_file，请下载后使用！"
        echo "电脑端配置文件已保存至$win_client_file，请下载后使用！"
        echo "Clash配置文件已保存至 $clash_file ,请下载使用！"
    fi   
}

function display_reality_config_info() {
    local config_file="/usr/local/etc/sing-box/config.json"
    local output_file="/usr/local/etc/sing-box/output.txt"
    local flow_type=$(jq -r '.inbounds[0].users[0].flow' "$config_file")
    local transport_type=$(jq -r '.inbounds[0].transport.type' "$config_file")
    local server_name=$(jq -r '.inbounds[0].tls.server_name' "$config_file")
    local target_server=$(jq -r '.inbounds[0].tls.reality.handshake.server' "$config_file")
    local transport_service_name=$(jq -r '.inbounds[0].transport.service_name' "$config_file")    
    local lobal_public_key="$public_key" 
    if [[ -n "$ip_v4" ]]; then
        local_ip="$ip_v4"
    elif [[ -n "$ip_v6" ]]; then
        local_ip="$ip_v6"
    fi      
    if [[ "$flow_type" == "xtls-rprx-vision" ]]; then
        transport_type="tcp"
    fi
    echo -e "${CYAN}VLESS 节点配置信息：${NC}" | tee -a "$output_file"
    echo -e "${CYAN}==============================================================================${NC}"  | tee -a "$output_file"
    echo "服务器地址: $local_ip" | tee -a "$output_file"
    echo -e "${CYAN}------------------------------------------------------------------------------${NC}"  | tee -a "$output_file"
    echo "监听端口: $listen_port" | tee -a "$output_file"
    echo -e "${CYAN}------------------------------------------------------------------------------${NC}"  | tee -a "$output_file"
    echo "UUID列表:"  | tee -a "$output_file" 
    for ((i=0; i<${#user_uuids[@]}; i++)); do
        user_uuid="${user_uuids[$i]}"
        echo "$user_uuid"| tee -a "$output_file"
    done
    if [ -n "$flow_type" ]; then
        echo -e "${CYAN}------------------------------------------------------------------------------${NC}"  | tee -a "$output_file"
        echo "流控类型: $flow_type" | tee -a "$output_file"
    fi
    echo -e "${CYAN}------------------------------------------------------------------------------${NC}"  | tee -a "$output_file"
    if [ "$transport_type" != "null" ]; then
        echo "传输协议: $transport_type"  | tee -a "$output_file"
        if [ "$transport_type" == "ws" ]; then
            echo "路径: $transport_path"  | tee -a "$output_file"
        elif [ "$transport_type" == "httpupgrade" ]; then
            echo "路径: $transport_path"  | tee -a "$output_file"
        elif [ "$transport_type" == "grpc" ]; then
            echo "grpc-service-name: $transport_service_name"  | tee -a "$output_file"
        fi
    else
        echo "传输协议: tcp"  | tee -a "$output_file"
    fi
    if [ -n "$server_name" ] && [ "$server_name" != "null" ]; then
        echo -e "${CYAN}------------------------------------------------------------------------------${NC}"  | tee -a "$output_file"
        echo "ServerName: $server_name" | tee -a "$output_file"
    fi
    if [ -n "$target_server" ] && [ "$target_server" != "null" ]; then
        echo -e "${CYAN}------------------------------------------------------------------------------${NC}"  | tee -a "$output_file"
        echo "目标网站地址: $target_server" | tee -a "$output_file"
    fi
    if [ -n "$short_id" ]; then
        echo -e "${CYAN}------------------------------------------------------------------------------${NC}"  | tee -a "$output_file"
        echo "Short ID:" | tee -a "$output_file"
        for ((i=0; i<${#short_ids[@]}; i++)); do
            short_id="${short_ids[$i]}"
            echo "$short_id" | tee -a "$output_file"
        done
    fi
    if [ -n "$public_key" ]; then
        echo -e "${CYAN}------------------------------------------------------------------------------${NC}"  | tee -a "$output_file"
        echo "PublicKey: $public_key" | tee -a "$output_file"
    fi
    echo -e "${CYAN}==============================================================================${NC}"  | tee -a "$output_file"
    echo "" >> "$output_file"
    echo "配置信息已保存至 $output_file"     
}

function display_reality_config_files() {
    local config_file="/usr/local/etc/sing-box/config.json" 
    local clash_file="/usr/local/etc/sing-box/clash.yaml" 
    local phone_client_file="/usr/local/etc/sing-box/phone_client.json" 
    local win_client_file="/usr/local/etc/sing-box/win_client.json"
    local flow_type=$(jq -r '.inbounds[0].users[0].flow' "$config_file")
    local transport_type=$(jq -r '.inbounds[0].transport.type' "$config_file")
    local server_name=$(jq -r '.inbounds[0].tls.server_name' "$config_file")
    local target_server=$(jq -r '.inbounds[0].tls.reality.handshake.server' "$config_file")
    local transport_service_name=$(jq -r '.inbounds[0].transport.service_name' "$config_file")  
    local lobal_public_key="$public_key"
    if [[ -n "$ip_v4" ]]; then
        local_ip="$ip_v4"
    elif [[ -n "$ip_v6" ]]; then
        local_ip="$ip_v6"
    fi
    for ((i=0; i<${#user_uuids[@]}; i++)); do
        local user_uuid="${user_uuids[$i]}"
        write_phone_client_file
        write_win_client_file
        if [[ "$server_name" == "null" ]] && [[ "$transport_type" == "null" ]]; then
            ensure_clash_yaml
            write_clash_yaml
            generate_vless_tcp_yaml
            generate_vless_win_client_config
            generate_vless_phone_client_config
        elif [[ "$server_name" == "null" ]] && [[ "$transport_type" == "ws" ]]; then
            ensure_clash_yaml
            write_clash_yaml
            generate_vless_ws_yaml
            generate_vless_win_client_config
            generate_vless_phone_client_config
        elif [[ "$server_name" == "null" ]] && [[ "$transport_type" == "grpc" ]]; then
            ensure_clash_yaml
            write_clash_yaml
            generate_vless_grpc_yaml
            generate_vless_win_client_config
            generate_vless_phone_client_config
        elif [[ "$server_name" == "null" ]] && [[ "$transport_type" == "httpupgrade" ]]; then
            generate_vless_win_client_config
            generate_vless_phone_client_config
        fi
        for ((j=0; j<${#short_ids[@]}; j++)); do
            local short_id="${short_ids[$j]}" 
            write_phone_client_file
            write_win_client_file
            if [[ -n "$server_name" ]] && [[ "$server_name" != "null" ]] && [[ "$transport_type" == "null" ]]; then
                ensure_clash_yaml
                write_clash_yaml
                generate_vless_reality_vision_yaml
                generate_vless_win_client_config
                generate_vless_phone_client_config
            elif [[ -n "$server_name" ]] && [[ "$server_name" != "null" ]] && [[ "$transport_type" == "http" ]]; then
                generate_vless_win_client_config
                generate_vless_phone_client_config
            elif [[ -n "$server_name" ]] && [[ "$server_name" != "null" ]] && [[ "$transport_type" == "grpc" ]]; then
                ensure_clash_yaml
                write_clash_yaml
                generate_vless_reality_grpc_yaml
                generate_vless_win_client_config
                generate_vless_phone_client_config
            fi
        done
    done
    if [[ "$transport_type" != "http" && "$transport_type" != "httpupgrade" ]]; then
        echo "Clash配置文件已保存至 $clash_file，请下载使用！"
    fi    
    echo "手机端配置文件已保存至$phone_client_file，请下载后使用！"
    echo "电脑端配置文件已保存至$win_client_file，请下载后使用！"          
}

function display_vmess_config_info() {
    local config_file="/usr/local/etc/sing-box/config.json"
    local output_file="/usr/local/etc/sing-box/output.txt"
    local server_address
    local transport_type=$(jq -r '.inbounds[0].transport.type' "$config_file")
    local transport_path=$(jq -r '.inbounds[0].transport.path' "$config_file")  
    local transport_service_name=$(jq -r '.inbounds[0].transport.service_name' "$config_file")   
    if [[ -n "$ip_v4" ]]; then
        local_ip="$ip_v4"
    elif [[ -n "$ip_v6" ]]; then
        local_ip="$ip_v6"
    fi
    if [[ -z "$domain" && -n "$domain_name" ]]; then
        server_address="$local_ip"
    elif [[ -z "$domain" && -z "$domain_name" ]]; then
        server_address="$local_ip"
    elif [[ -n "$domain" ]]; then
        server_address="$domain"
    fi
    echo -e "${CYAN}VMess 节点配置信息：${NC}"  | tee -a "$output_file"
    echo -e "${CYAN}==============================================================================${NC}"  | tee -a "$output_file"    
    echo "服务器地址: $server_address"  | tee -a "$output_file"   
    echo -e "${CYAN}------------------------------------------------------------------------------${NC}"  | tee -a "$output_file"
    echo "监听端口: $listen_port"  | tee -a "$output_file"
    echo -e "${CYAN}------------------------------------------------------------------------------${NC}"  | tee -a "$output_file"    
    echo "UUID列表:"  | tee -a "$output_file" 
    echo "------------------------------------------------------------------------------"  | tee -a "$output_file"
    for ((i=0; i<${#user_uuids[@]}; i++)); do
        user_uuid="${user_uuids[$i]}"
        echo "$user_uuid"| tee -a "$output_file"
    done  
    echo -e "${CYAN}------------------------------------------------------------------------------${NC}"  | tee -a "$output_file"    
    if [ "$transport_type" != "null" ]; then
        echo "传输协议: $transport_type"  | tee -a "$output_file"
        if [ "$transport_type" == "ws" ]; then
            echo "路径: $transport_path"  | tee -a "$output_file"
        elif [ "$transport_type" == "httpupgrade" ]; then
            echo "路径: $transport_path"  | tee -a "$output_file"
        elif [ "$transport_type" == "grpc" ]; then
            echo "grpc-service-name: $transport_service_name"  | tee -a "$output_file"
        fi
    else
        echo "传输协议: tcp"  | tee -a "$output_file"
    fi
    echo -e "${CYAN}==============================================================================${NC}"  | tee -a "$output_file"
    echo "" >> "$output_file"
    echo "配置信息已保存至 $output_file"  
}

function display_vmess_config_files() {
    local config_file="/usr/local/etc/sing-box/config.json"
    local clash_file="/usr/local/etc/sing-box/clash.yaml" 
    local phone_client_file="/usr/local/etc/sing-box/phone_client.json" 
    local win_client_file="/usr/local/etc/sing-box/win_client.json"
    local transport_type=$(jq -r '.inbounds[0].transport.type' "$config_file")
    local transport_path=$(jq -r '.inbounds[0].transport.path' "$config_file")  
    local transport_service_name=$(jq -r '.inbounds[0].transport.service_name' "$config_file")   
    local show_clash_message=true
    if [[ -n "$ip_v4" ]]; then
        local_ip="$ip_v4"
    elif [[ -n "$ip_v6" ]]; then
        local_ip="$ip_v6"
    fi     
    for ((i=0; i<${#user_uuids[@]}; i++)); do
        user_uuid="${user_uuids[$i]}"
        write_phone_client_file
        write_win_client_file
        generate_vmess_win_client_config
        generate_vmess_phone_client_config
        if [ "$enable_ech" != true ] && [ -z "$domain" ] && [ -z "$domain_name" ] && [ "$transport_type" == "null" ]; then
            ensure_clash_yaml
            write_clash_yaml
            generate_vmess_tcp_yaml
        elif [ "$enable_ech" != true ] && [ -z "$domain" ] && [ -z "$domain_name" ] && [ "$transport_type" == "ws" ]; then
            ensure_clash_yaml
            write_clash_yaml
            generate_vmess_ws_yaml
        elif [ "$enable_ech" != true ] && [ -z "$domain" ] && [ -z "$domain_name" ] && [ "$transport_type" == "grpc" ]; then
            ensure_clash_yaml
            write_clash_yaml
            generate_vmess_grpc_yaml
        elif [ "$enable_ech" != true ] && [[ -n "$domain" || -n "$domain_name" ]] && [ "$transport_type" == "null" ]; then
            ensure_clash_yaml
            write_clash_yaml
            generate_vmess_tcp_tls_yaml
        elif [ "$enable_ech" != true ] && [[ -n "$domain" || -n "$domain_name" ]] && [ "$transport_type" == "ws" ]; then
            ensure_clash_yaml
            write_clash_yaml
            generate_vmess_ws_tls_yaml
        elif [ "$enable_ech" != true ] && [[ -n "$domain" || -n "$domain_name" ]] && [ "$transport_type" == "grpc" ]; then
            ensure_clash_yaml
            write_clash_yaml
            generate_vmess_grpc_tls_yaml
        elif [ "$enable_ech" != true ] && [[ -n "$domain" || -n "$domain_name" ]] && [ "$transport_type" == "http" ]; then
            show_clash_message=false
        fi               
    done
    if [ "$transport_type" == "http" ] || [ "$transport_type" == "httpupgrade" ] || [ "$enable_ech" = true ]; then
        echo "手机端配置文件已保存至$phone_client_file，请下载后使用！"
        echo "电脑端配置文件已保存至$win_client_file，请下载后使用！"
    else
        echo "手机端配置文件已保存至$phone_client_file，请下载后使用！"
        echo "电脑端配置文件已保存至$win_client_file，请下载后使用！"    
        echo "Clash配置文件已保存至 $clash_file，请下载使用！"
    fi
}

function display_trojan_config_info() {
    local config_file="/usr/local/etc/sing-box/config.json"
    local output_file="/usr/local/etc/sing-box/output.txt"          
    local server_address
    local transport_type=$(jq -r '.inbounds[0].transport.type' "$config_file")
    local transport_path=$(jq -r '.inbounds[0].transport.path' "$config_file")
    local transport_service_name=$(jq -r '.inbounds[0].transport.service_name' "$config_file")
    if [[ -n "$ip_v4" ]]; then
        local_ip="$ip_v4"
    elif [[ -n "$ip_v6" ]]; then
        local_ip="$ip_v6"
    fi
    if [[ -z "$domain" && -n "$domain_name" ]]; then
        server_address="$local_ip"
    elif [[ -z "$domain" && -z "$domain_name" ]]; then
        server_address="$local_ip"
    elif [[ -n "$domain" ]]; then
        server_address="$domain"
    fi
    echo -e "${CYAN}Trojan 节点配置信息：${NC}"  | tee -a "$output_file"
    echo -e "${CYAN}==============================================================================${NC}"  | tee -a "$output_file" 
    echo "服务器地址: $server_address"  | tee -a "$output_file"  
    echo -e "${CYAN}------------------------------------------------------------------------------${NC}"  | tee -a "$output_file"
    echo "监听端口: $listen_port"  | tee -a "$output_file"
    echo -e "${CYAN}------------------------------------------------------------------------------${NC}"  | tee -a "$output_file"
    echo "密码列表:"  | tee -a "$output_file" 
    echo "------------------------------------------------------------------------------"  | tee -a "$output_file"
    for ((i = 0; i < ${#user_passwords[@]}; i++)); do
        user_password="${user_passwords[i]}" 
        echo "$user_password"| tee -a "$output_file"
    done    
    echo -e "${CYAN}------------------------------------------------------------------------------${NC}"  | tee -a "$output_file"
    if [ "$transport_type" != "null" ]; then
        echo "传输协议: $transport_type"  | tee -a "$output_file"
        if [ "$transport_type" == "ws" ]; then
            echo "路径: $transport_path"  | tee -a "$output_file"
        elif [ "$transport_type" == "httpupgrade" ]; then
            echo "路径: $transport_path"  | tee -a "$output_file"
        elif [ "$transport_type" == "grpc" ]; then
            echo "grpc-service-name: $transport_service_name"  | tee -a "$output_file"
        fi
    else
        echo "传输协议: tcp"  | tee -a "$output_file"
    fi
    echo -e "${CYAN}==============================================================================${NC}"  | tee -a "$output_file"
    echo "" >> "$output_file"
    echo "配置信息已保存至 $output_file"
}

function display_trojan_config_files() {
    local config_file="/usr/local/etc/sing-box/config.json"
    local clash_file="/usr/local/etc/sing-box/clash.yaml" 
    local phone_client_file="/usr/local/etc/sing-box/phone_client.json" 
    local win_client_file="/usr/local/etc/sing-box/win_client.json"          
    local transport_type=$(jq -r '.inbounds[0].transport.type' "$config_file")
    local transport_path=$(jq -r '.inbounds[0].transport.path' "$config_file")
    local transport_service_name=$(jq -r '.inbounds[0].transport.service_name' "$config_file")
    if [[ -n "$ip_v4" ]]; then
        local_ip="$ip_v4"
    elif [[ -n "$ip_v6" ]]; then
        local_ip="$ip_v6"
    fi 
    for ((i = 0; i < ${#user_passwords[@]}; i++)); do
        user_password="${user_passwords[i]}"  
        write_phone_client_file
        write_win_client_file
        generate_trojan_win_client_config
        generate_trojan_phone_client_config
        if [[ "$enable_ech" != true ]] && [[ -n "$domain" || -n "$domain_name" ]] && [ "$transport_type" == "null" ]; then
            ensure_clash_yaml
            write_clash_yaml
            generate_trojan_tcp_tls_yaml
        elif [[ "$enable_ech" != true ]] && [[ -n "$domain" || -n "$domain_name" ]] && [ "$transport_type" == "ws" ]; then
            ensure_clash_yaml
            write_clash_yaml
            generate_trojan_ws_tls_yaml
        elif [[ "$enable_ech" != true ]] && [[ -n "$domain" || -n "$domain_name" ]] && [ "$transport_type" == "grpc" ]; then
            ensure_clash_yaml
            write_clash_yaml
            generate_trojan_grpc_tls_yaml
        fi       
    done
    if [[ "$enable_ech" != true ]] && [[ -n "$domain" || -n "$domain_name" ]] && [[ "$transport_type" != "http" || "$transport_type" != "httpupgrade" ]]; then
        echo "Clash配置文件已保存至 $clash_file，请下载使用！"
    fi    
    echo "手机端配置文件已保存至$phone_client_file，请下载后使用！"
    echo "电脑端配置文件已保存至$win_client_file，请下载后使用！" 
}

function display_shadowtls_config_info() {
    local config_file="/usr/local/etc/sing-box/config.json"
    local output_file="/usr/local/etc/sing-box/output.txt"     
    local user_input=$(jq -r '.inbounds[0].handshake.server' "$config_file")
    local method=$(jq -r '.inbounds[1].method' "$config_file")
    if [[ -n "$ip_v4" ]]; then
        local_ip="$ip_v4"
    elif [[ -n "$ip_v6" ]]; then
        local_ip="$ip_v6"
    fi
    echo -e "${CYAN}ShadowTLS 节点配置信息：${NC}" | tee -a "$output_file"
    echo -e "${CYAN}==============================================================================${NC}" | tee -a "$output_file"
    echo "服务器地址: $local_ip" | tee -a "$output_file"
    echo -e "${CYAN}------------------------------------------------------------------------------${NC}" | tee -a "$output_file"
    echo "监听端口: $listen_port" | tee -a "$output_file"
    echo -e "${CYAN}------------------------------------------------------------------------------${NC}" | tee -a "$output_file"
    echo "加密方式: $method" | tee -a "$output_file"    
    echo -e "${CYAN}------------------------------------------------------------------------------${NC}" | tee -a "$output_file"   
    echo "ShadowTLS用户名                  ShadowTLS密码"  | tee -a "$output_file" 
    echo "------------------------------------------------------------------------------"  | tee -a "$output_file" 
    for ((i = 0; i < ${#stls_passwords[@]}; i++)); do
        local stls_password="${stls_passwords[i]}" 
        printf "%-25s %s\n" "$user_name" "$stls_password" | tee -a "$output_file"
    done 
    echo -e "${CYAN}------------------------------------------------------------------------------${NC}" | tee -a "$output_file"
    echo "Shadowsocks 密码: $ss_passwords" | tee -a "$output_file"
    echo -e "${CYAN}------------------------------------------------------------------------------${NC}" | tee -a "$output_file"
    echo "握手服务器地址: $user_input" | tee -a "$output_file"
    echo -e "${CYAN}==============================================================================${NC}" | tee -a "$output_file"
    echo "" >> "$output_file"
    echo "配置信息已保存至 $output_file"      
}

function display_shadowtls_config_files() {
    local config_file="/usr/local/etc/sing-box/config.json"
    local clash_file="/usr/local/etc/sing-box/clash.yaml" 
    local phone_client_file="/usr/local/etc/sing-box/phone_client.json" 
    local win_client_file="/usr/local/etc/sing-box/win_client.json"
    local user_input=$(jq -r '.inbounds[0].handshake.server' "$config_file")
    local method=$(jq -r '.inbounds[1].method' "$config_file")
    for ((i = 0; i < ${#stls_passwords[@]}; i++)); do
        local stls_password="${stls_passwords[i]}" 
        write_phone_client_file
        write_win_client_file
        generate_shadowtls_win_client_config "$stls_password"
        generate_shadowtls_phone_client_config "$stls_password"
        ensure_clash_yaml
        write_clash_yaml
        generate_shadowtls_yaml          
    done
    echo "手机端配置文件已保存至$phone_client_file，请下载后使用！"
    echo "电脑端配置文件已保存至$win_client_file，请下载后使用！"
    echo "Clash配置文件已保存至 $clash_file ,请下载使用！"   
}

function view_saved_config() {
    local config_paths=(
        "/usr/local/etc/sing-box/output.txt"
        "/usr/local/etc/juicity/output.txt"
    )
    local found=false
    for path in "${config_paths[@]}"; do
        if [[ -f "$path" ]]; then
            echo "配置信息文件 ($path):"
            cat "$path"
            found=true
        fi
    done

    if [[ "$found" == false ]]; then
        echo "未找到保存的配置信息文件！"
    fi
}

function check_and_restart_services() {
    if [ -f "/etc/systemd/system/sing-box.service" ]; then
        systemctl restart sing-box.service
        systemctl status --no-pager sing-box.service
    fi
    if [ -f "/etc/systemd/system/juicity.service" ]; then
        systemctl restart juicity.service
        systemctl status --no-pager juicity.service
    fi    
}

function uninstall_sing_box() {
    echo "开始卸载 sing-box..."
    systemctl stop sing-box
    systemctl disable sing-box
    rm -rf /usr/local/bin/sing-box
    rm -rf /usr/local/etc/sing-box
    rm -rf /etc/systemd/system/sing-box.service
    systemctl daemon-reload
    echo "sing-box 卸载完成。"
}

function uninstall_juicity() {
    echo "开始卸载 juicity..."
    systemctl stop juicity.service
    systemctl disable juicity.service
    rm -rf /etc/systemd/system/juicity.service
    rm -rf /usr/local/etc/juicity
    rm -rf /usr/local/bin/juicity-server
    echo "juicity 卸载完成。"
}

function update_proxy_tool() {
    if [ -e /usr/local/bin/juicity-server ]; then
        install_latest_juicity
    fi
    if [ -e /usr/local/bin/sing-box ]; then
        select_sing_box_install_option
    fi
}

function uninstall() {
    local uninstall_sing_box=false
    local uninstall_juicity=false
    if [[ -f "/etc/systemd/system/sing-box.service" ]] || [[ -f "/usr/local/bin/sing-box" ]] || [[ -d "/usr/local/etc/sing-box/" ]]; then
        uninstall_sing_box=true
    fi
    if [[ -f "/etc/systemd/system/juicity.service" ]] || [[ -f "/usr/local/bin/juicity-server" ]] || [[ -d "/usr/local/etc/juicity/" ]]; then
        uninstall_juicity=true
    fi
    if [[ "$uninstall_sing_box" == true ]]; then
        uninstall_sing_box
    fi
    if [[ "$uninstall_juicity" == true ]]; then
        uninstall_juicity
    fi    
}

function check_wireguard_config() {
    local config_file="/usr/local/etc/sing-box/config.json"
    if grep -q "wireguard" "$config_file"; then
        echo -e "${RED}Warp 已安装，请勿重复安装！${NC}"
        exit 1
    fi
}

function Update_Script() {
    wget -O /root/singbox.sh https://raw.githubusercontent.com/TinrLin/script_installation/main/Install.sh
    chmod +x /root/singbox.sh 
}

function add_cron_job() {
    if command -v crontab > /dev/null && crontab -l | grep -q "singbox.sh"; then
        echo "Cron job already exists."
    else
        (crontab -l 2>/dev/null ; echo "0 2 * * 1 /bin/bash /root/singbox.sh >> /usr/local/etc/certificate.log 2>&1") | crontab -
        echo "Cron job added successfully."
    fi
}

function juicity_install() {
    configure_dns64
    enable_bbr
    create_juicity_folder  
    install_latest_juicity
    get_local_ip
    generate_juicity_config
    add_cron_job
    configure_juicity_service
    systemctl daemon-reload
    systemctl enable juicity.service
    systemctl start juicity.service
    systemctl restart juicity.service
    display_juicity_config
}

function Direct_install() {
    install_sing_box
    enable_bbr    
    log_outbound_config    
    set_listen_port
    set_override_address
    set_override_port
    generate_Direct_config
    modify_format_inbounds_and_outbounds
    modify_route_rules
    check_firewall_configuration 
    systemctl daemon-reload   
    systemctl enable sing-box
    systemctl start sing-box
    systemctl restart sing-box
    get_local_ip    
    display_Direct_config
}

function Shadowsocks_install() {
    install_sing_box
    enable_bbr
    log_outbound_config    
    set_listen_port
    select_encryption_method
    set_ss_password
    generate_ss_config
    modify_format_inbounds_and_outbounds
    modify_route_rules
    check_firewall_configuration 
    systemctl daemon-reload   
    systemctl enable sing-box   
    systemctl start sing-box
    systemctl restart sing-box
    get_local_ip
    display_Shadowsocks_config_info
    display_Shadowsocks_config_files
}

function socks_install() {
    install_sing_box
    enable_bbr    
    log_outbound_config    
    generate_socks_config
    modify_format_inbounds_and_outbounds
    modify_route_rules
    check_firewall_configuration 
    systemctl daemon-reload   
    systemctl enable sing-box   
    systemctl start sing-box
    systemctl restart sing-box
    get_local_ip
    display_socks_config_info
    display_socks_config_files
}

function NaiveProxy_install() {
    install_sing_box
    enable_bbr
    log_outbound_config        
    generate_naive_config
    add_cron_job
    modify_format_inbounds_and_outbounds  
    modify_route_rules  
    systemctl daemon-reload
    systemctl enable sing-box
    systemctl start sing-box
    systemctl restart sing-box
    display_naive_config_info
    generate_naive_config_files
}

function http_install() {
    install_sing_box
    enable_bbr
    log_outbound_config        
    generate_http_config
    add_cron_job
    modify_format_inbounds_and_outbounds  
    modify_route_rules  
    systemctl daemon-reload
    systemctl enable sing-box
    systemctl start sing-box
    systemctl restart sing-box
    display_http_config_info
    display_http_config_files
}

function tuic_install() {
    install_sing_box
    enable_bbr
    log_outbound_config    
    generate_tuic_config
    add_cron_job
    modify_format_inbounds_and_outbounds
    modify_route_rules  
    systemctl daemon-reload
    systemctl enable sing-box
    systemctl start sing-box
    systemctl restart sing-box
    get_local_ip 
    display_tuic_config_info
    display_tuic_config_files
}

function Hysteria_install() {
    install_sing_box
    enable_bbr  
    log_outbound_config    
    generate_Hysteria_config
    add_cron_job
    modify_format_inbounds_and_outbounds
    modify_route_rules 
    systemctl daemon-reload
    systemctl enable sing-box
    systemctl start sing-box
    systemctl restart sing-box
    display_Hysteria_config_info
    display_Hysteria_config_files
}

function shadowtls_install() {
    install_sing_box
    enable_bbr
    log_outbound_config 
    generate_shadowtls_config
    modify_format_inbounds_and_outbounds
    modify_route_rules
    check_firewall_configuration      
    systemctl daemon-reload
    systemctl enable sing-box
    systemctl start sing-box
    systemctl restart sing-box
    get_local_ip    
    display_shadowtls_config_info
    display_shadowtls_config_files
}

function reality_install() {
    install_sing_box
    enable_bbr
    log_outbound_config         
    generate_vless_config 
    modify_format_inbounds_and_outbounds
    modify_route_rules
    check_firewall_configuration              
    systemctl daemon-reload
    systemctl enable sing-box
    systemctl start sing-box
    systemctl restart sing-box
    get_local_ip    
    display_reality_config_info
    display_reality_config_files
}

function Hysteria2_install() {
    install_sing_box
    enable_bbr  
    log_outbound_config    
    generate_Hy2_config
    add_cron_job
    modify_format_inbounds_and_outbounds
    modify_route_rules
    systemctl daemon-reload
    systemctl enable sing-box
    systemctl start sing-box
    systemctl restart sing-box
    display_Hy2_config_info
    display_Hy2_config_files
}

function trojan_install() {
    install_sing_box
    enable_bbr 
    log_outbound_config
    generate_trojan_config 
    add_cron_job
    modify_format_inbounds_and_outbounds
    modify_route_rules
    systemctl daemon-reload      
    systemctl enable sing-box 
    systemctl start sing-box
    systemctl restart sing-box
    display_trojan_config_info
    display_trojan_config_files
}

function vmess_install() {
    install_sing_box
    enable_bbr
    log_outbound_config 
    get_local_ip
    generate_vmess_config
    add_cron_job
    modify_format_inbounds_and_outbounds
    modify_route_rules
    systemctl daemon-reload   
    systemctl enable sing-box
    systemctl start sing-box
    systemctl restart sing-box
    display_vmess_config_info
    display_vmess_config_files
}

function wireguard_install() {
    check_wireguard_config
    check_config_file_existence
    select_unlocked_items
    geosite=()
    update_geosite_array
    select_outbound
    update_route_file "$outbound"
    get_temp_config_file
    extract_variables_and_cleanup
    update_outbound_file
    systemctl restart sing-box
}

function Update_certificate() {
    get_local_ip 
    extract_tls_info
    validate_tls_info
    Reapply_certificates
} 

function main_menu() {
echo "╔════════════════════════════════════════════════════════════════════════╗"
echo -e "║ ${CYAN}作者${NC}： Mr. xiao                                                        ║"
echo -e "║ ${CYAN}博客地址${NC}: https://tinrlin.com                                          ║"
echo -e "║ ${CYAN}项目地址${NC}: https://github.com/TinrLin                                   ║"
echo -e "║ ${CYAN}Telegram 群组${NC}: https://t.me/mrxiao758                                  ║"
echo -e "║ ${CYAN}YouTube频道${NC}: https://youtube.com/@Mr_xiao502       Version：1.2        ║"
echo "╠════════════════════════════════════════════════════════════════════════╣"
echo "║ 请选择要执行的操作：                                                   ║"
echo -e "║${CYAN} [1]${NC}  SOCKS                             ${CYAN} [2]${NC}   Direct                   ║"
echo -e "║${CYAN} [3]${NC}  HTTP                              ${CYAN} [4]${NC}   VMess                    ║"
echo -e "║${CYAN} [5]${NC}  VLESS                             ${CYAN} [6]${NC}   TUIC                     ║"
echo -e "║${CYAN} [7]${NC}  Juicity                           ${CYAN} [8]${NC}   Trojan                   ║"
echo -e "║${CYAN} [9]${NC}  Hysteria                          ${CYAN} [10]${NC}  Hysteria2                ║"
echo -e "║${CYAN} [11]${NC} ShadowTLS                         ${CYAN} [12]${NC}  NaiveProxy               ║"
echo -e "║${CYAN} [13]${NC} Shadowsocks                       ${CYAN} [14]${NC}  WireGuard                ║"
echo -e "║${CYAN} [15]${NC} 查看节点信息                      ${CYAN} [16]${NC}  更新内核                 ║"
echo -e "║${CYAN} [17]${NC} 更新脚本                          ${CYAN} [18]${NC}  更新证书                 ║"
echo -e "║${CYAN} [19]${NC} 重启服务                          ${CYAN} [20]${NC}  节点管理                 ║"
echo -e "║${CYAN} [21]${NC} 卸载                              ${CYAN} [0]${NC}   退出                     ║"
echo "╚════════════════════════════════════════════════════════════════════════╝"

    local choice
    read -p "请选择 [0-21]: " choice

    case $choice in
        1)
            socks_install
            exit 0
            ;;
        2)
            Direct_install
            exit 0
            ;;
        3)
            http_install
            exit 0
            ;; 
        4)
            vmess_install
            exit 0
            ;;                      
        5)
            reality_install
            exit 0
            ;;
        6)
            tuic_install
            exit 0
            ;;
        7)
            juicity_install
            exit 0
            ;;                
        8)
            trojan_install
            exit 0
            ;;
        9)
            Hysteria_install
            exit 0
            ;;
        10)
            Hysteria2_install
            exit 0
            ;;
        11)
            shadowtls_install
            exit 0
            ;; 
        12)
            NaiveProxy_install
            exit 0
            ;;  
        13)
            Shadowsocks_install
            exit 0
            ;;
        14)
            wireguard_install
            exit 0
            ;;                                       
        15)
            view_saved_config
            exit 0
            ;;

        16)
            update_proxy_tool
            exit 0
            ;;
        17)
            Update_Script
            exit 0
            ;;   
        18)
            Update_certificate
            ;; 
        19)
            check_and_restart_services
            exit 0
            ;;
        20)
            delete_choice
            exit 0
            ;; 
        21)
            uninstall
            exit 0
            ;;                   
        0)
            echo "感谢使用 Mr. xiao 安装脚本！再见！"
            exit 0
            ;;
        *)
            echo -e "${RED}无效的选择，请重新输入。${NC}"
            main_menu
            ;;
    esac
}

function run_option() {
    case "$1" in
        "18")
            Update_certificate
            exit 0 
            ;;
    esac
}

if [ $# -eq 0 ]; then
    main_menu
else
    run_option "$1"
fi

main_menu
