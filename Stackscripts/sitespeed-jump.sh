#!/bin/bash

############################################
#                                          #
#          sitespeed-jump.sh               #
#                  v16                     #
#                                          #
#         Created by Greg Wolf             #
#           gwolf@akamai.com               #
#                                          #
############################################

# <UDF name="USERNAME" Label="Name of admin user" />
# <UDF name="DOMAIN" Label="Primary domain name" Example="Example i.e., sitespeed.akamai.com" />
# <UDF name="SERVERS" Label="Sitespeed host name(s)" Example="Example i.e., Newark Dallas London (space delimited)" />

# Update the core OS
yum -y update

# Install packages
yum -y install tree wget nmap-ncat
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

# Download configurations files
wget https://as.akamai.com/user/sitespeed/jump.tgz
wget https://as.akamai.com/user/sitespeed/portal.tgz
wget https://as.akamai.com/user/sitespeed/sitespeed.tgz
wget https://as.akamai.com/user/sitespeed/sshkeys.tgz

# Modify sudoers
sed -i 's/# %wheel/%wheel/' /etc/sudoers

# Create admin user
useradd $USERNAME
echo -e "function jump() {\n  ssh -i /home/$USERNAME/.ssh/sitespeed \$1.$DOMAIN\n}\nexport PS1='[Jump \u@\h \W]\$ '" >> /home/$USERNAME/.bash_profile 

# Create sitespeed user
useradd sitespeed

# Add users to required groups
usermod -aG wheel sitespeed
usermod -aG docker sitespeed
usermod -aG wheel $USERNAME
usermod -aG docker $USERNAME
usermod -aG sitespeed $USERNAME

# Create SSH and Sitespeed folders
mkdir /home/$USERNAME/.ssh
mkdir /home/sitespeed/.ssh
mkdir -p /usr/local/sitespeed/logs
mkdir /usr/local/sitespeed/portal
mkdir /usr/local/sitespeed/google
mkdir /usr/local/sitespeed/sitespeed
mkdir /usr/local/sitespeed/seeds
mkdir /usr/local/sitespeed/cron
mkdir /usr/local/sitespeed/config

# Extract TAR files into appropriate folders
tar --warning=none --no-same-owner -C /usr/local/sitespeed -xf /jump.tgz *.sh
tar --warning=none --no-same-owner -C /usr/local/sitespeed/cron -xf /jump.tgz psicron sitecron
tar --warning=none --no-same-owner -C /home/sitespeed -xf /jump.tgz jumpcron
tar --warning=none --no-same-owner -C /usr/local/sitespeed/portal -xf /portal.tgz
tar --warning=none --no-same-owner -C /usr/local/sitespeed/sitespeed -xf /sitespeed.tgz *.sh *.json
tar --warning=none --no-same-owner -C /home/$USERNAME/.ssh -xf /sshkeys.tgz jump.pub sitespeed
tar --warning=none --no-same-owner -C /etc/nginx -xf /sitespeed.tgz nginx.conf

# Set ownership and permissions
chgrp -R sitespeed /usr/local/sitespeed
chmod -R 775 /usr/local/sitespeed
chmod 664 /usr/local/sitespeed/Sitespeed/config.json
chown sitespeed /home/sitespeed/jumpcron
chgrp sitespeed /home/sitespeed/jumpcron

# Set up SSH for admin user
mv /home/$USERNAME/.ssh/jump.pub /home/$USERNAME/.ssh/authorized_keys
chown -R $USERNAME /home/$USERNAME/.ssh
chgrp -R $USERNAME /home/$USERNAME/.ssh
chmod 600 /home/$USERNAME/.ssh/authorized_keys
chmod 600 /home/$USERNAME/.ssh/sitespeed

# Set up SSH for sitespeed user
cp /home/$USERNAME/.ssh/authorized_keys /home/sitespeed/.ssh/authorized_keys
cp /home/$USERNAME/.ssh/sitespeed /home/sitespeed/.ssh/sitespeed
chown -R sitespeed /home/sitespeed/.ssh
chgrp -R sitespeed /home/sitespeed/.ssh

# Modify admin.sh
sed -i "s/\[DOMAIN\]/$DOMAIN/" /usr/local/sitespeed/admin.sh

# Modify maintenance.sh
sed -i "s/\[DOMAIN\]/$DOMAIN/" /usr/local/sitespeed/maintenance.sh
sed -i "s#\[TIMEZONE\]#$TIMEZONE#" /usr/local/sitespeed/maintenance.sh

# Modify user.sh
sed -i "s/\[DOMAIN\]/$DOMAIN/" /usr/local/sitespeed/user.sh

# Create config files and set ownership
for data in $SERVERS
  do
   echo $data >> /usr/local/sitespeed/config/servers
  done
echo $USERNAME-Admin > /usr/local/sitespeed/config/users
echo $DOMAIN > /usr/local/sitespeed/config/domain

# Set the ownership and permissions for config folder and files
chown -R root /usr/local/sitespeed/config
chgrp -R sitespeed /usr/local/sitespeed/config
chmod -R 664 /usr/local/sitespeed/config

# Modify index.html
sortedSERVERS=$(echo $SERVERS | xargs -n 1 | sort | xargs)
count=$(echo $sortedSERVERS | wc -w)
line=1
for (( index=0; index < count ; index+=1 ))
  do
    Region=$(echo $sortedSERVERS | awk -v var=$line '{print $var}')
    echo "     <option value=\"http://$Region.$DOMAIN/\">$Region</option>" >> foo
    let "line++"
  done
sed '/\[HOST\]\.\[DOMAIN\]/r foo' /usr/local/sitespeed/portal/index.html | sed '/\[HOST\]\.\[DOMAIN\]/d' > bar
mv -f bar /usr/local/sitespeed/portal/index.html
rm foo
sed -i "s/\[DOMAIN\]/$DOMAIN/g" /usr/local/sitespeed/portal/index.html
chmod 755 /usr/local/sitespeed/portal/index.html
chgrp sitespeed /usr/local/sitespeed/portal/index.html

# Modify error.html
sed -i "s/\[DOMAIN\]/$DOMAIN/g" /usr/local/sitespeed/portal/error.html

# Modify sitespeed.sh
sed -i -r "s#\[TIMEZONE\]#$TIMEZONE#" /usr/local/sitespeed/sitespeed/sitespeed.sh
sed -i "s/\[DOMAIN\]/$DOMAIN/" /usr/local/sitespeed/sitespeed/sitespeed.sh

# Modify config.json
sed -i "s/\[DOMAIN\]/$DOMAIN/" /usr/local/sitespeed/sitespeed/config.json

# Create symbolic links
sudo -u $USERNAME ln -s /usr/local/sitespeed/admin.sh /home/$USERNAME/admin.sh
sudo -u $USERNAME ln -s /usr/local/sitespeed/cron/ /home/$USERNAME/cron
sudo -u $USERNAME ln -s /usr/local/sitespeed/seeds/ /home/$USERNAME/seeds

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
