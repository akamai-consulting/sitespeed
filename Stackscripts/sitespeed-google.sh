#!/bin/bash

############################################
#                                          #
#          sitespeed-google.sh             #
#                  v6                      #
#                                          #
#         Created by Greg Wolf             #
#            gwolf@akamai.com              #
#                                          #
############################################

# <UDF name="USERNAME" Label="Name of admin user" />
# <UDF name="PASSWORD" Label="Password for admin user" />
# <UDF name="TIMEZONE" Label="Timezone" Example="IANA timezone format, i.e., America/New_York" />
# <UDF name="HOST" Label="Host name for this server" Example="Example i.e., Google or PSI-CrUX (no spaces allowed)" />
# <UDF name="DOMAIN" Label="Primary domain name" Example="Example i.e., sitespeed.akamai.com" />
# <UDF name="GRAPHITE" Label="Graphite host name" />
# <UDF name="API" Label="Google API Key" />

# Update the core OS
yum -y update

# Install packages
yum -y install tree wget nmap-ncat

# Update the system timezone
timedatectl set-timezone $TIMEZONE

# Install Docker
curl -fsSL https://get.docker.com/ | sh

# Start Docker
systemctl --now enable docker

# Download configurations files
wget https://as.akamai.com/user/sitespeed/google.tgz
wget https://as.akamai.com/user/sitespeed/sshkeys.tgz

# Modify sudoers
sed -i 's/# %wheel/%wheel/' /etc/sudoers

# Create admin user
useradd $USERNAME
echo "$PASSWORD" | passwd "$USERNAME" --stdin
echo "export PS1='[$HOST \u@\h \W]\$ '" >> /home/$USERNAME/.bash_profile

# Create sitespeed user
useradd sitespeed
echo "$PASSWORD" | passwd sitespeed --stdin

# Add users to required groups
usermod -aG wheel sitespeed
usermod -aG docker sitespeed
usermod -aG wheel $USERNAME
usermod -aG docker $USERNAME
usermod -aG sitespeed $USERNAME

# Create SSH folder and working Sitespeed folder
mkdir /home/$USERNAME/.ssh
mkdir /home/sitespeed/.ssh
mkdir -p /usr/local/sitespeed/comp
mkdir /usr/local/sitespeed/tld
mkdir /usr/local/sitespeed/logs

# Extract TAR files into appropriate folders
tar --warning=none --no-same-owner -C /usr/local/sitespeed -xf /google.tgz google.sh
tar --warning=none --no-same-owner -C /home/$USERNAME/.ssh -xf /sshkeys.tgz sitespeed.pub

# Set ownership and permissions
chgrp -R sitespeed /usr/local/sitespeed
chmod -R 775 /usr/local/sitespeed

# Set up SSH for admin user
mv /home/$USERNAME/.ssh/sitespeed.pub /home/$USERNAME/.ssh/authorized_keys
chown -R $USERNAME /home/$USERNAME/.ssh
chgrp -R $USERNAME /home/$USERNAME/.ssh
chmod 600 /home/$USERNAME/.ssh/authorized_keys

# Set up SSH for sitespeed user
cp /home/$USERNAME/.ssh/authorized_keys /home/sitespeed/.ssh/authorized_keys
chown -R sitespeed /home/sitespeed/.ssh
chgrp -R sitespeed /home/sitespeed/.ssh

# Modify google.sh
sed -i -r "s#\[TIMEZONE\]#$TIMEZONE#" /usr/local/sitespeed/google.sh
sed -i "s/\[GRAPHITE\]/$GRAPHITE/" /usr/local/sitespeed/google.sh
sed -i "s/\[DOMAIN\]/$DOMAIN/" /usr/local/sitespeed/google.sh
sed -i "s/\[API\]/$API/" /usr/local/sitespeed/google.sh

# Harden file system
sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart sshd
