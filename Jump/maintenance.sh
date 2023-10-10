#!/bin/bash

############################################
#                                          #
#            maintenance.sh                #
#                 v 23                     #
#                                          #
############################################

# Set global variables
Key=$HOME/.ssh/sitespeed
Root=/usr/local/sitespeed
Domain=$(cat $Root/config/domain)
Dow=$(date +%A)

# Read servers and set Servers variable
Servers=""
end=$(cat /usr/local/sitespeed/config/servers | wc -l)
exec 3</usr/local/sitespeed/config/servers
read data <&3
for (( index=1; index <= $end; index+=1 ))
  do
    Servers="$Servers$data "
    read data <&3
  done
  
# Mark the start of the run
echo -e "\n|=========================================================="
echo "| Start: $(date) $0"
echo "|=========================================================="

# Count the number of core dumps and errors on each server
All="google $Servers"
echo -e "\nCount the number of core dumps and errors"
for region in $All
  do
   echo -n "Processing "$region" ... "
   if [ "$region" == "google" ]; then
      echo "sitespeed_log.PSI-CrUX.core `ssh -i $Key $(whoami)@$region.$Domain find $Root/ -maxdepth 2 -name core* -type f | wc -l` `date +%s`" | nc graphite.$Domain 2003 &> /dev/null
      echo "sitespeed_log.PSI-CrUX.errors `ssh -i $Key $(whoami)@$region.$Domain grep -i error $Root/logs/*.msg.log | wc -l` `date +%s`" | nc graphite.$Domain 2003 &> /dev/null
    else
      echo "sitespeed_log.$region.core `ssh -i $Key $(whoami)@$region.$Domain find $Root/ -maxdepth 2 -name core* -type f | wc -l` `date +%s`" | nc graphite.$Domain 2003 &> /dev/null
      echo "sitespeed_log.$region.errors `ssh -i $Key $(whoami)@$region.$Domain grep -i error $Root/logs/*.msg.log | wc -l` `date +%s`" | nc graphite.$Domain 2003 &> /dev/null
   fi
   echo "done"
  done

# Clean Docker images only on Sundays
if [ "$Dow" == "Sunday" ]; then
   echo -e "\nPerform Docker cleanup"
   All="google $Servers"
   for region in $All
     do
      echo -n "Starting "$region" ... "
      ssh -i $Key $(whoami)@$region.$Domain docker system prune --all --volumes -f &> /dev/null
      echo "done"
     done
fi

# Delete core dumps only on Sundays
if [ "$Dow" == "Sunday" ]; then
   echo -e "\nDeleting core dumps"
   All="google $Servers"
   for region in $All
     do
      echo -n "Starting "$region" ... "
      ssh -i $Key $(whoami)@$region.$Domain find /usr/local/sitespeed/ -type f -name core* -exec sudo rm {} +; 
      echo "done"
     done
fi

# Delete Sitespeed runs older than 7 days (60 * 24 * 7) and log disk usage of each server
echo -e "\nDelete old Sitespeed results and log disk usage of each server"
for region in $Servers
  do
   echo -n "Processing "$region" ... "
   ssh -i $Key $(whoami)@$region.$Domain find $Root/ -maxdepth 4 -type d -name 20* -mmin +10080 -exec sudo rm -Rf {} +;
   echo "sitespeed_log.$region.tld `ssh -i $Key $(whoami)@"$region".$Domain du -s $Root/tld | awk '{print $1}'` `date +%s`" | nc graphite.$Domain 2003 &> /dev/null
   echo "sitespeed_log.$region.comp `ssh -i $Key $(whoami)@"$region".$Domain du -s $Root/comp | awk '{print $1}'` `date +%s`" | nc graphite.$Domain 2003 &> /dev/null
   echo "sitespeed_log.$region.images `ssh -i $Key $(whoami)@"$region".$Domain du -s $Root/portal/images | awk '{print $1}'` `date +%s`" | nc graphite.$Domain 2003 &> /dev/null
   echo "done"
  done

# Log disk usage on Graphite
echo ""
echo -n "Log disk usage on Graphite ... "
echo "sitespeed_log.disk `ssh -i $Key $(whoami)@graphite.$Domain du -s /usr/local/graphite/graphite-storage/whisper/sitespeed_io | awk '{print $1}'` `date +%s`" | nc graphite.$Domain 2003 &> /dev/null
echo "sitespeed_log.TLD.disk `ssh -i $Key $(whoami)@graphite.$Domain du -s /usr/local/graphite/graphite-storage/whisper/sitespeed_io/TLD | awk '{print $1}'` `date +%s`" | nc graphite.$Domain 2003 &> /dev/null
echo "sitespeed_log.Competitors.disk `ssh -i $Key $(whoami)@graphite.$Domain du -s /usr/local/graphite/graphite-storage/whisper/sitespeed_io/Competitors | awk '{print $1}'` `date +%s`" | nc graphite.$Domain 2003 &> /dev/null
echo "done"
     
# Remove Graphite annotations older than 7 days
echo ""
echo -n "Removing old annotations on Graphite ... "
ssh -i $Key $(whoami)@graphite.$Domain sudo /usr/local/graphite/sqlite.sh &> /dev/null
echo "done"

exit 0
