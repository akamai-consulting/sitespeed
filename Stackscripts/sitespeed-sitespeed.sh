#!/bin/bash

############################################
#                                          #
#         sitespeed-sitespeed.sh           #
#                                          #
#         Created by Greg Wolf             #
#            gwolf@akamai.com              #
#                                          #
############################################

# <UDF name="USERNAME" Label="Name of admin user" />
# <UDF name="PASSWORD" Label="Password for admin user" />
# <UDF name="TIMEZONE" Label="Timezone" Example="IANA timezone format, i.e., America/New_York" />
# <UDF name="HOST" Label="Host name for this server" Example="US-East or Chicago (no spaces allowed)" />
# <UDF name="GRAPHITE" Label="Graphite host name" />
# <UDF name="DOMAIN" Label="Domain name" Example="sitespeed.akamai.com" />

# Update the core OS
yum -y update

# Install packages
yum -y install tree wget nmap-ncat iproute-tc kernel-modules-extra
yum -y install epel-release && yum -y install nginx

# Update the system timezone
timedatectl set-timezone $TIMEZONE

# Modify the kernel for network throttling 
modprobe sch_netem

# Install Docker
curl -fsSL https://get.docker.com/ | sh

# Start Docker
systemctl --now enable docker

# Download configurations files
wget https://as.akamai.com/user/sitespeed/sitespeed.tgz
wget https://as.akamai.com/user/sitespeed/portal.tgz

# Modify sudoers
sed -i 's/# %wheel/%wheel/' /etc/sudoers

# Create admin user
useradd $USERNAME
echo "$PASSWORD" | passwd "$USERNAME" --stdin

# Create sitespeed group and add user to required groups
groupadd sitespeed
usermod -aG wheel $USERNAME
usermod -aG docker $USERNAME
usermod -aG sitespeed $USERNAME

# Create SSH folder and working Sitespeed folder
mkdir /home/$USERNAME/.ssh
mkdir -p /usr/local/sitespeed/comp
mkdir /usr/local/sitespeed/tld
mkdir /usr/local/sitespeed/logs
mkdir /usr/local/sitespeed/portal

# Extract TAR files into appropriate folders
tar --warning=none --no-same-owner -C /home/$USERNAME/.ssh -xf /sitespeed.tgz *.pub
tar --warning=none --no-same-owner -C /usr/local/sitespeed -xf /sitespeed.tgz *.sh
tar --warning=none --no-same-owner -C /usr/local/sitespeed/tld -xf /sitespeed.tgz config.json
tar --warning=none --no-same-owner -C /usr/local/sitespeed/comp -xf /sitespeed.tgz config.json
tar --warning=none --no-same-owner -C /usr/local/sitespeed/portal -xf /portal.tgz
tar --warning=none --no-same-owner -C /etc/nginx -xf /sitespeed.tgz nginx.conf

# Set ownership and permissions
chgrp -R sitespeed /usr/local/sitespeed
chmod -R 775 /usr/local/sitespeed
chmod 664 /usr/local/sitespeed/tld/config.json 
chmod 664 /usr/local/sitespeed/comp/config.json

# Set up SSH
cat /home/$USERNAME/.ssh/jump-*.pub > /home/$USERNAME/.ssh/authorized_keys
cat /home/$USERNAME/.ssh/sitespeed.pub >> /home/$USERNAME/.ssh/authorized_keys
rm /home/$USERNAME/.ssh/*.pub
chmod 600 /home/$USERNAME/.ssh/authorized_keys
chown $USERNAME /home/$USERNAME/.ssh/authorized_keys
chgrp $USERNAME /home/$USERNAME/.ssh/authorized_keys

# Modify config.json
sed -i "s/\[GRAPHITE\]\.\[DOMAIN\]/$GRAPHITE.$DOMAIN/" /usr/local/sitespeed/tld/config.json
sed -i "s/\[GRAPHITE\]\.\[DOMAIN\]/$GRAPHITE.$DOMAIN/" /usr/local/sitespeed/comp/config.json

# Modify sitespeed.sh
sed -i -r "s#\[TIMEZONE\]#$TIMEZONE#" /usr/local/sitespeed/sitespeed.sh
sed -i "s/\[DOMAIN\]/$DOMAIN/" /usr/local/sitespeed/sitespeed.sh
sed -i "s/\[GRAPHITE\]/$GRAPHITE/" /usr/local/sitespeed/sitespeed.sh

# Modify index.html and error.html
sed -i "s/\[DOMAIN\]/$DOMAIN/g" /usr/local/sitespeed/portal/index.html
sed -i "s/\[HOST\]/$HOST/g" /usr/local/sitespeed/portal/index.html
sed -i "s/\[GRAPHITE\]/$GRAPHITE/" /usr/local/sitespeed/portal/index.html
sed -i "s/\[DOMAIN\]/$DOMAIN/g" /usr/local/sitespeed/portal/error.html
sed -i "s/\[GRAPHITE\]/$GRAPHITE/" /usr/local/sitespeed/portal/error.html

# Start nginx
systemctl --now enable nginx

# Configure firewall
firewall-cmd --permanent --zone=public --add-service=http
firewall-cmd --permanent --zone=public --add-service=https
firewall-cmd --reload

# Harden file system
sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart sshd

# Install Certbot components
yum -y install dnf && dnf -y install epel-release 
yum -y install snapd && systemctl --now enable snapd
systemctl daemon-reload
snap install core
ln -s /var/lib/snapd/snap /snap
snap install --classic certbot
ln -s /snap/bin/certbot /usr/bin/certbot
