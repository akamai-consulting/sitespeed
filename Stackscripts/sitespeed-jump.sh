#!/bin/bash

############################################
#                                          #
#         sitespeed-jump.sh                #
#                                          #
#         Created by Greg Wolf             #
#            gwolf@akamai.com              #
#                                          #
############################################

# <UDF name="USERNAME" Label="Name of admin user" />
# <UDF name="PASSWORD" Label="Password for admin user" />
# <UDF name="TIMEZONE" Label="Timezone" Example="IANA timezone format, i.e., America/New_York" />
# <UDF name="LOCATION" Label="Name(s) of Sitespeed servers" Example="New-York Dallas SanFran (no spaces in name)" />
# <UDF name="GOOGLE" Label="Name of the Google server" Example="Google or PSI-CrUX (no spaces in name)" />
# <UDF name="HOST" Label="Hostname" Example="sitespeed.akamai.com (must be resolvable)" />
# <UDF name="GRAPHITE" Label="IP or friendly name of Graphite (must be resolvable)" />

# Update the core OS
yum -y update

# Install packages
yum -y install tree wget nmap-ncat
yum -y install epel-release && yum -y install nginx

# Update the system timezone
timedatectl set-timezone $TIMEZONE

# Download configurations files
wget https://as.akamai.com/user/sitespeed/jump.tgz
wget https://as.akamai.com/user/sitespeed/portal.tgz
wget https://as.akamai.com/user/sitespeed/google.tgz
wget https://as.akamai.com/user/sitespeed/sitespeed.tgz

# Modify sudoers
sed -i 's/# %wheel/%wheel/' /etc/sudoers

# Create admin user
useradd $USERNAME
echo "$PASSWORD" | passwd "$USERNAME" --stdin

# Create sitespeed user
useradd sitespeed
echo "$PASSWORD" | passwd sitespeed --stdin

# Add users to required groups
groupadd sitespeed
usermod -aG wheel sitespeed
usermod -aG docker sitespeed
usermod -aG wheel $USERNAME
usermod -aG docker $USERNAME
usermod -aG sitespeed $USERNAME

# Create SSH folder and working Sitespeed folder
mkdir /home/$USERNAME/.ssh
mkdir -p /usr/local/sitespeed/logs
mkdir /usr/local/sitespeed/portal
mkdir /usr/local/sitespeed/Google
mkdir /usr/local/sitespeed/Sitespeed
mkdir /usr/local/sitespeed/Seeds
mkdir /usr/local/sitespeed/Cron

# Extract TAR files into appropriate folders
tar --warning=none --no-same-owner -C /home/$USERNAME/.ssh -xf /jump.tgz *.pub sitespeed
tar --warning=none --no-same-owner -C /usr/local/sitespeed/portal -xf /portal.tgz
tar --warning=none --no-same-owner -C /usr/local/sitespeed/Google -xf /google.tgz *.sh
tar --warning=none --no-same-owner -C /usr/local/sitespeed/Sitespeed -xf /sitespeed.tgz *.sh *.json
tar --warning=none --no-same-owner -C /usr/local/sitespeed -xf /jump.tgz *.sh
tar --warning=none --no-same-owner -C /usr/local/sitespeed/Cron -xf /jump.tgz *cron
tar --warning=none --no-same-owner -C /etc/nginx -xf /sitespeed.tgz nginx.conf

# Set ownership and permissions
chgrp -R sitespeed /usr/local/sitespeed
chmod -R 775 /usr/local/sitespeed
chmod 664 /usr/local/sitespeed/Sitespeed/config.json

# Set up SSH
cat /home/$USERNAME/.ssh/jump-*.pub > /home/$USERNAME/.ssh/authorized_keys
rm /home/$USERNAME/.ssh/*.pub
chmod 600 /home/$USERNAME/.ssh/authorized_keys
chown $USERNAME /home/$USERNAME/.ssh/authorized_keys
chgrp $USERNAME /home/$USERNAME/.ssh/authorized_keys
chmod 600 /home/$USERNAME/.ssh/sitespeed
chown $USERNAME /home/$USERNAME/.ssh/sitespeed
chgrp $USERNAME /home/$USERNAME/.ssh/sitespeed

# Modify lots of files

# Create symbolic links properly to push, and the cron files

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
