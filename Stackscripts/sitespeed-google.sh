#!/bin/bash

############################################
#                                          #
#          sitespeed-google.sh             #
#                  v20                     #
#                                          #
#         Created by Greg Wolf             #
#            gwolf@akamai.com              #
#                                          #
############################################

# <UDF name="USERNAME" Label="Name of admin user" />
# <UDF name="DOMAIN" Label="Primary domain name" Example="Example i.e., sitespeed.akamai.com" />
# <UDF name="API" Label="Google API Key" />

# Update the core OS
yum -y update

# Install packages
yum -y install tree wget nmap-ncat

# Update the system timezone
case $LINODE_DATACENTERID in
  4 | 6 | 17 ) timedatectl set-timezone America/New_York
               TIMEZONE=America/New_York ;;
                  
           2 ) timedatectl set-timezone America/Chicago
               TIMEZONE=America/Chicago ;;
      
           3 ) timedatectl set-timezone America/Los_Angeles
               TIMEZONE=America/Los_Angeles ;;
 
          15 ) timedatectl set-timezone America/Toronto
               TIMEZONE=America/Toronto ;;
     
           7 ) timedatectl set-timezone Europe/London
               TIMEZONE=Europe/London ;;
        
          10 ) timedatectl set-timezone Europe/Berlin
               TIMEZONE=Europe/Berlin ;;
     
           9 ) timedatectl set-timezone Asia/Singapore
               TIMEZONE=Asia/Singapore ;;
       
          16 ) timedatectl set-timezone Australia/Sydney
               TIMEZONE=Australia/Sydney ;;
   
          11 ) timedatectl set-timezone Asia/Tokyo
               TIMEZONE=Asia/Tokyo ;;
   
          14 ) timedatectl set-timezone Asia/Kolkata 
               TIMEZONE=Asia/Kolkata ;;
esac

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
echo "export PS1='[Google \u@\h \W]\$ '" >> /home/$USERNAME/.bash_profile

# Create sitespeed user
useradd sitespeed

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

# Create config files and set ownership
echo $DOMAIN > /usr/local/sitespeed/config/domain
echo $API > /usr/local/sitespeed/config/api
echo $TIMEZONE > /usr/local/sitespeed/config/timezone

# Set the ownership and permissions for config folder and files
chown -R root /usr/local/sitespeed/config
chgrp -R sitespeed /usr/local/sitespeed/config
chmod -R 775 /usr/local/sitespeed/config

# Harden file system
sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart sshd
