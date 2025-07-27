#!/bin/bash

# --- Configuration ---
DOMAIN="104100.xyz"
EMAIL="your-email@example.com"  # Replace with your real email
WEBROOT="/var/www/${DOMAIN}"
NGINX_CONF="/etc/nginx/sites-available/${DOMAIN}"
NGINX_ENABLED="/etc/nginx/sites-enabled/${DOMAIN}"

# --- Step 1: Create webroot directory ---
echo "[1] Creating webroot at $WEBROOT"
sudo mkdir -p "$WEBROOT"
echo "<h1>Hello from $DOMAIN</h1>" | sudo tee "$WEBROOT/index.html" > /dev/null

# --- Step 2: Install Certbot & Get Certificate Using Webroot Method ---
echo "[2] Installing Certbot and requesting certificate..."
sudo apt update
sudo apt install -y certbot python3-certbot-nginx nginx

# Temporary minimal config just for certificate validation
echo "[2.1] Creating temporary HTTP config for Certbot validation..."
sudo tee "$NGINX_CONF" > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;

    root $WEBROOT;
    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

sudo ln -sf "$NGINX_CONF" "$NGINX_ENABLED"
sudo nginx -t && sudo systemctl reload nginx

# --- Step 3: Obtain SSL certificate ---
sudo certbot certonly --webroot -w "$WEBROOT" -d "$DOMAIN" -d "www.$DOMAIN" --non-interactive --agree-tos -m "$EMAIL"

# --- Step 4: Replace config with HTTPS-enabled version ---
echo "[4] Replacing Nginx config with SSL-enabled block..."
sudo tee "$NGINX_CONF" > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name $DOMAIN www.$DOMAIN;

    root $WEBROOT;
    index index.html;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

# --- Step 5: Reload Nginx with final config ---
echo "[5] Reloading Nginx..."
sudo nginx -t && sudo systemctl reload nginx

echo "✅ SSL setup complete. Visit https://$DOMAIN"
