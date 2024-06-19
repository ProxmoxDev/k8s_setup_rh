#!/bin/bash

## install code-server
curl -fsSL https://code-server.dev/install.sh | sh

cat > /root/.config/code-server/config.yaml <<EOF
bind-addr: 0.0.0.0:8080
auth: none
cert: false
EOF

systemctl enable --now code-server@root

## install nginx
dnf install -y nginx
cat > /etc/nginx/conf.d/code.conf <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name code.syun.dev;

    location / {
      proxy_pass http://localhost:8080/;
      proxy_set_header Host $http_host;
      proxy_set_header Upgrade $http_upgrade;
      proxy_set_header Connection upgrade;
      proxy_set_header Accept-Encoding gzip;
    }
}
EOF
systemctl enable --now nginx

## code-server extension
code-server --install-extension ms-ceintl.vscode-language-pack-ja
code-server --install-extension vscodevim.vim
code-server --install-extension antfu.browse-lite
code-server --install-extension pkief.material-icon-theme
code-server --install-extension gulajavaministudio.mayukaithemevsc


## install google-chrome
## https://www.google.com/chrome/?platform=linux
curl -O https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm
dnf install -y google-chrome-stable_current_x86_64.rpm
