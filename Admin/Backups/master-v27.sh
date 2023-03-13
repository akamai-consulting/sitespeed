#!/bin/bash

############################################
#                                          #
#                master.sh                 #
#                  v 27                    #
#                                          #
############################################

# Print help
if [[ "$1" == "--help" || "$1" == "-h" || "$1" == "/?" || $# -eq 0 ]]
    then
        echo -e "\n\tUsage: master.sh arg1 arg2 arg3 [arg4]"
        echo -e "\targ1: Test type"
        echo -e "\targ2: Test name"
        echo -e "\targ3: Test location"
        echo -e "\targ4: Optional URL to be tested"
        echo -e "\tIf arg4 is not passed testing is based on the URLs contained in arg2.txt\n"
        exit 0
fi

# Check for the correct number of arguments
if [[ $# -ne 3 && $# -ne 4 ]]
  then
    echo -e "\nmaster requires 3 or 4 arguments\n"
    exit 1
fi

# Check the correct test type ($1) has been entered
if [[ ! "$1" == "tld" && ! "$1" == "comp" ]]
    then 
        echo -e "\nTest type must be either tld or comp\n"
        exit 1
fi

# Check that config.json exists
if [ ! -f "$(pwd)/$1/config.json" ]
    then
        echo -e "\n$(pwd)/$1/config.json does not exist\n"
        exit 1
fi

# Check that URL seed file ($2) exists
if [ -f "$(pwd)/$1/$2.txt" ]
    then
        url=$2.txt
    else
        echo -e "\n$(pwd)/$1/$2.txt does not exist\n"
        exit 1
fi

# Check that the correct test location ($3) has been entered
regions="US-East US-Central US-West Toronto London Frankfurt Singapore Tokyo Mumbai Sydney"
echo $regions | tr ' ' '\n' | grep -F -x -q $3
if [ $? -eq 1 ]
   then
     echo -e "\nIncorrect region entered. Valid regions are:"
     echo -e "\n\tUS-East US-Central US-West Toronto London"
     echo -e "\tFrankfurt Singapore Tokyo Mumbai Sydney\n"
     exit 1
fi

# Check that the command line URL ($4) is valid
if [ $# -eq 4 ]
    then
        curl --head --silent $4 > /dev/null
        if [ $? -eq 0 ]
           then
             url=$4
           else
             echo -e "\nBad URL has been entered\n"
             exit 1
        fi
fi

# Docker commands
DockerLAN="--rm --name $2"
DockerMobile="--rm --name $2 --cap-add=NET_ADMIN"

# Sitespeed directives
ChromeLAN="--browsertime.connectivity.alias LAN"
ChromeLTE="-c custom --browsertime.connectivity.alias LTE --downstreamKbps 12000 --upstreamKbps 12000 --latency 35 --connectivity.engine throttle --chrome.CPUThrottlingRate 4 --mobile"

# Capture start of the entire run
start=`date +%s`

# Run Docker tests for both LAN and Mobile
for (( index=1; index < 3 ; index+=1 ))
  do
    case $index in
        1) TestType=LTE
           DockerCmds=$DockerMobile
           SitespeedDirs=$ChromeLTE
           sudo sysctl net.ipv4.ip_forward | grep 0 > /dev/null
           if [ $? -eq 0 ]
                then sudo sysctl net.ipv4.ip_forward=1
           fi
           sudo modprobe -c | grep ifb > /dev/null
           if [ $? -eq 1 ]
                then sudo modprobe ifb numifbs=1
           fi
           ;;

        2) TestType=LAN
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
        tld) docker run \
             $DockerCmds \
             -e TZ=America/New_York \
             -v $(pwd)/$1:/sitespeed.io \
             -v /etc/localtime:/etc/localtime:ro \
             sitespeedio/sitespeed.io:24.7.0 \
             --config config.json \
             $SitespeedDirs \
             --requestheader Pragma:akamai-x-cache-on,akamai-x-cache-remote-on,akamai-x-check-cacheable,akamai-x-feo-trace,akamai-x-get-cache-key,akamai-x-get-cache-tags,akamai-x-get-client-ip,akamai-x-get-extracted-values,akamai-x-get-request-id,akamai-x-get-ssl-client-session-id,akamai-x-get-true-cache-key,akamai-x-im-trace,akamai-x-rapid-debug,akamai-x-ro-trace,akamai-x-serial-no,akamai-x-tapioca-trace,akamai-x-write-v-log-line,edgegrid-fingerprints-on,edgegrid-trace-on,x-akamai-a2-trace \
             --name "$RptName" \
             --slug $3 \
             --graphite.namespace sitespeed_io.TLD.$2 \
             $url
             ;;

       comp) docker run \
             $DockerCmds \
             -e TZ=America/New_York \
             -v $(pwd)/$1:/sitespeed.io \
             -v /etc/localtime:/etc/localtime:ro \
             sitespeedio/sitespeed.io:24.7.0 \
             --config config.json \
             $SitespeedDirs \
             --name "$RptName" \
             --slug $3 \
             --graphite.namespace sitespeed_io.Competitors.$2 \
             $url
             ;;
    esac

    # Modify naming structure of sitespeed-result
    if [ ! -d $(pwd)/$1/sitespeed-result/$2 ]
      then
        mv -f $(pwd)/$1/sitespeed-result/$3 $(pwd)/$1/sitespeed-result/$2
      else
        mv -f $(pwd)/$1/sitespeed-result/$3/* $(pwd)/$1/sitespeed-result/$2/
        rm -Rf $(pwd)/$1/sitespeed-result/$3
    fi

    # Move the generated images to the correct location 
    if [ ! -f $(pwd)/portal/images/$2 ]
      then
        mkdir -p $(pwd)/portal/images/$2
        mv -f $(pwd)/$1/sitespeed-result/$2/*_* $(pwd)/portal/images/$2/
      else
        mv -f $(pwd)/$1/sitespeed-result/$2/*_* $(pwd)/portal/images/$2/
    fi

    end=`date +%s`
    runtime=$((end-teststart))
    hours=$((runtime / 3600))
    minutes=$(( (runtime % 3600) / 60 ))
    seconds=$(( (runtime % 3600) % 60 ))
    echo "$TestType End: $(TZ='America/New_York' date): $0 $@  Duration: $hours:$minutes:$seconds" >> $(pwd)/logs/$1.run.log
done

# Capture the end of the entire run, but do not log locally
end=`date +%s`
runtime=$((end-start))

# Set variables to point to correct directory
case $1 in
    tld) graphdir=TLD
         weblan=tldlan
         webmobile=tldmobile
         ;;
   comp) graphdir=Competitors
         weblan=complan
         webmobile=compmobile
         ;;
esac

test=$(echo $2 | tr '[:upper:]' '[:lower:]')
region=$(echo $3 | tr '[:upper:]' '[:lower:]')

# Log local run duration to Graphite
echo "sitespeed_usage.$1.$test.$region.duration $runtime `date +%s`" | nc graphite 2003

# Log disk usage for regional test to Graphite
echo "sitespeed_usage.$1.$test.$region.disk `ssh graphite du -s graphite-storage/whisper/sitespeed_io/$graphdir/$2/$3 | awk '{print $1}'` `date +%s`" | nc graphite 2003

# Log disk usage for entire test to Graphite
echo "sitespeed_usage.$1.$test.disk `ssh graphite du -s graphite-storage/whisper/sitespeed_io/$graphdir/$2 | awk '{print $1}'` `date +%s`" | nc graphite 2003

# Log local image usage to Graphite
echo "sitespeed_usage.$1.$test.$region.images `du -s $(pwd)/portal/images/$2 | awk '{print $1}'` `date +%s`" | nc graphite 2003

# Set the symlink for nginx root directive to point to the latest LAN index.html
ln -nsf $(find $(pwd)/$1/sitespeed-result/ -maxdepth 3 -name index.html | xargs ls -Art | tail -n 1 | xargs dirname) $(pwd)/portal/$weblan

# Set the symlink for nginx root directive to point to the latest Mobile index.html
ln -nsf $(find $(pwd)/$1/sitespeed-result/ -maxdepth 3 -name index.html | xargs ls -Art | tail -n 2 | xargs ls -At | tail -n 1 | xargs dirname) $(pwd)/portal/$webmobile

# Delete the older sitespeed-result runs
case $1 in
     tld ) find $(pwd)/$1/sitespeed-result/$2/ -mmin +180 | xargs rm -rf
           ;;
    comp ) find $(pwd)/$1/sitespeed-result/$2/ -mmin +180 | xargs rm -rf 
           ;;
esac
