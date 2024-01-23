### Sing-box executable file directory: /usr/local/bin/sing-box.
### The systemd service directory of sing-box: /etc/systemd/system/sing-box.service.
### Sing-box configuration file directory: /usr/local/etc/sing-box/config.json.
### Github.com/TinrLin/singbox 脚本备份
# **Script installation**
```bash
apt update && apt -y install curl wget tar socat net-tools jq git openssl uuid-runtime build-essential zlib1g-dev libssl-dev libevent-dev dnsutils cron
```
```bash
bash <(curl https://raw.githubusercontent.com/sw19999/singbox/main/singbox.sh.sh)
```
