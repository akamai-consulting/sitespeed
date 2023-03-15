#!/bin/bash

############################################
#                                          #
#          sitespeed-google.sh             #
#                                          #
#         Created by Greg Wolf             #
#            gwolf@akamai.com              #
#                                          #
############################################

# <UDF name="USERNAME" Label="Name of admin user" />
# <UDF name="PASSWORD" Label="Password for admin user" />
# <UDF name="TIMEZONE" Label="Timezone" Example="IANA timezone format, i.e., America/New_York" />
# <UDF name="HOST" Label="Host name for this server" Example="google or psi-crux (no spaces allowed)" />
# <UDF name="GRAPHITE" Label="Graphite host name" />
# <UDF name="DOMAIN" Label="Domain name" Example="sitespeed.akamai.com" />
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

# Extract TAR files into appropriate folders
tar --warning=none --no-same-owner -C /usr/local/sitespeed -xf /google.tgz google.sh
tar --warning=none --no-same-owner -C /home/$USERNAME/.ssh -xf /google.tgz *.pub

# Set ownership and permissions
chgrp -R sitespeed /usr/local/sitespeed
chmod -R 775 /usr/local/sitespeed

# Set up SSH
cat /home/$USERNAME/.ssh/jump-*.pub > /home/$USERNAME/.ssh/authorized_keys
cat /home/$USERNAME/.ssh/sitespeed.pub >> /home/$USERNAME/.ssh/authorized_keys
rm /home/$USERNAME/.ssh/*.pub
chmod 600 /home/$USERNAME/.ssh/authorized_keys
chown $USERNAME /home/$USERNAME/.ssh/authorized_keys
chgrp $USERNAME /home/$USERNAME/.ssh/authorized_keys

# Modify google.sh
sed -i -r "s#\[TIMEZONE\]#$TIMEZONE#" /usr/local/sitespeed/google.sh
sed -i "s/\[GRAPHITE\]/$GRAPHITE/" /usr/local/sitespeed/google.sh
sed -i "s/\[DOMAIN\]/$DOMAIN/" /usr/local/sitespeed/google.sh
sed -i "s/\[API\]/$API/" /usr/local/sitespeed/google.sh

# Harden file system
sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart sshd
