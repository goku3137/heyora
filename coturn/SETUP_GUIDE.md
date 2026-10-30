# HeyOra Coturn TURN Server Setup & Deployment Guide

This guide details how to install and configure Coturn on an inexpensive Ubuntu VPS (~$4–$10/month on Hetzner, Contabo, or DigitalOcean) to serve as a WebRTC TURN relay fallback for carriers with strict symmetric NATs (e.g. Jio / Airtel / Vodafone).

---

## 1. Installation on Ubuntu 22.04 / 24.04 LTS

```bash
sudo apt-get update -y
sudo apt-get install coturn ufw -y
```

## 2. Firewall Port Configuration (UFW)

Open the standard STUN/TURN listening ports and the UDP relay port range:

```bash
# Standard STUN/TURN ports
sudo ufw allow 3478/tcp
sudo ufw allow 3478/udp
sudo ufw allow 5349/tcp
sudo ufw allow 5349/udp

# Dynamic UDP Relay Port Range
sudo ufw allow 49152:65535/udp

# SSH
sudo ufw allow 22/tcp

# Enable Firewall
sudo ufw enable
```

## 3. Configure Coturn

Copy [coturn.conf](file:///c:/CODE/FL/heyora/coturn/coturn.conf) to `/etc/turnserver.conf`:

```bash
sudo cp coturn.conf /etc/turnserver.conf
```

Edit `/etc/turnserver.conf` and set your server's external IP:
```ini
external-ip=YOUR_ACTUAL_VPS_PUBLIC_IP
```

Enable the Coturn service daemon in `/etc/default/coturn`:
```ini
TURNSERVER_ENABLED=1
```

## 4. Start and Enable Service

```bash
sudo systemctl restart coturn
sudo systemctl enable coturn
sudo systemctl status coturn
```

## 5. Free TLS/SSL Certificates (Optional for TURNS)

For encrypted TLS relay over port 5349:
```bash
sudo apt-get install certbot -y
sudo certbot certonly --standalone -d turn.yourdomain.com
```
Update `/etc/turnserver.conf` with:
```ini
cert=/etc/letsencrypt/live/turn.yourdomain.com/fullchain.pem
pkey=/etc/letsencrypt/live/turn.yourdomain.com/privkey.pem
```

## 6. Live Monitoring & Bandwidth Inspection

Monitor active TURN sessions and bandwidth in real-time:
```bash
# Check system connections
sudo netstat -anp | grep turnserver

# View live relay traffic
tail -f /var/log/coturn/turnserver.log
```
