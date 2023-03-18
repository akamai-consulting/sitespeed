#!/bin/bash

############################################
#                                          #
#          sitespeed-jump.sh               #
#                                          #
#         Created by Greg Wolf             #
#           gwolf@akamai.com               #
#                                          #
############################################

# <UDF name="USERNAME" Label="Name of admin user" />
# <UDF name="PASSWORD" Label="Password for admin user" />
# <UDF name="TIMEZONE" Label="Timezone" Example="IANA timezone format, i.e., America/New_York" />
# <UDF name="HOST" Label="Host name for this server" Example="Example i.e., Jump or Portal (no spaces allowed)" />
# <UDF name="DOMAIN" Label="Primary domain name" Example="Example i.e., sitespeed.akamai.com" />
# <UDF name="SERVERS" Label="Sitespeed host name(s)" Example="Example i.e., US-East Chicago SanFran (space delimited)" />
# <UDF name="GOOGLE" Label="Google host name" />
# <UDF name="GRAPHITE" Label="Graphite host name" />

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
usermod -aG wheel sitespeed
usermod -aG docker sitespeed
usermod -aG wheel $USERNAME
usermod -aG docker $USERNAME
usermod -aG sitespeed $USERNAME

# Create SSH folder and working Sitespeed folder
mkdir /home/$USERNAME/.ssh
mkdir -p /usr/local/sitespeed/logs
mkdir /usr/local/sitespeed/portal
mkdir /usr/local/sitespeed/google
mkdir /usr/local/sitespeed/sitespeed
mkdir /usr/local/sitespeed/seeds
mkdir /usr/local/sitespeed/cron

# Extract TAR files into appropriate folders
tar --warning=none --no-same-owner -C /usr/local/sitespeed -xf /jump.tgz *.sh
tar --warning=none --no-same-owner -C /usr/local/sitespeed/cron -xf /jump.tgz *cron
tar --warning=none --no-same-owner -C /usr/local/sitespeed/portal -xf /portal.tgz
tar --warning=none --no-same-owner -C /usr/local/sitespeed/sitespeed -xf /sitespeed.tgz *.sh *.json
tar --warning=none --no-same-owner -C /home/$USERNAME/.ssh -xf /jump.tgz *.pub sitespeed
tar --warning=none --no-same-owner -C /etc/nginx -xf /sitespeed.tgz nginx.conf

# Set ownership and permissions
chgrp -R sitespeed /usr/local/sitespeed
chmod -R 775 /usr/local/sitespeed
chmod 664 /usr/local/sitespeed/Sitespeed/config.json

# Set up SSH
cat /home/$USERNAME/.ssh/jump-*.pub > /home/$USERNAME/.ssh/authorized_keys
rm /home/$USERNAME/.ssh/*.pub
chown $USERNAME /home/$USERNAME/.ssh
chgrp $USERNAME /home/$USERNAME/.ssh
chmod 600 /home/$USERNAME/.ssh/authorized_keys
chown $USERNAME /home/$USERNAME/.ssh/authorized_keys
chgrp $USERNAME /home/$USERNAME/.ssh/authorized_keys
chmod 600 /home/$USERNAME/.ssh/sitespeed
chown $USERNAME /home/$USERNAME/.ssh/sitespeed
chgrp $USERNAME /home/$USERNAME/.ssh/sitespeed

# Modify admin.sh
sed -i "s/\[HOST\]/$HOST/" /usr/local/sitespeed/sitespeed/admin.sh
sed -i "s/\[DOMAIN\]/$DOMAIN/" /usr/local/sitespeed/sitespeed/admin.sh
sed -i "s/\[SERVERS\]/$SERVERS/" /usr/local/sitespeed/sitespeed/admin.sh
sed -i "s/\[GOOGLE\]/$GOOGLE/" /usr/local/sitespeed/sitespeed/admin.sh
sed -i "s/\[GRAPHITE\]/$GRAPHITE/" /usr/local/sitespeed/sitespeed/admin.sh

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
sed -i "s/\[GRAPHITE\]/$GRAPHITE/" /usr/local/sitespeed/portal/index.html
chmod 755 /usr/local/sitespeed/portal/index.html
chgrp sitespeed /usr/local/sitespeed/portal/index.html

# Modify error.html
sed -i "s/\[DOMAIN\]/$DOMAIN/g" /usr/local/sitespeed/portal/error.html
sed -i "s/\[GRAPHITE\]/$GRAPHITE/" /usr/local/sitespeed/portal/error.html

# Modify sitespeed.sh
sed -i -r "s#\[TIMEZONE\]#$TIMEZONE#" /usr/local/sitespeed/sitespeed/sitespeed.sh
sed -i "s/\[DOMAIN\]/$DOMAIN/" /usr/local/sitespeed/sitespeed/sitespeed.sh
sed -i "s/\[GRAPHITE\]/$GRAPHITE/" /usr/local/sitespeed/sitespeed/sitespeed.sh

# Modify config.json
sed -i "s/\[GRAPHITE\]\.\[DOMAIN\]/$GRAPHITE.$DOMAIN/" /usr/local/sitespeed/sitespeed/config.json

# Create symbolic links
sudo -u $USERNAME ln -s /usr/local/sitespeed/push.sh /home/$USERNAME/push.sh
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
