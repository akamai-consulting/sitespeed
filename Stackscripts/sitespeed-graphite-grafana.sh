#!/bin/bash

############################################
#                                          #
#      sitespeed-graphite-grafana          #
#                  v7                      #
#                                          #
#         Created by Greg Wolf             #
#            gwolf@akamai.com              #
#                                          #
############################################

# <UDF name="USERNAME" Label="Name of admin user" />
# <UDF name="HOST" Label="Host name for this server" Example="Example i.e., graphite or grafana (no spaces allowed)" />
# <UDF name="DOMAIN" Label="Primary domain name" Example="Example i.e., sitespeed.akamai.com" />

# Update the core OS
yum -y update

# Create a Grafana YUM repo
cat <<EOF | tee /etc/yum.repos.d/grafana.repo
[grafana]
name=grafana-enterprise
baseurl=https://packages.grafana.com/enterprise/rpm
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://packages.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF

# Install packages
yum -y install grafana-enterprise tree wget

# Install Grafana plugin
grafana-cli plugins install yesoreyeram-boomtable-panel

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
wget https://as.akamai.com/user/sitespeed/graphite.tgz
wget https://as.akamai.com/user/sitespeed/grafana.tgz
wget https://as.akamai.com/user/sitespeed/sshkeys.tgz

# Modify sudoers
sed -i 's/# %wheel/%wheel/' /etc/sudoers

# Create admin user
useradd $USERNAME
echo "export PS1='[$HOST \u@\h \W]\$ '" >> /home/$USERNAME/.bash_profile

# Create sitespeed user
useradd sitespeed

# Add admin to required groups
usermod -aG wheel sitespeed
usermod -aG docker sitespeed
usermod -aG wheel $USERNAME
usermod -aG docker $USERNAME
usermod -aG sitespeed $USERNAME

# Create Graphite, SSH, and Grafana dashboard folders
mkdir /usr/local/graphite
mkdir /home/$USERNAME/.ssh
mkdir /home/sitespeed/.ssh
mkdir -p /var/lib/grafana/dashboards/apis
mkdir /var/lib/grafana/dashboards/google
mkdir /var/lib/grafana/dashboards/lyra
mkdir /var/lib/grafana/dashboards/sitespeed
mkdir /var/lib/grafana/dashboards/ds2

# Extract TAR files into appropriate folders
tar --warning=none --no-same-owner -C /usr/local/graphite -xf /grafana.tgz *.sh
tar --warning=none --no-same-owner -C /usr/local/graphite -xf /graphite.tgz *.sh *.sql
tar --warning=none --no-same-owner -C /home/$USERNAME/.ssh -xf /sshkeys.tgz sitespeed.pub

# Set permissions
chmod 755 /usr/local/graphite/*.sh

# Set up SSH for admin user
mv /home/$USERNAME/.ssh/sitespeed.pub /home/$USERNAME/.ssh/authorized_keys
chown -R $USERNAME /home/$USERNAME/.ssh
chgrp -R $USERNAME /home/$USERNAME/.ssh
chmod 600 /home/$USERNAME/.ssh/authorized_keys

# Set up SSH for sitespeed user
cp /home/$USERNAME/.ssh/authorized_keys /home/sitespeed/.ssh/authorized_keys
chown -R sitespeed /home/sitespeed/.ssh
chgrp -R sitespeed /home/sitespeed/.ssh

# Modify Grafana configuration files and start Grafana
sed -i -r "s#;default_timezone = browser#default_timezone = $TIMEZONE#" /etc/grafana/grafana.ini
sed -i 's/;http_port = 3000/http_port = 80/' /etc/grafana/grafana.ini
sed -i 's/;default_theme = dark/default_theme = light/' /etc/grafana/grafana.ini
sed -i '/;default_home_dashboard_path =/a default_home_dashboard_path = /var/lib/grafana/dashboards/sitespeed/Welcome to sitespeed.io.json' /etc/grafana/grafana.ini
sed -i "s/;domain = localhost/domain = $HOST.$DOMAIN/" /etc/grafana/grafana.ini
sed -i 's/CapabilityBoundingSet=/&CAP_NET_BIND_SERVICE/' /usr/lib/systemd/system/grafana-server.service
sed -i '/CAP_NET_BIND_SERVICE/a AmbientCapabilities=CAP_NET_BIND_SERVICE' /usr/lib/systemd/system/grafana-server.service
sed -i '/AmbientCapabilities=CAP_NET_BIND_SERVICE/a PrivateUsers=false' /usr/lib/systemd/system/grafana-server.service
systemctl daemon-reload
systemctl --now enable grafana-server

# Execute Grafana provisioning script
/usr/local/graphite/provision.sh

# Modify graphite.sh to set timezone
sed -i -r "s#\[TIMEZONE\]#$TIMEZONE#" /usr/local/graphite/graphite.sh

# Start Graphite for the first time to expose persistent volumes
/usr/local/graphite/graphite.sh start

# Modify Graphite configuration files
tar --warning=none --no-same-owner --overwrite -C /usr/local/graphite/graphite-conf -xf /graphite.tgz *.conf
chmod 666 /usr/local/graphite/graphite-storage/graphite.db

# Restart Graphite to apply configuration changes
/usr/local/graphite/graphite.sh stop && /usr/local/graphite/graphite.sh start

# Configure firewall
firewall-cmd --permanent --zone=public --add-service=http
firewall-cmd --permanent --zone=public --add-service=https
firewall-cmd --permanent --zone=public --add-port=2003/tcp
firewall-cmd --permanent --zone=public --add-port=8888/tcp
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
