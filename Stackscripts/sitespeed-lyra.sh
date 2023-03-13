#!/bin/bash

############################################
#                                          #
#             sitespeed-lyra               #
#                                          #
#         Created by Greg Wolf             #
#            gwolf@akamai.com              #
#                                          #
############################################

# <UDF name="USERNAME" Label="Name of admin user" />
# <UDF name="PASSWORD" Label="Password for admin user" />
# <UDF name="TIMEZONE" Label="Timezone" Example="IANA timezone format, i.e., America/New_York" />
# <UDF name="SSH" Label="SSH Public Key" />

# Update the core OS
yum -y update

# Update the system timezone
timedatectl set-timezone $TIMEZONE

# Create an Influx YUM repo
cat <<EOF | tee /etc/yum.repos.d/influxdata.repo
[influxdata]
name = InfluxData Repository - Stable
baseurl = https://repos.influxdata.com/stable/\$basearch/main
enabled = 1
gpgcheck = 1
gpgkey = https://repos.influxdata.com/influxdata-archive_compat.key
EOF

# Install packages
yum -y install influxdb2 tree

# Configure firewall
firewall-cmd --permanent --zone=public --add-port=8086/tcp
firewall-cmd --reload

# Start Influx
systemctl --now enable influxdb

# Harden file system
sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart sshd

# Modify sudoers
sed -i 's/# %wheel/%wheel/' /etc/sudoers

# Create admin user
useradd $USERNAME
echo "$PASSWORD" | passwd "$USERNAME" --stdin

# Set group memberships
usermod -aG wheel $USERNAME

# Set up SSH
mkdir /home/$USERNAME/.ssh
echo "$SSH" > /home/$USERNAME/.ssh/authorized_keys
chmod 600 /home/$USERNAME/.ssh/authorized_keys
chown $USERNAME /home/$USERNAME/.ssh/authorized_keys
chgrp $USERNAME /home/$USERNAME/.ssh/authorized_keys

# Install Certbot components
yum -y install dnf && dnf -y install epel-release 
yum -y install snapd && systemctl --now enable snapd
systemctl daemon-reload
snap install core
ln -s /var/lib/snapd/snap /snap
snap install --classic certbot
ln -s /snap/bin/certbot /usr/bin/certbot
