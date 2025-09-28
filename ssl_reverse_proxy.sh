#!/bin/bash

# --- Configuration ---
EMAIL="satyam@example.com"
DOMAINS=("x.104100.xyz")  # Add more subdomains if needed
BACKEND_URL="http://127.0.0.1:5000"  # Change to your backend service

# --- Step 1: Install Nginx & Certbot ---
echo "[1] Installing Nginx & Certbot..."
sudo apt update
sudo apt install -y nginx certbot python3-certbot-nginx

# --- Step 2: Loop over domains ---
for DOMAIN in "${DOMAINS[@]}"; do
    WEBROOT="/var/www/$DOMAIN"
    NGINX_CONF="/etc/nginx/sites-available/$DOMAIN"
    NGINX_ENABLED="/etc/nginx/sites-enabled/$DOMAIN"

    echo "----------------------------------------"
    echo "[*] Setting up $DOMAIN"
    echo "----------------------------------------"

    # Step 2.1: Create webroot (for Certbot validation)
    sudo mkdir -p "$WEBROOT"
    echo "<h1>Hello from $DOMAIN</h1>" | sudo tee "$WEBROOT/index.html" > /dev/null

    # Step 2.2: Temporary HTTP config for Certbot
    sudo tee "$NGINX_CONF" > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    root $WEBROOT;
    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

    sudo ln -sf "$NGINX_CONF" "$NGINX_ENABLED"
done

# Reload Nginx with temporary HTTP configs
sudo nginx -t && sudo systemctl reload nginx

# --- Step 3: Obtain SSL certificates ---
for DOMAIN in "${DOMAINS[@]}"; do
    echo "[3] Requesting SSL for $DOMAIN..."
    sudo certbot certonly --webroot -w "/var/www/$DOMAIN" -d "$DOMAIN" \
        --non-interactive --agree-tos -m "$EMAIL"
done

# --- Step 4: Replace with HTTPS + proxy_pass config ---
for DOMAIN in "${DOMAINS[@]}"; do
    NGINX_CONF="/etc/nginx/sites-available/$DOMAIN"
    sudo tee "$NGINX_CONF" > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    location / {
        proxy_pass $BACKEND_URL;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
done

# --- Step 5: Reload Nginx ---
sudo nginx -t && sudo systemctl reload nginx

echo "✅ SSL + reverse proxy setup complete for: ${DOMAINS[*]}"
