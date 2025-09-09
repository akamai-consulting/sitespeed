#!/bin/bash

############################################
#                                          #
#         sitespeed-google.sh              #
#                 v36                      #
#           Ubuntu 24.04 LTS               #
#         Author gwolf@akamai.com          #
#                                          #
############################################

# <UDF name="USERNAME" Label="Name of admin user" />
# <UDF name="SITEKEY" Label="SSH public key for access from Jump server" />
# <UDF name="DOMAIN" Label="Primary domain name" Example="Example i.e., sitespeed.akamai.com" />
# <UDF name="API" Label="Google API Key" />

# Update the OS
apt -y update
apt -y upgrade

# Install packages
apt -y install tree net-tools

# Update the system timezone
case $LINODE_DATACENTERID in
  4 | 6 | 17 | 28 ) timedatectl set-timezone America/New_York
  					TIMEZONE=America/New_York ;;
                  
      	   2 | 18 ) timedatectl set-timezone America/Chicago
      	   			TIMEZONE=America/Chicago ;;
      
      3 | 20 | 30 ) timedatectl set-timezone America/Los_Angeles
      				TIMEZONE=America/Los_Angeles ;;
               		
               21 ) timedatectl set-timezone America/Sao_Paulo
               		TIMEZONE=America/Sao_Paulo ;;             		
  
          	   15 ) timedatectl set-timezone America/Toronto
          	   		TIMEZONE=America/Toronto ;;
          	   		
     14 | 25 | 46 ) timedatectl set-timezone Asia/Istanbul
     				TIMEZONE=Asia/Istanbul ;;
          	   		
           	   29 ) timedatectl set-timezone Asia/Jakarta
           	   		TIMEZONE=Asia/Jakarta ;;          	   		
          	   		
           9 | 48 ) timedatectl set-timezone Asia/Singapore
      	   			TIMEZONE=Asia/Singapore ;;
  
     11 | 26 | 49 ) timedatectl set-timezone Asia/Tokyo
     				TIMEZONE=Asia/Tokyo ;;
      	   		
           	   45 ) timedatectl set-timezone Australia/Melbourne
           	   		TIMEZONE=Australia/Melbourne ;;
                        	   		
               16 ) timedatectl set-timezone Australia/Sydney
               		TIMEZONE=Australia/Sydney ;;
  
     10 | 27 | 47 ) timedatectl set-timezone CET
     				TIMEZONE=CET ;;

           	   22 ) timedatectl set-timezone Europe/Amsterdam
           	   		TIMEZONE=Europe/Amsterdam ;;
     
           7 | 44 ) timedatectl set-timezone Europe/London
           			TIMEZONE=Europe/London ;;
 
        	   24 ) timedatectl set-timezone Europe/Madrid
        	   		TIMEZONE=Europe/Madrid ;;
 
        	   19 ) timedatectl set-timezone Europe/Paris
        	   		TIMEZONE=Europe/Paris ;;
        	   		
        	   23 ) timedatectl set-timezone Europe/Stockholm
        	   		TIMEZONE=Europe/Stockholm ;;
esac

# Set the hostname
hostnamectl set-hostname Google

# Download configurations files
wget https://as.akamai.com/user/sitespeed/google.tgz

# Create admin user
useradd -m -s /bin/bash $USERNAME
mkdir /home/$USERNAME/.ssh
echo $SITEKEY > /home/$USERNAME/.ssh/authorized_keys
chown -R $USERNAME /home/$USERNAME/.ssh
chgrp -R $USERNAME /home/$USERNAME/.ssh
chmod 600 /home/$USERNAME/.ssh/authorized_keys

# Create sitespeed user
useradd -m -s /bin/bash sitespeed
mkdir /home/sitespeed/.ssh
echo $SITEKEY > /home/sitespeed/.ssh/authorized_keys
chown -R sitespeed /home/sitespeed/.ssh
chgrp -R sitespeed /home/sitespeed/.ssh
chmod 600 /home/sitespeed/.ssh/authorized_keys

# Enable sudo permission for admin and sitespeed
sudo chmod 640 /etc/sudoers
sudo echo $USERNAME 'ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
sudo echo sitespeed 'ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
sudo chmod 440 /etc/sudoers

# Harden file system
sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart ssh

# Refresh the OS
apt -y update
apt -y upgrade

# Install Docker
apt -y install apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
apt -y update
apt-cache policy docker-ce
apt -y install docker-ce

# Add admin and sitespeed to appropriate groups
usermod -aG docker sitespeed
usermod -aG docker $USERNAME
usermod -aG sitespeed $USERNAME

# Create Sitespeed folder structure
mkdir -p /usr/local/sitespeed/comp
mkdir /usr/local/sitespeed/tld
mkdir /usr/local/sitespeed/logs
mkdir /usr/local/sitespeed/config

# Create config files
echo $DOMAIN > /usr/local/sitespeed/config/domain
echo $TIMEZONE > /usr/local/sitespeed/config/timezone
echo $API > /usr/local/sitespeed/config/api

# Extract TAR files into appropriate folders
tar --warning=none --no-same-owner -C /usr/local/sitespeed -xf /google.tgz google.sh

# Set Sitespeed folder ownership and permissions
chgrp -R sitespeed /usr/local/sitespeed
chmod -R 775 /usr/local/sitespeed
chmod 664 /usr/local/sitespeed/tld/config.json 
chmod 664 /usr/local/sitespeed/comp/config.json

# Set Sitespeed folder ownership and permissions
chgrp -R sitespeed /usr/local/sitespeed
chmod -R 775 /usr/local/sitespeed

# Enable the firewall
ufw enable
ufw allow ssh
ufw reload

# Refresh the OS
apt -y update
apt -y upgrade

# Install the Guardicore agent
export UI_UM_PASSWORD='8X2AG0OQwq5rGRT6BNHS'
export GC_PROFILE='advsol'
export SSL_ADDRESSES="aggr-customer-60196557.cloud.guardicore.com:443"
wget https://aggr-customer-60196557.cloud.guardicore.com/guardicore-cas-chain-file.pem --no-check-certificate -O /tmp/guardicore_cas_chain_file.pem
SHA256SUM_VALUE=`sha256sum /tmp/guardicore_cas_chain_file.pem | awk '{print $1;}'`
export INSTALLATION_CMD='wget --ca-certificate /tmp/guardicore_cas_chain_file.pem -O- https://aggr-customer-60196557.cloud.guardicore.com | sudo -E bash'
if [ $SHA256SUM_VALUE == 270e761af94e1f733b2c5ad16818f4ac25f78b03ea21dd2e42889457a7175959 ]; then eval $INSTALLATION_CMD; else echo "Certificate checksum mismatch error"; fi

# Refresh the OS
apt -y update
apt -y upgrade
