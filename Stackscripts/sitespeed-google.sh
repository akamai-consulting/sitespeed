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
# <UDF name="GRAPHITE" Label="IP address OR friendly name of Graphite database (must be resolvable)" />
# <UDF name="API" Label="Google API Key" />

# Update the core OS
yum -y update

# Install packages
yum -y install tree wget nmap-ncat

# Update the system timezone
timedatectl set-timezone $TIMEZONE

# Download configurations files
wget https://as.akamai.com/user/sitespeed/google.tgz

# Install Docker
curl -fsSL https://get.docker.com/ | sh

# Start Docker
systemctl --now enable docker

# Create working Sitespeed folder
mkdir -p /usr/local/sitespeed/comp
mkdir /usr/local/sitespeed/tld
mkdir /usr/local/sitespeed/logs

# Extract and modify script
tar --warning=none --no-same-owner -C /usr/local/sitespeed -xf /google.tgz google.sh
chmod 755 /usr/local/sitespeed/google.sh
sed -i -r "s#\[TIMEZONE\]#$TIMEZONE#" /usr/local/sitespeed/google.sh
sed -i "s/\[GRAPHITE\]/$GRAPHITE/" /usr/local/sitespeed/google.sh
sed -i "s/\[API\]/$API/" /usr/local/sitespeed/google.sh

# Create sitespeed group and set ownership and permissions
groupadd sitespeed
chgrp -R sitespeed /usr/local/sitespeed
chmod -R 775 /usr/local/sitespeed

# Harden file system
sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart sshd

# Modify sudoers
sed -i 's/# %wheel/%wheel/' /etc/sudoers

# Create admin user
useradd $USERNAME
echo "$PASSWORD" | passwd "$USERNAME" --stdin

# Add admin to required groups
usermod -aG wheel $USERNAME
usermod -aG docker $USERNAME
usermod -aG sitespeed $USERNAME

# Set up SSH
mkdir /home/$USERNAME/.ssh
tar --warning=none --no-same-owner -C /home/$USERNAME/.ssh -xf /google.tgz *.pub
cat /home/$USERNAME/.ssh/jump-*.pub > /home/$USERNAME/.ssh/authorized_keys
cat /home/$USERNAME/.ssh/sitespeed.pub >> /home/$USERNAME/.ssh/authorized_keys
rm /home/$USERNAME/.ssh/*.pub
chmod 600 /home/$USERNAME/.ssh/authorized_keys
chown $USERNAME /home/$USERNAME/.ssh/authorized_keys
chgrp $USERNAME /home/$USERNAME/.ssh/authorized_keys
