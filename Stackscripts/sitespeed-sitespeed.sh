#!/bin/bash

############################################
#                                          #
#         sitespeed-sitespeed.sh           #
#                 v20                      #
#                                          #
#         Created by Greg Wolf             #
#            gwolf@akamai.com              #
#                                          #
############################################

# <UDF name="USERNAME" Label="Name of admin user" />
# <UDF name="HOST" Label="Host name for this server" Example="Example i.e., Newark or Dallas" />
# <UDF name="DOMAIN" Label="Primary domain name" Example="Example i.e., sitespeed.akamai.com" />

# Update the core OS
yum -y update

# Install packages
yum -y install tree wget nmap-ncat iproute-tc kernel-modules-extra
yum -y install epel-release && yum -y install nginx

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

# Modify the kernel for network throttling 
modprobe sch_netem

# Install Docker
curl -fsSL https://get.docker.com/ | sh

# Start Docker
systemctl --now enable docker

# Download configurations files
wget https://as.akamai.com/user/sitespeed/sitespeed.tgz
wget https://as.akamai.com/user/sitespeed/portal.tgz
wget https://as.akamai.com/user/sitespeed/sshkeys.tgz

# Modify sudoers
sed -i 's/# %wheel/%wheel/' /etc/sudoers

# Create admin user
useradd $USERNAME
echo "export PS1='[$HOST \u@\h \W]\$ '" >> /home/$USERNAME/.bash_profile

# Create sitespeed user
useradd sitespeed

# Create sitespeed group and add user to required groups
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
mkdir /usr/local/sitespeed/portal

# Extract TAR files into appropriate folders
tar --warning=none --no-same-owner -C /home/$USERNAME/.ssh -xf /sshkeys.tgz sitespeed.pub
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

# Set up SSH for admin user
mv /home/$USERNAME/.ssh/sitespeed.pub /home/$USERNAME/.ssh/authorized_keys
chown -R $USERNAME /home/$USERNAME/.ssh
chgrp -R $USERNAME /home/$USERNAME/.ssh
chmod 600 /home/$USERNAME/.ssh/authorized_keys

# Set up SSH for sitespeed user
cp /home/$USERNAME/.ssh/authorized_keys /home/sitespeed/.ssh/authorized_keys
chown -R sitespeed /home/sitespeed/.ssh
chgrp -R sitespeed /home/sitespeed/.ssh

# Modify config.json
sed -i "s/\[DOMAIN\]/$DOMAIN/" /usr/local/sitespeed/tld/config.json
sed -i "s/\[DOMAIN\]/$DOMAIN/" /usr/local/sitespeed/comp/config.json

# Modify index.html
sed -i "s/\[DOMAIN\]/$DOMAIN/g" /usr/local/sitespeed/portal/index.html
sed -i "s/\[HOST\]/$HOST/g" /usr/local/sitespeed/portal/index.html

# Modify error.html
sed -i "s/\[DOMAIN\]/$DOMAIN/g" /usr/local/sitespeed/portal/error.html

# Create config files and set ownership
echo $DOMAIN > /usr/local/sitespeed/config/domain
echo $TIMEZONE > /usr/local/sitespeed/config/timezone

# Set the ownership and permissions for config folder and files
chown -R root /usr/local/sitespeed/config
chgrp -R sitespeed /usr/local/sitespeed/config
chmod -R 775 /usr/local/sitespeed/config

# Start nginx
chcon -vR system_u:object_r:httpd_sys_content_t:s0 /usr/local/sitespeed
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
