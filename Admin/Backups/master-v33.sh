#!/bin/bash

############################################
#                                          #
#                master.sh                 #
#                  v 33                    #
#                                          #
############################################

# Set variable for Linode regions
regions="US-East US-Central US-West Toronto London Frankfurt Singapore Tokyo Mumbai Sydney"

# Set variables to point to correct directory
case $1 in
    tld ) graphdir=TLD
          weblan=tldlan
          webmobile=tldmobile
          ;;

   comp ) graphdir=Competitors
          weblan=complan
          webmobile=compmobile
          ;;
esac

# Docker commands
Tag=`date +%s`
DockerLAN="--rm --name $2-$Tag"
DockerMobile="--rm --name $2-$Tag --cap-add=NET_ADMIN"

# Sitespeed directives
ChromeLAN="--browsertime.connectivity.alias LAN"
ChromeLTE="-c custom --browsertime.connectivity.alias LTE --downstreamKbps 12000 --upstreamKbps 12000 --latency 35 --connectivity.engine throttle --chrome.CPUThrottlingRate 4 --mobile"

# Print help
if [[ "$1" == "--help" || "$1" == "-h" || "$1" == "/?" || $# -eq 0 ]]
  then
    echo -e "\n\tUsage: master.sh arg1 arg2 arg3"
    echo -e "\targ1: Test type"
    echo -e "\targ2: Test name"
    echo -e "\targ3: Test location"
    exit 0
fi

# Check for the correct number of arguments
if [ $# -ne 3 ]
  then
    echo -e "\nmaster requires 3 arguments\n"
    exit 1
fi

# Check the correct test type has been entered
echo "tld comp" | tr ' ' '\n' | grep -F -x -q $1
if [ $? -ne 0 ]
  then 
    echo -e "\narg1 (test type) must be either tld or comp\n"
    exit 1
fi

# Check that config.json exists
if [ ! -f "$(pwd)/$1/config.json" ]
  then
   echo -e "\n$(pwd)/$1/config.json does not exist\n"
   exit 1
fi

# Check that a seed file exists
if [ -f "$(pwd)/$1/$2.txt" ]
  then
    url=$2.txt
  else
    echo -e "\n$(pwd)/$1/$2.txt does not exist\n"
    exit 1
fi

# Check that the correct test location has been entered
echo $regions | tr ' ' '\n' | grep -F -x -q $3
if [ $? -eq 1 ]
  then
    echo -e "\nIncorrect region was entered. Valid regions are:"
    echo -e "\n$regions\n"
    exit 1
fi

# Capture start of the entire run
start=`date +%s`

# Run Docker tests for both LAN and Mobile
for (( index=1; index < 3 ; index+=1 ))
  do
    case $index in
      1 ) TestType=LTE
          DockerCmds=$DockerMobile
          SitespeedDirs=$ChromeLTE
          sudo sysctl net.ipv4.ip_forward | grep 0 &> /dev/null
          if [ $? -eq 0 ]
            then sudo sysctl net.ipv4.ip_forward=1
          fi
          sudo modprobe -c | grep ifb &> /dev/null
          if [ $? -eq 1 ]
            then sudo modprobe ifb numifbs=1
          fi
          ;;

      2 ) TestType=LAN
          DockerCmds=$DockerLAN
          SitespeedDirs=$ChromeLAN
          ;;
    esac
    
    # Define the test name that will appear on HTML output
    RptName="$2 on Chrome over $TestType in $3"

    # Capture start of each test
    teststart=`date +%s`

    echo "|=============================================================================="
    echo "| $TestType start: $(TZ='America/New_York' date): $0 $@"
    echo "|=============================================================================="

    case $1 in
       tld )  docker run \
              $DockerCmds \
              -e TZ=America/New_York \
              -v $(pwd)/$1:/sitespeed.io \
              -v /etc/localtime:/etc/localtime:ro \
              sitespeedio/sitespeed.io:24.9.0 \
              --config config.json \
              $SitespeedDirs \
              --requestheader Pragma:akamai-x-cache-on,akamai-x-cache-remote-on,akamai-x-check-cacheable,akamai-x-feo-trace,akamai-x-get-cache-key,akamai-x-get-cache-tags,akamai-x-get-client-ip,akamai-x-get-extracted-values,akamai-x-get-request-id,akamai-x-get-ssl-client-session-id,akamai-x-get-true-cache-key,akamai-x-im-trace,akamai-x-rapid-debug,akamai-x-ro-trace,akamai-x-serial-no,akamai-x-tapioca-trace,akamai-x-write-v-log-line,edgegrid-fingerprints-on,edgegrid-trace-on,x-akamai-a2-trace \
              --name "$RptName" \
              --slug $3 \
              --graphite.namespace sitespeed_io.TLD.$2 \
              $url
              ;;

       comp ) docker run \
              $DockerCmds \
              -e TZ=America/New_York \
              -v $(pwd)/$1:/sitespeed.io \
              -v /etc/localtime:/etc/localtime:ro \
              sitespeedio/sitespeed.io:24.9.0 \
              --config config.json \
              $SitespeedDirs \
              --name "$RptName" \
              --slug $3 \
              --graphite.namespace sitespeed_io.Competitors.$2 \
              $url
              ;;
    esac
    end=`date +%s`
    runtime=$((end-teststart))
    hours=$((runtime / 3600))
    minutes=$(( (runtime % 3600) / 60 ))
    seconds=$(( (runtime % 3600) % 60 ))
    echo "$TestType End: $(TZ='America/New_York' date): $0 $@  Duration: $hours:$minutes:$seconds" >> $(pwd)/logs/$1.$2.run.log
done

# Move the generated images to the correct location 
if [ ! -d $(pwd)/portal/images/$2 ]
  then
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
echo "sitespeed_log.$graphdir.$2.$3.duration $runtime `date +%s`" | nc graphite 2003
echo "sitespeed_log.$graphdir.$2.$3.images `du -s $(pwd)/portal/images/$2 | awk '{print $1}'` `date +%s`" | nc graphite 2003
ErrorCnt=$(grep ERROR ./logs/$1.$2.msg.log | wc -l)
echo "sitespeed_log.$graphdir.$2.$3.errors $ErrorCnt `date +%s`" | nc graphite 2003
echo "sitespeed_log.$graphdir.$2.$3.disk `ssh graphite du -s graphite-storage/whisper/sitespeed_io/$graphdir/$2/$3 | awk '{print $1}'` `date +%s`" | nc graphite 2003

# Executed only from US-East
if [ "$3" == "US-East" ]
  then
    # Log disk usage for all of Sitespeed_io
    echo "sitespeed_log.disk `ssh graphite du -s graphite-storage/whisper/sitespeed_io | awk '{print $1}'` `date +%s`" | nc graphite 2003

    # Log disk usage for test type
    echo "sitespeed_log.$graphdir.disk `ssh graphite du -s graphite-storage/whisper/sitespeed_io/$graphdir | awk '{print $1}'` `date +%s`" | nc graphite 2003

    # Log disk usage for test name
    echo "sitespeed_log.$graphdir.$2.disk `ssh graphite du -s graphite-storage/whisper/sitespeed_io/$graphdir/$2 | awk '{print $1}'` `date +%s`" | nc graphite 2003
fi

# Set the symlink for nginx root directive to point to the latest LAN index.html
ln -nsf $(find $(pwd)/$1/sitespeed-result/ -maxdepth 3 -name index.html | xargs ls -Art | tail -n 1 | xargs dirname) $(pwd)/portal/$weblan

# Set the symlink for nginx root directive to point to the latest Mobile index.html
ln -nsf $(find $(pwd)/$1/sitespeed-result/ -maxdepth 3 -name index.html | xargs ls -Art | tail -n 2 | xargs ls -At | tail -n 1 | xargs dirname) $(pwd)/portal/$webmobile

# Delete the older sitespeed-result runs
case $1 in
   tld ) find $(pwd)/$1/sitespeed-result/$3/ -mmin +120 | xargs rm -rf
         ;;

  comp ) find $(pwd)/$1/sitespeed-result/$3/ -mmin +120 | xargs rm -rf 
         ;;
esac
