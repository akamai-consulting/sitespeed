#!/bin/bash

############################################
#                                          #
#            maintenance.sh                #
#                 v 2                      #
#                                          #
############################################

# Associated cron entry on jump
# 1 0 * * * ./maintenance.sh &>> ~/logs/maintenance.log
#

# Set variables
Regions="US-East US-Central US-West Toronto London Frankfurt Singapore Tokyo Mumbai Sydney"
Domain="sitespeed.akadns.net"

# Mark the start of the run
echo "|=========================================================="
echo "| Start: $(TZ='America/New_York' date) $0"
echo "|=========================================================="

# Clean Docker images
echo -e "\nPerforming Docker cleanup"
for region in $Regions
  do
   echo -n "Starting "$region" ... "
   ssh "$region".$Domain docker system prune --all --volumes -f &> /dev/null
   echo "done"
  done
   
echo -n "Starting PSI-CrUX ... "
ssh psi-crux.$Domain docker system prune --all --volumes -f &> /dev/null
echo "done"

# Delete sitespeed-result runs older than 7 days (60 * 24 * 7)
echo -e "\nDeleting old sitespeed-results"
for region in $Regions
  do
   echo -n "Starting "$region" ... "
   ssh "$region".$Domain ./clean.sh &> /dev/null
   echo "done"
  done
  
# Remove annotations older than 7 days
echo ""
echo -n "Reducing graphite.db on Graphite ... "
ssh graphite.$Domain sudo  ./sqlite.sh &> /dev/null
echo "done"

exit 0
