#!/bin/bash

############################################
#                                          #
#            maintenance.sh                #
#                 v 7                      #
#                                          #
############################################

# Set global variables
Domain="sitespeed.akadns.net"
Key="sitespeed-2023-01-24"

# Mark the start of the run
echo -e "\n|=========================================================="
echo "| Start: $(TZ='America/New_York' date) $0"
echo "|=========================================================="

# Count the number of core dumps and errors on each server
Regions="PSI-CrUX US-East US-Central US-West Toronto London Frankfurt Singapore Tokyo Mumbai Sydney"
echo -e "\nCount the number of core dumps and errors"
for region in $Regions
  do
   echo -n "Processing "$region" ... "
   echo "sitespeed_log.$region.core `ssh -i ~/.ssh/$Key $region.$Domain find ~/ -maxdepth 2 -name core* -type f | wc -l` `date +%s`" | nc graphite.$Domain 2003
   echo "sitespeed_log.$region.errors `ssh -i ~/.ssh/$Key $region.$Domain grep -i error ~/logs/*.msg.log | wc -l` `date +%s`" | nc graphite.$Domain 2003
   echo "done"
  done

# Clean Docker images
echo -e "\nPerform Docker cleanup"
for region in $Regions
  do
   echo -n "Starting "$region" ... "
   ssh -i ~/.ssh/$Key "$region".$Domain docker system prune --all --volumes -f &> /dev/null
   echo "done"
  done

# Delete Sitespeed runs older than 7 days (60 * 24 * 7) and log disk usage of each server
Regions="US-East US-Central US-West Toronto London Frankfurt Singapore Tokyo Mumbai Sydney"
echo -e "\nDelete old Sitespeed results and log disk usage of each server"
for region in $Regions
  do
   echo -n "Processing "$region" ... "
   ssh -i ~/.ssh/$Key "$region".$Domain find ~/ -maxdepth 4 -type d -name 20* -mmin +10080 -exec rm -Rf {} +;
   echo "sitespeed_log.$region.tld `ssh -i ~/.ssh/$Key $region.$Domain du -s ~/tld | awk '{print $1}'` `date +%s`" | nc graphite.$Domain 2003
   echo "sitespeed_log.$region.comp `ssh -i ~/.ssh/$Key $region.$Domain du -s ~/comp | awk '{print $1}'` `date +%s`" | nc graphite.$Domain 2003
   echo "sitespeed_log.$region.images `ssh -i ~/.ssh/$Key $region.$Domain du -s ~/portal/images | awk '{print $1}'` `date +%s`" | nc graphite.$Domain 2003
   echo "done"
  done

# Log disk usage on Graphite
echo ""
echo -n "Log disk usage on Graphite ... "
echo "sitespeed_log.disk `ssh -i ~/.ssh/$Key graphite.$Domain du -s graphite-storage/whisper/sitespeed_io | awk '{print $1}'` `date +%s`" | nc graphite.$Domain 2003
echo "sitespeed_log.TLD.disk `ssh -i ~/.ssh/$Key graphite.$Domain du -s graphite-storage/whisper/sitespeed_io/TLD | awk '{print $1}'` `date +%s`" | nc graphite.$Domain 2003
echo "sitespeed_log.Competitors.disk `ssh -i ~/.ssh/$Key graphite.$Domain du -s graphite-storage/whisper/sitespeed_io/Competitors | awk '{print $1}'` `date +%s`" | nc graphite.$Domain 2003
echo "done"
     
# Remove Graphite annotations older than 7 days
echo ""
echo -n "Removing old annotations on Graphite ... "
ssh -i ~/.ssh/$Key graphite.$Domain sudo ~/sqlite.sh &> /dev/null
echo "done"

exit 0
