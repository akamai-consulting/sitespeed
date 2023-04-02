#!/bin/bash

############################################
#                                          #
#              sitespeed.sh                #
#                  v 51                    #
#                                          #
############################################

# Set variables
SitespeedVer="sitespeedio/sitespeed.io:26.1.0"
Domain=[DOMAIN]
Root=/usr/local/sitespeed

ChromeLAN="--browsertime.connectivity.alias LAN"
ChromeLTE="-c custom --browsertime.connectivity.alias LTE --downstreamKbps 12000 --upstreamKbps 12000 --latency 35 --connectivity.engine throttle --chrome.CPUThrottlingRate 4 --mobile"
Pragma="--requestheader Pragma:akamai-x-get-cache-key,akamai-x-cache-on,akamai-x-cache-remote-on,akamai-x-get-true-cache-key,akamai-x-check-cacheable,akamai-x-get-request-id"

# Print help
if [[ "$1" == "--help" || "$1" == "-h" || "$1" == "/?" || $# -eq 0 ]]; then
   echo -e "\nUsage: master arg1 arg2 arg3 [arg4]"
   echo -e "\targ1: Test type"
   echo -e "\targ2: Test name"
   echo -e "\targ3: Test location"
   echo -e "\targ4: Test iterations\n"
   exit 1
fi

# Check for the correct number of arguments
if [[ $# -ne 3 && $# -ne 4 ]]; then
   echo -e "\nmaster requires 3 OR 4 arguments\n"
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
   weblan=tldlan
   webmobile=tldmobile
 else
   graphdir=Competitors
   weblan=complan
   webmobile=compmobile
fi

# Check that config.json exists
if [ ! -f $Root/$1/config.json ]; then
   echo -e "\n$Root/$1/config.json does not exist\n"
   exit 1
fi

# Check that a seed file exists
if [ -f "$Root/$1/$2.txt" ]; then
   url=$2.txt
  else
   echo -e "\n$Root/$1/$2.txt does not exist\n"
   exit 1
fi

# Set number of test iterations
if [ $# -eq 3 ]; then
   ITR=3
  else
   if [ $(($4%2)) -eq 0 ]; then
      echo -e "\nTest iterations must be an odd number\n"
      exit 1
     else
      ITR=$4
    fi
fi

# Capture start of the entire run
start=`date +%s`

# Run Docker tests for both LAN and Mobile
for (( index=1; index < 3 ; index+=1 ))
  do
    case $index in
      1 ) TestType=LTE
          DockerCmds="--rm --name $2-`date +%s` --cap-add=NET_ADMIN"
          if [ "$1" == "tld" ]; then
             SitespeedDirs="${ChromeLTE} ${Pragma}"
            else
             SitespeedDirs=$ChromeLTE
          fi
          sudo sysctl net.ipv4.ip_forward | grep 0 &> /dev/null
          if [ $? -eq 0 ]; then
            sudo sysctl net.ipv4.ip_forward=1
          fi
          sudo modprobe -c | grep ifb &> /dev/null
          if [ $? -eq 1 ]; then
            sudo modprobe ifb numifbs=1
          fi
          ;;

      2 ) TestType=LAN
          DockerCmds="--rm --name $2-`date +%s`"   
          if [ "$1" == "tld" ]; then
             SitespeedDirs="${ChromeLAN} ${Pragma}"
            else
             SitespeedDirs=$ChromeLAN
          fi
          ;;
    esac
    RptName="$2 on Chrome over $TestType in $3"
    teststart=`date +%s`
    echo "|=============================================================================="
    echo "| $TestType start: $(TZ='[TIMEZONE]' date): $0 $@"
    echo "|=============================================================================="

    docker run \
     $DockerCmds \
     -e TZ=[TIMEZONE] \
     -e MAX_OLD_SPACE_SIZE=4096 \
     -v $Root/$1:/sitespeed.io \
     -v /etc/localtime:/etc/localtime:ro \
     $SitespeedVer \
     -n $ITR \
     --config config.json \
     --resultBaseURL "http://$3.$Domain/$1/sitespeed-result" \
     $SitespeedDirs \
     --name "$RptName" \
     --slug $3 \
     --graphite.namespace sitespeed_io.$graphdir.$2 \
     $url

    end=`date +%s`
    runtime=$((end-teststart))
    hours=$((runtime / 3600))
    minutes=$(( (runtime % 3600) / 60 ))
    seconds=$(( (runtime % 3600) % 60 ))
    echo "$TestType End: $(TZ='[TIMEZONE]' date): $0 $@  Duration: $hours:$minutes:$seconds" >> $Root/logs/$1.$2.run.log
  done

# Move the generated images to the correct location 
if [ ! -d $Root/portal/images/$2 ]; then
   sudo mkdir -p $Root/portal/images/$2
fi
domainList=$(cat $Root/$1/$2.txt | awk '{print $3}' | uniq )
for domain in $domainList
  do
    sudo mv -f $Root/$1/sitespeed-result/$3/"$domain"* $Root/portal/images/$2/ &> /dev/null
  done

# Capture the end of the entire run, but do not log locally
end=`date +%s`
runtime=$((end-start))

# Log the test duration
echo "sitespeed_log.$graphdir.$2.$3.duration $runtime `date +%s`" | nc graphite.$Domain 2003

# Set the symlink for nginx root directive to point to the latest LAN index.html
sudo ln -nsf $(find $Root/$1/sitespeed-result/ -maxdepth 3 -name index.html | xargs ls -Art | tail -n 1 | xargs dirname) $Root/portal/$weblan

# Set the symlink for nginx root directive to point to the latest Mobile index.html
sudo ln -nsf $(find $Root/$1/sitespeed-result/ -maxdepth 3 -name index.html | xargs ls -Art | tail -n 2 | xargs ls -At | tail -n 1 | xargs dirname) $Root/portal/$webmobile
