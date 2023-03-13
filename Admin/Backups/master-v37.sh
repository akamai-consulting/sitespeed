#!/bin/bash

############################################
#                                          #
#                master.sh                 #
#                  v 37                    #
#                                          #
############################################

# Set variables
SitespeedVer="sitespeedio/sitespeed.io:25.11.0"
regions="US-East US-Central US-West Toronto London Frankfurt Singapore Tokyo Mumbai Sydney"
Domain="sitespeed.akadns.net"
ChromeLAN="--browsertime.connectivity.alias LAN"
ChromeLTE="-c custom --browsertime.connectivity.alias LTE --downstreamKbps 12000 --upstreamKbps 12000 --latency 35 --connectivity.engine throttle --chrome.CPUThrottlingRate 4 --mobile"
Pragma="--requestheader Pragma:akamai-x-get-cache-key,akamai-x-cache-on,akamai-x-cache-remote-on,akamai-x-get-true-cache-key,akamai-x-check-cacheable,akamai-x-get-request-id"

# Check to see if previous sitespeed-result exists
if [ ! -d $(pwd)/$1/sitespeed-result ]; then
   runNginx=true
fi

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
if [ ! -f $(pwd)/$1/config.json ]; then
   echo -e "\n$(pwd)/$1/config.json does not exist\n"
   exit 1
fi

# Check that a seed file exists
if [ -f "$(pwd)/$1/$2.txt" ]; then
   url=$2.txt
  else
   echo -e "\n$(pwd)/$1/$2.txt does not exist\n"
   exit 1
fi

# Check that the correct test location has been entered
echo $regions | tr ' ' '\n' | grep -F -x -q $3
if [ $? -eq 1 ]; then
   echo -e "\nIncorrect region was entered. Valid regions are:"
   echo -e "\n$regions\n"
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

# Check that ssh-agent is running which is required for graphite
ssh-add &> /dev/null
if [ $? -ne 0 ]; then 
   eval "$(ssh-agent)" &> /dev/null
   ssh-add &> /dev/null
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
    echo "| $TestType start: $(TZ='America/New_York' date): $0 $@"
    echo "|=============================================================================="

    docker run \
     $DockerCmds \
     -e TZ=America/New_York \
     -v $(pwd)/$1:/sitespeed.io \
     -v /etc/localtime:/etc/localtime:ro \
     $SitespeedVer \
     -n $ITR \
     --config config.json \
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
    echo "$TestType End: $(TZ='America/New_York' date): $0 $@  Duration: $hours:$minutes:$seconds" >> $(pwd)/logs/$1.$2.run.log
  done

# Move the generated images to the correct location 
if [ ! -d $(pwd)/portal/images/$2 ]; then
   mkdir -p $(pwd)/portal/images/$2
fi
domainList=$(cat $(pwd)/$1/$2.txt | awk '{print $3}' | uniq )
for domain in $domainList
  do
    mv -f $(pwd)/$1/sitespeed-result/$3/"$domain"* $(pwd)/portal/images/$2/
  done

# Capture the end of the entire run, but do not log locally
end=`date +%s`
runtime=$((end-start))

# Executed for each test on each server
echo "sitespeed_log.$graphdir.$2.$3.duration $runtime `date +%s`" | nc graphite.$Domain 2003
echo "sitespeed_log.$graphdir.$2.$3.images `du -s $(pwd)/portal/images/$2 | awk '{print $1}'` `date +%s`" | nc graphite.$Domain 2003
ErrorCnt=$(grep ERROR ~/logs/$1.$2.msg.log | wc -l)
echo "sitespeed_log.$graphdir.$2.$3.errors $ErrorCnt `date +%s`" | nc graphite.$Domain 2003
echo "sitespeed_log.$graphdir.$2.$3.disk `ssh graphite.$Domain du -s graphite-storage/whisper/sitespeed_io/$graphdir/$2/$3 | awk '{print $1}'` `date +%s`" | nc graphite.$Domain 2003

# Executed only from US-East
if [ "$3" == "US-East" ]; then
   echo "sitespeed_log.disk `ssh graphite.$Domain du -s graphite-storage/whisper/sitespeed_io | awk '{print $1}'` `date +%s`" | nc graphite.$Domain 2003
   echo "sitespeed_log.$graphdir.disk `ssh graphite.$Domain du -s graphite-storage/whisper/sitespeed_io/$graphdir | awk '{print $1}'` `date +%s`" | nc graphite.$Domain 2003
   echo "sitespeed_log.$graphdir.$2.disk `ssh graphite.$Domain du -s graphite-storage/whisper/sitespeed_io/$graphdir/$2 | awk '{print $1}'` `date +%s`" | nc graphite.$Domain 2003
fi

# Set the symlink for nginx root directive to point to the latest LAN index.html
ln -nsf $(find $(pwd)/$1/sitespeed-result/ -maxdepth 3 -name index.html | xargs ls -Art | tail -n 1 | xargs dirname) $(pwd)/portal/$weblan

# Set the symlink for nginx root directive to point to the latest Mobile index.html
ln -nsf $(find $(pwd)/$1/sitespeed-result/ -maxdepth 3 -name index.html | xargs ls -Art | tail -n 2 | xargs ls -At | tail -n 1 | xargs dirname) $(pwd)/portal/$webmobile

# Delete the older sitespeed-result runs
find $(pwd)/$1/sitespeed-result/$3/ -mmin +120 | xargs rm -rf

# Run nginx.sh iff previous sitespeed-result did not exist
if [ "$runNginx" = true ]; then
  $(sudo ~/nginx.sh &> /dev/null)
fi
