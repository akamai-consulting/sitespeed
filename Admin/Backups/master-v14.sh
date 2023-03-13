#!/bin/bash

############################################
#                                          #
#                master.sh                 #
#                  v 14                    #
#                                          #
############################################

# The script must run with 2 - 3 arguments

# Argument 1 ($1) indicates the test type (tld or comp)
# Argument 2 ($2) is the --slug and --name
# Argument 3 ($3) is an optional URL to be tested
# If argument 3 is not provided the test will use $2.txt

# The HTML output of each run is stored in ~/$1/sitespeed-result/
# An updated symbolic link is set for the nginx webroot after each run
# The older HTML results are deleted after each run

# Print help and/or check for correct number of arguments
if [[ "$1" == "--help" || ( $# -ne 2 && $# -ne 3 ) ]] 
    then
        echo -e "\n\tUsage: master.sh arg1 arg2 [arg3]"
        echo -e "\targ1: Test type (tld or comp)"
        echo -e "\targ2: Test name"
        echo -e "\targ3: Optional URL to be tested"
        echo -e "\tIf arg3 is not passed testing is based on the URLs contained in arg2.txt\n"
        exit 0
fi

# Check the correct test type has been entered
if [[ ! "$1" == "tld" && ! "$1" == "comp" ]]
    then 
        echo -e "\nTest type must be either tld or comp\n"
        exit 1
fi

# Check that $2 or $3 are valid
case $# in
    2) if [ -f "$(pwd)/$1/$2.txt" ]
        then
            url=$2.txt
        else
            echo -e "\n$(pwd)/$1/$2.txt does not exist\n"
            exit 1
       fi
       ;;

    3) curl --head --silent $3 > /dev/null
       if [ $? -eq 0 ]
         then
            url=$3
         else
            echo -e "\nBad URL has been entered\n"
            exit 1
       fi
       ;;
esac

# Contruct FirstParty depending on $2 and $3
case $# in
    2) IFS=$'\n' read -d '' -r -a data < "$(pwd)/$1/$2.txt"
       hosttmp=()
       tldtmp=()
       for (( index=0; index < ${#data[*]} ; index+=1 ))
          do
            hosttmp[index]="$(echo ${data[index]} | cut -d '.' -f2)"
            tldtmp[index]="$(echo ${data[index]} | cut -d '.' -f3 | cut -d '/' -f1)"
        done
        host=($(echo -e "${hosttmp[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
        tld=($(echo -e "${tldtmp[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
        case ${#host[*]} in
            1) hosts=${host[0]}
               ;;
            *) hosts=${host[0]}
               for (( index = 1; index < ${#host[*]}; index += 1 ))
                 do
                   hosts="$hosts|${host[index]}"
               done
               ;;
        esac
        case ${#tld[*]} in
            1) tlds=${tld[0]}
               ;;
            *) tlds=${tld[0]}
               for (( index = 1; index < ${#tld[*]}; index += 1 ))
                 do
                 tlds="$tlds|${tld[index]}"
               done
               ;;
        esac
        FirstParty="\"\\.($hosts)\\.($tlds)\""
        ;;

    3)  host="$(echo $3 | cut -d '.' -f2)"
        tld="$(echo $3 | cut -d '.' -f 3| cut -d '/' -f 1)"
        FirstParty="\"\\.($host)\\.($tld)\""
        ;;
esac

echo -e "\n|========================================================================="
echo "| Start: $(TZ='America/New_York' date): $0 $@"
echo "|========================================================================="

# Capture start of run
start=`date +%s`

# Spin up correct container based on $1 = tld or comp

case $1 in
    tld) docker run \
         --rm \
         --cap-add=NET_ADMIN \
         --name $1 \
         -e TZ=America/New_York \
         -v $(pwd)/$1:/sitespeed.io \
         -v /etc/localtime:/etc/localtime:ro \
         sitespeedio/sitespeed.io:21.4.0 \
         -n 1 \
         --browser chrome \
         --connectivity.profile custom \
         --viewPort "375x812" \
         --browsertime.connectivity.alias 4G \
         --mobile \
         --connectivity.downstreamKbps 9000 \
         --connectivity.upstreamKbps 9000 \
         --connectivity.rtt 85 \
         --userAgent "Mozilla/5.0 (iPhone; CPU iPhone OS 15_1_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.1 Mobile/15E148 Safari/604.1" \
         --browsertime.connectivity.engine=throttle \
         --visualMetrics true \
         --speedIndex true \
         --visualElements true \
         --visualMetricsPerceptual true \
         --visualMetricsContentful true \
         --video true \
         --filmstrip.showAll true \
         --screenshotLCP true \
         --screenshotLS true \
         --browsertime.screenshotLCPColor red \
         --browsertime.screenshotLSColor green \
         --cpu \
         --resultBaseURL https://www.hilltoptech.net/images \
         --copyLatestFilesToBase true \
         --screenshot.type png \
         --requestheader X-IM-Debug:showvars \
         --requestheader x-im-piez:on \
         --requestheader Pragma:akamai-x-cache-on,akamai-x-cache-remote-on,akamai-x-check-cacheable,akamai-x-feo-trace,akamai-x-get-cache-key,akamai-x-get-cache-tags,akamai-x-get-client-ip,akamai-x-get-extracted-values,akamai-x-get-request-id,akamai-x-get-ssl-client-session-id,akamai-x-get-true-cache-key,akamai-x-im-trace,akamai-x-rapid-debug,akamai-x-ro-trace,akamai-x-serial-no,akamai-x-tapioca-trace,akamai-x-write-v-log-line,edgegrid-fingerprints-on,edgegrid-trace-on,x-akamai-a2-trace \
         --thirdParty.cpu \
         --chrome.collectLongTasks \
         --firstParty $FirstParty \
         --name $2 \
         --slug $2 \
         --graphite.host 10.128.0.11 \
         --graphite.httpPort 8888 \
         --graphite.namespace sitespeed_io.TLD \
         $url
         
         sleep 3
         
         # Move the latest png and mp4 files so they can be accessed within Grafana
         if [ ! -f $(pwd)/portal/images/$2 ]
            then
                mkdir -p $(pwd)/portal/images/$2
                mv -f $(pwd)/$1/sitespeed-result/$2/www_* $(pwd)/portal/images/$2/
            else
                mv -f $(pwd)/$1/sitespeed-result/$2/www_* $(pwd)/portal/images/$2/
         fi

         end=`date +%s`
         runtime=$((end-start))
         hours=$((runtime / 3600))
         minutes=$(( (runtime % 3600) / 60 ))
         seconds=$(( (runtime % 3600) % 60 ))
         echo "End: $(TZ='America/New_York' date): $0 $@  Duration: $hours:$minutes:$seconds" >> $(pwd)/logs/$1.run.log
         ;;

  comp)  docker run \
         --rm \
         --name $1 \
         -e TZ=America/New_York \
         -v $(pwd)/$1:/sitespeed.io \
         -v /etc/localtime:/etc/localtime:ro \
         sitespeedio/sitespeed.io:21.4.0 \
         -b chrome \
         -n 1 \
         --viewPort "maximize" \
         --visualMetrics true \
         --speedIndex true \
         --visualElements true \
         --visualMetricsPerceptual true \
         --visualMetricsContentful true \
         --video true \
         --filmstrip.showAll true \
         --screenshotLCP true \
         --screenshotLS true \
         --browsertime.screenshotLCPColor red \
         --browsertime.screenshotLSColor green \
         --percentiles [0,10,50,75,85,90,95,100] \
         --cpu \
         --resultBaseURL https://www.hilltoptech.net/images \
         --copyLatestFilesToBase true \
         --screenshot.type png \
         --thirdParty.cpu \
         --chrome.collectLongTasks \
         --firstParty $FirstParty \
         --name $2 \
         --slug $2 \
         --graphite.host 10.128.0.11 \
         --graphite.httpPort 8888 \
         --graphite.namespace sitespeed_io.Competitors \
         $url
         sleep 3
         
         # Move the latest png and mp4 files so they can be accessed within Grafana
         if [ ! -f $(pwd)/portal/images/$2 ]
            then
                mkdir -p $(pwd)/portal/images/$2
                mv -f $(pwd)/$1/sitespeed-result/$2/www_* $(pwd)/portal/images/$2/
            else
                mv -f $(pwd)/$1/sitespeed-result/$2/www_* $(pwd)/portal/images/$2/
         fi

         end=`date +%s`
         runtime=$((end-start))
         hours=$((runtime / 3600))
         minutes=$(( (runtime % 3600) / 60 ))
         seconds=$(( (runtime % 3600) % 60 ))
         echo "End: $(TZ='America/New_York' date): $0 $@  Duration: $hours:$minutes:$seconds" >> $(pwd)/logs/$1.run.log
         ;;
esac

# Set variables to point to correct directory
case $1 in
    tld) graphdir=TLD
         webroot=tldroot
         ;;
   comp) graphdir=Competitors
         webroot=comproot
         ;;
esac
logname=$(echo $2 | tr '[:upper:]' '[:lower:]')

# Send run duration and disk usage to Graphite
echo "sitespeed_usage.$1.$logname.duration $runtime `date +%s`" | nc -N 10.128.0.11 2003
echo "sitespeed_usage.$1.$logname.disk `ssh 10.128.0.11 du -s graphite-storage/whisper/sitespeed_io/$graphdir/$2 | awk '{print $1}'` `date +%s`" | nc -N 10.128.0.11 2003

# Set the symlink for nginx root directive to point to the latest index.html
ln -nsf $(find $(pwd)/$1/sitespeed-result/ -maxdepth 3 -name index.html | xargs ls -Art | tail -n 1 | xargs dirname) $(pwd)/portal/$webroot

# Delete the older sitespeed-result runs
case $1 in
     tld ) find $(pwd)/$1/sitespeed-result/$2/ -mmin +240 | xargs rm -rf
           ;;
    comp ) find $(pwd)/$1/sitespeed-result/$2/ -mmin +300 | xargs rm -rf 
           ;;
esac
