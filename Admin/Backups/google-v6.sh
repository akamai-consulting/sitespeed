#!/bin/bash

############################################
#                                          #
#               google.sh                  #
#                  v 6                     #
#                                          #
############################################

# Set variable
SitespeedVer="sitespeedio/sitespeed.io:26.0.1-plus1"
Regions="PSI-CrUX"
Domain="sitespeed.akadns.net"

# Print help
if [[ "$1" == "--help" || "$1" == "-h" || "$1" == "/?" || $# -eq 0 ]]; then
   echo -e "\nUsage: google arg1 arg2 arg3"
   echo -e "\targ1: Test type"
   echo -e "\targ2: Test name"
   echo -e "\targ3: Test location\n"
   exit 1
fi

# Check for the correct number of arguments
if [ $# -ne 3 ]; then
   echo -e "\ngoogle requires 3 arguments\n"
   exit 1
fi

# Check the correct test type has been entered
echo "tld comp" | tr ' ' '\n' | grep -F -x -q $1
if [ $? -ne 0 ]; then 
   echo -e "\narg1 must be tld|comp\n"
   exit 1
fi

# Set variables to point to correct directory
if [ "$1" == "tld" ]; then
   graphdir=TLD
 else
   graphdir=Competitors
fi

# Check that a seed file exists
if [ -f "$(pwd)/$1/$2.txt" ]; then
   url=$2.txt
  else
   echo -e "\n$(pwd)/$1/$2.txt does not exist\n"
   exit 1
fi

# Check that the correct test location has been entered
echo $Regions | tr ' ' '\n' | grep -F -x -q $3
if [ $? -eq 1 ]; then
   echo -e "\nIncorrect region was entered. Valid regions are:"
   echo -e "\n$Regions\n"
   exit 1
fi

# Capture start of the entire run
start=`date +%s`

teststart=`date +%s`
echo "|=============================================================================="
echo "| LTE start: $(TZ='America/New_York' date): $0 $@"
echo "|=============================================================================="
docker run \
 --rm --name $2-`date +%s` \
 -e TZ=America/New_York \
 -e MAX_OLD_SPACE_SIZE=4096 \
 -v $(pwd)/$1:/sitespeed.io \
 -v /etc/localtime:/etc/localtime:ro \
 $SitespeedVer \
 -n 1 \
 --mobile \
 --plugins.remove browsertime \
 --plugins.remove /lighthouse \
 --plugins.remove html \
 --gpsi.key "AIzaSyDTIKCKpo6Ka7s-zIkkvy36gi94KvdQ9RU" \
 --slug $3 \
 --graphite.namespace sitespeed_io.$graphdir.$2 \
 --graphite.host 198.74.57.70 \
 $url

echo "|=============================================================================="
echo "| LAN start: $(TZ='America/New_York' date): $0 $@"
echo "|=============================================================================="
docker run \
 --rm --name $2-`date +%s` \
 -e TZ=America/New_York \
 -e MAX_OLD_SPACE_SIZE=4096 \
 -v $(pwd)/$1:/sitespeed.io \
 -v /etc/localtime:/etc/localtime:ro \
 $SitespeedVer \
 -n 1 \
 --plugins.remove browsertime \
 --plugins.remove /lighthouse \
 --plugins.remove html \
 --gpsi.key "AIzaSyDTIKCKpo6Ka7s-zIkkvy36gi94KvdQ9RU" \
 --crux.key "AIzaSyDTIKCKpo6Ka7s-zIkkvy36gi94KvdQ9RU" \
 --crux.formFactor "DESKTOP" \
 --crux.formFactor "PHONE" \
 --crux.collect "ALL" \
 --slug $3 \
 --graphite.namespace sitespeed_io.$graphdir.$2 \
  --graphite.host 198.74.57.70 \
 $url
 
end=`date +%s`
runtime=$((end-teststart))
hours=$((runtime / 3600))
minutes=$(( (runtime % 3600) / 60 ))
seconds=$(( (runtime % 3600) % 60 ))
echo "$TestType End: $(TZ='America/New_York' date): $0 $@  Duration: $hours:$minutes:$seconds" >> $(pwd)/logs/$1.$2.run.log

# Capture the end of the entire run
end=`date +%s`
runtime=$((end-start))

# Log the test duration and error count
echo "sitespeed_log.$graphdir.$2.$3.duration $runtime `date +%s`" | nc graphite.$Domain 2003
echo "sitespeed_log.$graphdir.$2.$3.errors $(grep -i error ~/logs/$1.$2.msg.log | wc -l) `date +%s`" | nc graphite.$Domain 2003

# Remove sitespeed_io structure
rm -Rf $1/sitespeed-result
