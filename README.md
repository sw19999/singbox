### Sing-box executable file directory: /usr/local/bin/sing-box.
### The systemd service directory of sing-box: /etc/systemd/system/sing-box.service.
### Sing-box configuration file directory: /usr/local/etc/sing-box/config.json.
### Github.com/TinrLin/singbox 脚本备份
# **Script installation**

# **Install**
- **Debian&&Ubuntu use the following command to install dependencies**
```
apt update && apt -y install curl wget tar socat net-tools jq git openssl uuid-runtime build-essential zlib1g-dev libssl-dev libevent-dev dnsutils cron
```
- **CentOS uses the following command to install dependencies**
```
yum update && yum -y install curl wget tar socat net-tools jq git openssl util-linux gcc-c++ zlib-devel openssl-devel libevent-devel bind-utils cronie
```
```bash
bash <(curl https://raw.githubusercontent.com/sw19999/singbox/main/singbox.sh.sh)
```
