#!/bin/bash

############################################
#                                          #
#            maintenance.sh                #
#                 v 5                      #
#                                          #
############################################

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
   echo "sitespeed_log.Core.$region.core `ssh -i ~/.ssh/sitespeed-2023-01-24 $region.$Domain find ~/ -maxdepth 2 -name core* -type f | wc -l` `date +%s`" | nc graphite.$Domain 2003
   echo "done"
  done  

# Log disk usage on Graphite
echo ""
echo -n "Logging disk usage on Graphite ... "

echo "sitespeed_log.disk `ssh -i ~/.ssh/sitespeed-2023-01-24 graphite.$Domain du -s graphite-storage/whisper/sitespeed_io | awk '{print $1}'` `date +%s`" | nc graphite.$Domain 2003
echo "sitespeed_log.TLD.disk `ssh -i ~/.ssh/sitespeed-2023-01-24 graphite.$Domain du -s graphite-storage/whisper/sitespeed_io/TLD | awk '{print $1}'` `date +%s`" | nc graphite.$Domain 2003
echo "sitespeed_log.Competitors.disk `ssh -i ~/.ssh/sitespeed-2023-01-24 graphite.$Domain du -s graphite-storage/whisper/sitespeed_io/Competitors | awk '{print $1}'` `date +%s`" | nc graphite.$Domain 2003
echo "done"

# Clean Docker images
echo -e "\nPerforming Docker cleanup"
for region in $Regions
  do
   echo -n "Starting "$region" ... "
   ssh -i ~/.ssh/sitespeed-2023-01-24 "$region".$Domain docker system prune --all --volumes -f &> /dev/null
   echo "done"
  done
     
# Remove Graphite annotations older than 7 days
echo ""
echo -n "Reducing graphite.db on Graphite ... "
ssh -i ~/.ssh/sitespeed-2023-01-24 graphite.$Domain sudo ~/sqlite.sh &> /dev/null
echo "done"

# Delete sitespeed-result runs older than 7 days (60 * 24 * 7)
Regions="US-East US-Central US-West Toronto London Frankfurt Singapore Tokyo Mumbai Sydney"
echo -e "\nDeleting old sitespeed-results"
for region in $Regions
  do
   echo -n "Starting "$region" ... "
   ssh -i ~/.ssh/sitespeed-2023-01-24 "$region".$Domain find ~/ -maxdepth 4 -type d -name 20* -mmin +10080 -exec rm -Rf {} +;
   echo "done"
  done

exit 0
