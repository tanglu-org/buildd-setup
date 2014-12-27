#!/bin/bash

# restrict ssh login
cat << EOF > /etc/ssh/sshd_config

PermitRootLogin no
PasswordAuthentication no
AllowUsers vagrant@10.0.2.2 yofel ximion
EOF

service ssh restart
