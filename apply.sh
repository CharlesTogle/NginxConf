#!/usr/bin/env bash
set -euo pipefail

NGINX_AVAILABLE="/etc/nginx/sites-available"
NGINX_ENABLED="/etc/nginx/sites-enabled"
CONFIG_DIR="$(dirname "$0")/sites-available"
BIND_DIR="$(dirname "$0")/bind"
BIND_TARGET_DIR="/etc/bind"
TAILSCALE_IP="100.116.210.110"
TSNET_HOST="charles.auroch-kingsnake.ts.net"
FUNNEL_TARGET_PORT="80"
FUNNEL_PUBLIC_PORT="443"

sudo -v

if [[ ! -d "$CONFIG_DIR" ]]; then
    echo "No sites-available directory found next to this script."
    exit 1
fi

for conf in "$CONFIG_DIR"/*.conf; do
    name="$(basename "$conf")"

    echo "Installing $name ..."
    sudo cp "$conf" "$NGINX_AVAILABLE/$name"

    if [[ ! -L "$NGINX_ENABLED/$name" ]]; then
        sudo ln -s "$NGINX_AVAILABLE/$name" "$NGINX_ENABLED/$name"
        echo "  -> enabled"
    else
        echo "  -> already enabled"
    fi
done

echo "Testing nginx config ..."
sudo nginx -t

echo "Reloading nginx ..."
sudo systemctl reload nginx

if command -v tailscale >/dev/null 2>&1; then
    echo "Enabling Tailscale Funnel for HTTPS on $TSNET_HOST ..."
    sudo tailscale funnel --bg --https="$FUNNEL_PUBLIC_PORT" "$FUNNEL_TARGET_PORT"
    echo "Funnel now exposes only the nginx web entrypoint, not SSH."
fi

if [[ -d "$BIND_DIR" ]]; then
    for bind_conf in named.conf.options named.conf.local db.home; do
        source_file="$BIND_DIR/$bind_conf"

        if [[ ! -f "$source_file" ]]; then
            echo "Missing BIND config: $source_file"
            exit 1
        fi

        echo "Installing $bind_conf ..."
        sudo cp "$source_file" "$BIND_TARGET_DIR/$bind_conf"
    done

    echo "Testing bind config ..."
    sudo named-checkconf
    sudo named-checkzone home "$BIND_TARGET_DIR/db.home"

    echo "Reloading bind9 ..."
    sudo systemctl reload bind9
fi

if command -v ufw >/dev/null 2>&1; then
    echo "Applying UFW rules for tailscale-only DNS and web access ..."
    sudo ufw allow in on tailscale0 to "$TAILSCALE_IP" port 53 proto udp
    sudo ufw allow in on tailscale0 to "$TAILSCALE_IP" port 53 proto tcp
    sudo ufw allow in on tailscale0 to "$TAILSCALE_IP" port 80 proto tcp
    sudo ufw allow in on tailscale0 to "$TAILSCALE_IP" port 443 proto tcp
fi

echo "Done."
