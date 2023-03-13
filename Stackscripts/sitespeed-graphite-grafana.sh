#!/bin/bash

############################################
#                                          #
#      sitespeed-graphite-grafana          #
#                                          #
#         Created by Greg Wolf             #
#            gwolf@akamai.com              #
#                                          #
############################################

# <UDF name="USERNAME" Label="Name of admin user" />
# <UDF name="PASSWORD" Label="Password for admin user" />
# <UDF name="TIMEZONE" Label="Timezone" Example="IANA timezone format, i.e., America/New_York" />

# Update the core OS
yum -y update

# Update the system timezone
timedatectl set-timezone $TIMEZONE

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

# Download configurations files
wget https://as.akamai.com/user/sitespeed/graphite.tgz
wget https://as.akamai.com/user/sitespeed/grafana.tgz

# Modify Grafana configuration files
sed -i -r "s#;default_timezone = browser#default_timezone = $TIMEZONE#" /etc/grafana/grafana.ini
sed -i 's/;http_port = 3000/http_port = 80/' /etc/grafana/grafana.ini
sed -i 's/;default_theme = dark/default_theme = light/' /etc/grafana/grafana.ini
sed -i '/;default_home_dashboard_path =/a default_home_dashboard_path = /var/lib/grafana/dashboards/sitespeed/Welcome to sitespeed.io.json' /etc/grafana/grafana.ini
sed -i 's/CapabilityBoundingSet=/&CAP_NET_BIND_SERVICE/' /usr/lib/systemd/system/grafana-server.service
sed -i '/CAP_NET_BIND_SERVICE/a AmbientCapabilities=CAP_NET_BIND_SERVICE' /usr/lib/systemd/system/grafana-server.service
sed -i '/AmbientCapabilities=CAP_NET_BIND_SERVICE/a PrivateUsers=false' /usr/lib/systemd/system/grafana-server.service
systemctl daemon-reload

# Install Grafana plugin
grafana-cli plugins install yesoreyeram-boomtable-panel

# Create Grafana dashboard folders
mkdir -p /var/lib/grafana/dashboards/apis
mkdir /var/lib/grafana/dashboards/google
mkdir /var/lib/grafana/dashboards/lyra
mkdir /var/lib/grafana/dashboards/sitespeed
mkdir /var/lib/grafana/dashboards/ds2

# Create Graphite/Grafana working folder
mkdir /usr/local/graphite

# Extract Grafana provisioning script and set the correct permissions
tar --warning=none --no-same-owner -C /usr/local/graphite -xf /grafana.tgz *.sh
chmod 755 /usr/local/graphite/provision.sh

# Execute the provisioning script
/usr/local/graphite/provision.sh

# Start Grafana
systemctl --now enable grafana-server

# Configure firewall
firewall-cmd --permanent --zone=public --add-service=http
firewall-cmd --permanent --zone=public --add-service=https
firewall-cmd --permanent --zone=public --add-port=2003/tcp
firewall-cmd --permanent --zone=public --add-port=8888/tcp
firewall-cmd --reload

# Install Docker
curl -fsSL https://get.docker.com/ | sh

# Start Docker
systemctl --now enable docker

# Extract startup and maintenance scripts
tar --warning=none --no-same-owner -C /usr/local/graphite -xf /graphite.tgz *.sh *.sql
chmod 755 /usr/local/graphite/*.sh

# Modify graphite.sh to reflect correct timezone
sed -i -r "s#\[TIMEZONE\]#$TIMEZONE#" /usr/local/graphite/graphite.sh

# Start Graphite for the first time to expose persistent volumes
/usr/local/graphite/graphite.sh start

# Modify Graphite configuration files
tar --warning=none --no-same-owner --overwrite -C /usr/local/graphite/graphite-conf -xf /graphite.tgz *.conf
chmod 666 /usr/local/graphite/graphite-storage/graphite.db

# Restart Graphite to apply new configuration changes
/usr/local/graphite/graphite.sh stop && /usr/local/graphite/graphite.sh start

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

# Set up SSH
mkdir /home/$USERNAME/.ssh
tar --warning=none --no-same-owner -C /home/$USERNAME/.ssh -xf /graphite.tgz *.pub
cat /home/$USERNAME/.ssh/jump-*.pub > /home/$USERNAME/.ssh/authorized_keys
cat /home/$USERNAME/.ssh/sitespeed.pub >> /home/$USERNAME/.ssh/authorized_keys
rm /home/$USERNAME/.ssh/*.pub
chmod 600 /home/$USERNAME/.ssh/authorized_keys
chown $USERNAME /home/$USERNAME/.ssh/authorized_keys
chgrp $USERNAME /home/$USERNAME/.ssh/authorized_keys

# Install Certbot components
yum -y install dnf && dnf -y install epel-release 
yum -y install snapd && systemctl --now enable snapd
systemctl daemon-reload
snap install core
ln -s /var/lib/snapd/snap /snap
snap install --classic certbot
ln -s /snap/bin/certbot /usr/bin/certbot
