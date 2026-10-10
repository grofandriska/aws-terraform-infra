#!/bin/bash
mkdir -p /var/www
echo "Hello from secure, modular SSM Terraform architecture!" > /var/www/index.html

cat > /etc/systemd/system/webserver.service <<'UNIT'
[Unit]
Description=Simple Python web server
After=network.target

[Service]
User=www-data
WorkingDirectory=/var/www
ExecStart=/usr/bin/python3 -m http.server 80
AmbientCapabilities=CAP_NET_BIND_SERVICE
Restart=always

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now webserver