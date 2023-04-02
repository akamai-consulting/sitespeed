#!/bin/bash

############################################
#                                          #
#               google.sh                  #
#                  v 15                    #
#                                          #
############################################

# Set variables
SitespeedVer=sitespeedio/sitespeed.io:26.1.0-plus1
Domain=[DOMAIN]
Root=/usr/local/sitespeed

# Print help
if [[ "$1" == "--help" || "$1" == "-h" || "$1" == "/?" || $# -eq 0 ]]; then
   echo -e "\nUsage: google arg1 arg2"
   echo -e "\targ1: Test type"
   echo -e "\targ2: Test name\n"
   exit 1
fi

# Check for the correct number of arguments
if [ $# -ne 2 ]; then
   echo -e "\ngoogle requires 2 arguments\n"
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
if [ -f $Root/$1/$2.txt ]; then
   url=$2.txt
  else
   echo -e "\n$Root/$1/$2.txt does not exist\n"
   exit 1
fi

# Capture start of the entire run
start=`date +%s`

teststart=`date +%s`
echo "|=============================================================================="
echo "| Phone start: $(TZ='[TIMEZONE]' date): $0 $@"
echo "|=============================================================================="
docker run \
 --rm --name $2-`date +%s` \
 -e TZ=[TIMEZONE] \
 -e MAX_OLD_SPACE_SIZE=4096 \
 -v $Root/$1:/sitespeed.io \
 -v /etc/localtime:/etc/localtime:ro \
 $SitespeedVer \
 -n 1 \
 --mobile \
 --plugins.remove browsertime \
 --plugins.remove /lighthouse \
 --plugins.remove html \
 --gpsi.key "[API]" \
 --slug PSI-CrUX \
 --graphite.namespace sitespeed_io.$graphdir.$2 \
 --graphite.host graphite.$Domain \
 $url

echo "|=============================================================================="
echo "| Desktop start: $(TZ='[TIMEZONE]' date): $0 $@"
echo "|=============================================================================="
docker run \
 --rm --name $2-`date +%s` \
 -e TZ=[TIMEZONE] \
 -e MAX_OLD_SPACE_SIZE=4096 \
 -v $Root/$1:/sitespeed.io \
 -v /etc/localtime:/etc/localtime:ro \
 $SitespeedVer \
 -n 1 \
 --plugins.remove browsertime \
 --plugins.remove /lighthouse \
 --plugins.remove html \
 --gpsi.key "[API]" \
 --crux.key "[API]" \
 --crux.formFactor "DESKTOP" \
 --crux.formFactor "PHONE" \
 --crux.collect "ALL" \
 --slug PSI-CrUX \
 --graphite.namespace sitespeed_io.$graphdir.$2 \
 --graphite.host graphite.$Domain \
 $url
 
end=`date +%s`
runtime=$((end-teststart))
hours=$((runtime / 3600))
minutes=$(( (runtime % 3600) / 60 ))
seconds=$(( (runtime % 3600) % 60 ))
echo "$TestType End: $(TZ='[TIMEZONE]' date): $0 $@  Duration: $hours:$minutes:$seconds" >> $Root/logs/$1.$2.run.log

# Capture the end of the entire run
end=`date +%s`
runtime=$((end-start))

# Log the test duration
echo "sitespeed_log.PSI-CrUX.$graphdir.$2.duration $runtime `date +%s`" | nc graphite.$Domain 2003

# Remove sitespeed_io structure
sudo rm -Rf $Root/$1/sitespeed-result
