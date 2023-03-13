#!/bin/bash

############################################
#                                          #
#            maintenance.sh                #
#                 v 6                      #
#                                          #
############################################

# Set variables
Regions="PSI-CrUX US-East US-Central US-West Toronto London Frankfurt Singapore Tokyo Mumbai Sydney"
Domain="sitespeed.akadns.net"
Key="sitespeed-2023-01-24"

# Mark the start of the run
echo -e "\n|=========================================================="
echo "| Start: $(TZ='America/New_York' date) $0"
echo "|=========================================================="

# Count the number of core dumps
echo -e "\nCount the number of core dumps"
for region in $Regions
  do
   echo -n "Counting "$region" ... "
   echo "sitespeed_log.$region.core `ssh -i ~/.ssh/$Key $region.$Domain find ~/ -maxdepth 2 -name core* -type f | wc -l` `date +%s`" | nc graphite.$Domain 2003
   echo "done"
  done
  
# Log disk usage on each server
echo -e "\nLog disk usage on each server"
for region in $Regions
  do
   echo -n "Logging "$region" ... "
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

# Clean Docker images
echo -e "\nPerform Docker cleanup"
for region in $Regions
  do
   echo -n "Starting "$region" ... "
   ssh -i ~/.ssh/$Key "$region".$Domain docker system prune --all --volumes -f &> /dev/null
   echo "done"
  done
     
# Remove Graphite annotations older than 7 days
echo ""
echo -n "Reduce size of graphite.db on Graphite ... "
ssh -i ~/.ssh/$Key graphite.$Domain sudo ~/sqlite.sh &> /dev/null
echo "done"

# Delete Sitespeed runs older than 7 days (60 * 24 * 7)
Regions="US-East US-Central US-West Toronto London Frankfurt Singapore Tokyo Mumbai Sydney"
echo -e "\nDelete old Sitespeed results"
for region in $Regions
  do
   echo -n "Starting "$region" ... "
   ssh -i ~/.ssh/$Key "$region".$Domain find ~/ -maxdepth 4 -type d -name 20* -mmin +10080 -exec rm -Rf {} +;
   echo "done"
  done

exit 0
