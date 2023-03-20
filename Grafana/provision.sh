#!/bin/bash

#########################################
#                                       #
#             provision.sh              #
#                  v 1                  #
#                                       #
#########################################

# Make sure the script runs as root
if [ "$EUID" -ne 0 ]
  then echo -e "\nNeed to run script as root\n"
  exit 1
fi

# Download latest file
wget -q -O /grafana.tgz https://as.akamai.com/user/sitespeed/grafana.tgz

# Perform provisioning update
if [ "$1" == "update" ]; then
  tar --warning=none --no-same-owner --overwrite -C / -xf /grafana.tgz provision.sh
  exit 0
fi
  
# Extract the provisioning files
tar --warning=none --no-same-owner --overwrite -C /etc/grafana/provisioning/datasources -xf /grafana.tgz graphite.yaml
tar --warning=none --no-same-owner --overwrite -C /etc/grafana/provisioning/dashboards -xf /grafana.tgz sitespeed.yaml apis.yaml google.yaml lyra.yaml ds2.yaml
tar --warning=none --no-same-owner --overwrite -C /var/lib/grafana/dashboards/google -xf /grafana.tgz Chrome*.json Light*.json
tar --warning=none --no-same-owner --overwrite -C /var/lib/grafana/dashboards/sitespeed -xf /grafana.tgz Site*.json Page*.json Leader*.json Geo*.json Welcome*.json

# Set the correct Grafana permissions
chgrp -R grafana /etc/grafana/provisioning/
chmod -R 755 /etc/grafana/provisioning/

# Restart Grafana only if it is running
systemctl status grafana-server > /dev/null
if [ $? -eq 0 ]; then
   systemctl restart grafana-server
fi
