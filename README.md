# Nginx + Tailscale Notes

This was a useful experiment that let me access my self-hosted cloud drive through Tailscale using private DNS, nginx routing, and tailnet-only access controls.

## What This Repo Is

`NginxConf` is a small infrastructure repo for my server-side nginx and DNS deployment files.

It acts as a source-of-truth for:

- nginx virtual host configs
- local BIND zone files for private DNS
- an `apply.sh` deploy script that installs those configs onto the server

## Purpose

The purpose of this repo is to make private self-hosted services easier to reach through human-friendly names instead of raw localhost ports or raw Tailscale IPs.

In practice, that means:

- turning names like `chat.charles.home` and `drive.charles.home` into working entrypoints
- routing requests through nginx to the correct backend service
- keeping access limited to devices inside Tailscale

## Low-Level Description

At a low level, this setup works like this:

- BIND answers private DNS queries for the `home` zone
- Tailscale Split DNS sends `*.home` requests to the BIND server at `100.116.210.110`
- nginx listens on the server's Tailscale IP
- nginx routes requests by hostname or path to the right local app
- UFW allows only the required DNS/HTTP/HTTPS ports on `tailscale0`

This repo now documents a private Tailscale-only setup where:

- `http://chat.charles.home` proxies to `127.0.0.1:4096`
- `http://drive.charles.home` serves the Drive frontend and proxies `/api/` to `127.0.0.1:3000`
- `https://charles.auroch-kingsnake.ts.net/chat/` can proxy into `chat.charles.home`
- `https://charles.auroch-kingsnake.ts.net/drive/` can proxy into `drive.charles.home`

Note: the correct hostname is `drive.charles.home`, not `charles.drive.home`.

## DNS Model

Two DNS systems are involved:

- local BIND DNS for `*.home`
- Tailscale DNS settings for tailnet clients

### Split DNS

Use Tailscale **Split DNS** when you want only a specific domain to resolve through your private DNS server.

For this setup:

- domain: `home`
- nameserver: `100.116.210.110`

That means Tailscale clients send `*.home` lookups to the BIND server on `100.116.210.110`.

### MagicDNS

MagicDNS is separate from Split DNS.

- MagicDNS gives Tailscale device names automatic DNS
- Split DNS forwards chosen domains to your own DNS server

You can leave MagicDNS off if you only want your own `*.home` zone.

## UFW Ports

These are the ports that mattered:

- `53/udp` for normal DNS lookups
- `53/tcp` for larger DNS responses and TCP fallback
- `80/tcp` for HTTP to nginx
- `443/tcp` for HTTPS to nginx

Rules used:

```bash
sudo ufw allow in on tailscale0 to 100.116.210.110 port 53 proto udp
sudo ufw allow in on tailscale0 to 100.116.210.110 port 53 proto tcp
sudo ufw allow in on tailscale0 to 100.116.210.110 port 80 proto tcp
sudo ufw allow in on tailscale0 to 100.116.210.110 port 443 proto tcp
```

Why not open `4096` and `5173`?

- those app ports stay internal
- nginx is the front door
- nginx routes by hostname or path

## How Routing Works

DNS does not carry ports.

This is wrong as a DNS idea:

- `chat.charles.home -> 100.116.210.110:4096`

This is the correct model:

- DNS maps `chat.charles.home -> 100.116.210.110`
- nginx receives the request on `80` or `443`
- nginx decides whether to proxy to `127.0.0.1:4096` or serve the Drive frontend

## Tailscale HTTPS

We tried using:

```bash
tailscale cert charles.auroch-kingsnake.ts.net
```

and hit this error:

- `500 Internal Server Error: your Tailscale account does not support getting TLS certs`

That means `tailscale cert` will not work unless your Tailscale account/tailnet supports HTTPS certificates.

### To make `tailscale cert` work

In the Tailscale admin settings, enable the feature that allows device HTTPS certificates.

What to look for:

- allow users to provision HTTPS certificates for devices
- HTTPS / TLS certificates for tailnet devices

If that feature is disabled or unavailable on the account plan, `tailscale cert` will fail and nginx cannot use Tailscale-issued cert files.

## Turning On HTTPS

There are three practical paths:

### 1. Tailscale-issued HTTPS

Works only if your tailnet supports cert provisioning.

Then nginx can use cert files for:

- `charles.auroch-kingsnake.ts.net`

### 2. Private CA / self-signed HTTPS

Works for private hostnames like:

- `chat.charles.home`
- `drive.charles.home`

But every client device must trust your CA/cert.

### 3. Real domain

Best option for clean trusted HTTPS if you want your own subdomains and public CA trust.

## /drive Hosting Lesson

`/drive` hosting is not just an nginx problem. The frontend build also has to support being mounted under a subpath.

The bug we hit was:

- browser requested `/assets/...`
- nginx returned HTML instead of JS
- browser blocked the module with a MIME-type error

Root cause:

- frontend was built for `/`
- but served under `/drive/`

### Fixes made in HomeServer-Lite

- Vite build base changed to `./`
- API URLs are resolved from the current page base instead of assuming root `/api/...`
- PDF preview/download links were updated to use resolved API URLs too

That lets the same frontend build work better under:

- `http://drive.charles.home`
- `https://charles.auroch-kingsnake.ts.net/drive/`

## Deploying `index.html` and Drive Frontend

The Drive app is served from:

- `/home/charles/home/HomeServer-Lite/frontend/dist`

That means after frontend changes, the server needs a rebuilt `dist/` deployed there.

If `/drive/` breaks, check these first:

- was the frontend rebuilt after changing Vite config?
- is the server serving `frontend/dist` and not an older `dist` folder?
- are generated asset paths relative or still root-based?

## Current Mental Model

- BIND answers `*.home`
- Tailscale Split DNS sends `home` queries to the BIND server
- nginx listens on the Tailscale IP
- UFW allows DNS/HTTP/HTTPS only on `tailscale0`
- `drive.charles.home` is the source route for the Drive app
- `charles.auroch-kingsnake.ts.net/drive/` can proxy into that route
