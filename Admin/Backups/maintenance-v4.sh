#!/bin/bash

############################################
#                                          #
#            maintenance.sh                #
#                 v 4                      #
#                                          #
############################################

# Associated cron entry on jump
# 1 0 * * * ./maintenance.sh &>> ~/logs/maintenance.log

# Set variables
Regions="PSI-CrUX US-East US-Central US-West Toronto London Frankfurt Singapore Tokyo Mumbai Sydney"
Domain="sitespeed.akadns.net"

# Mark the start of the run
echo -e "\n|=========================================================="
echo "| Start: $(TZ='America/New_York' date) $0"
echo "|=========================================================="

# Log count of core dumps
echo -e "\nLog the count of core dumps"
for region in $Regions
  do
   echo -n "Counting "$region" ... "
   echo "sitespeed_log.Core.$region.core `ssh $region.$Domain find ~/ -maxdepth 2 -name core* -type f | wc -l` `date +%s`" | nc graphite.$Domain 2003
   echo "done"
  done  

# Log disk usage on Graphite
echo ""
echo -n "Logging disk usage on Graphite ... "
echo "sitespeed_log.disk `ssh graphite.$Domain du -s graphite-storage/whisper/sitespeed_io | awk '{print $1}'` `date +%s`" | nc graphite.$Domain 2003
echo "sitespeed_log.TLD.disk `ssh graphite.$Domain du -s graphite-storage/whisper/sitespeed_io/TLD | awk '{print $1}'` `date +%s`" | nc graphite.$Domain 2003
echo "sitespeed_log.Competitors.disk `ssh graphite.$Domain du -s graphite-storage/whisper/sitespeed_io/Competitors | awk '{print $1}'` `date +%s`" | nc graphite.$Domain 2003
echo "done"

# Clean Docker images
echo -e "\nPerforming Docker cleanup"
for region in $Regions
  do
   echo -n "Starting "$region" ... "
   ssh "$region".$Domain docker system prune --all --volumes -f &> /dev/null
   echo "done"
  done
     
# Remove Graphite annotations older than 7 days
echo ""
echo -n "Reducing graphite.db on Graphite ... "
ssh graphite.$Domain sudo  ./sqlite.sh &> /dev/null
echo "done"

Regions="US-East US-Central US-West Toronto London Frankfurt Singapore Tokyo Mumbai Sydney"
# Delete sitespeed-result runs older than 7 days (60 * 24 * 7)
echo -e "\nDeleting old sitespeed-results"
for region in $Regions
  do
   echo -n "Starting "$region" ... "
   ssh "$region".$Domain find ~/ -maxdepth 4 -type d -name 20* -mmin +10080 -exec rm -Rf {} +;
   echo "done"
  done
   
exit 0
