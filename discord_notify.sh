#!/bin/bash

DISCORD_WEBHOOK_URL=

## Create Script
mkdir discord-notify

cat <<EOF | tee /root/discord-notify/start.sh
#!/bin/bash

discordWebhook=$DISCORD_WEBHOOK_URL

curl=\`cat <<EOS
curl
 --verbose
 -X POST
 ${discordWebhook}
 -H 'Content-Type: application/json'
 --data '{"content": "[XXXX] XXXX が起動しました"}'
EOS\`
eval ${curl}
EOF

cat <<EOF | tee /root/discord-notify/stop.sh
#!/bin/bash

discordWebhook=$DISCORD_WEBHOOK_URL

curl=`cat <<EOS
curl
 --verbose
 -X POST
 ${discordWebhook}
 -H 'Content-Type: application/json'
 --data '{"content": "[XXXX] XXXX を停止します"}'
EOS`
eval ${curl}
EOF

chmod +x /root/discord-notify/start.sh
chmod +x /root/discord-notify/stop.sh

## Create Service
cat <<EOF | tee /etc/systemd/system/discord.service
[Unit]
Description=Start&stop Discord Notify service.
After=syslog.target network-online.target

[Service]
User=root
Type=oneshot
RemainAfterExit=yes
KillMode=none
ExecStart=/bin/bash -c 'cd /root/discord-notify; ./start.sh'
ExecStop=/bin/bash -c 'cd /root/discord-notify; ./stop.sh'

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now discord.service
