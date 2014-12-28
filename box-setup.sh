#!/bin/bash

set -x # Verbose

# restrict ssh login
cat << EOF >> /etc/ssh/sshd_config

PermitRootLogin no
PasswordAuthentication no
AllowUsers vagrant@10.0.2.2 yofel ximion
EOF

service ssh restart

# Add more swap
fallocate -l 8G /srv/swap
mkswap /srv/swap
chmod 600 /srv/swap

cat << EOF >> /etc/fstab

/srv/swap none swap sw,pri=-5 0 0
EOF
