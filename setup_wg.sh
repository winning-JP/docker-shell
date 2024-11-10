#!/bin/bash

# Dockerのインストール確認とインストール
if command -v docker &> /dev/null
then
    echo "Dockerは既にインストールされています。インストールをスキップ。"
else
    echo "Dockerをインストールしています..."
    curl -sSL https://get.docker.com | sh

    if ! command -v docker &> /dev/null
    then
        echo "Dockerのインストールに失敗しました。終了します。"
        exit 1
    fi
fi

echo "SSH設定を更新し、rootログインとパスワード認証を許可しています..."
sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
if [ -f /etc/ssh/sshd_config.d/60-cloudimg-settings.conf ]; then
    sed -i 's/^PasswordAuthentication no/#PasswordAuthentication no/' /etc/ssh/sshd_config.d/60-cloudimg-settings.conf
fi

echo "SSHサービスを再起動しています..."
systemctl restart ssh

WG_HOST=$(curl -s api.ipify.org || curl -s ifconfig.me)
echo "docker-compose.ymlファイルを作成しています..."
echo "volumes:
  etc_wireguard:

services:
  wg-easy:
    environment:
      - LANG=ja
      - WG_HOST=${WG_HOST}
    image: ghcr.io/wg-easy/wg-easy
    container_name: wg-easy
    volumes:
      - etc_wireguard:/etc/wireguard
    ports:
      - \"51820:51820/udp\"
      - \"51821:51821/tcp\"
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    sysctls:
      - net.ipv4.ip_forward=1
      - net.ipv4.conf.all.src_valid_mark=1" > ~/docker-compose.yml

echo "docker-compose.ymlがrootディレクトリに作成されました。"

echo "自動で起動しています...(1分程度かかります)"
docker compose -p wg-easy -f ~/docker-compose.yml up -d

echo "セットアップが完了しました。"
echo "WireGuard WebGUI: http://${WG_HOST}:51821"
echo "WireGuard WebGUI: http://${WG_HOST}:51821" > /etc/motd
