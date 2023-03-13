#!/bin/bash

############################################
#                                          #
#             master-msn.sh                #
#                 v 21                     #
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

# Check that URL seed file ($2) exists and URL ($3) is valid
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

# Contruct FirstParty depending on the command line arguments
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

# Docker commands
DockerLAN="--rm --name $2"
DockerMobile="--rm --name $2 --cap-add=NET_ADMIN"

# Sitespeed directives
ChromeLAN="--browsertime.connectivity.alias LAN"

FirefoxLAN="-b firefox --browsertime.connectivity.alias LAN"

ChromeLTE="-c custom --browsertime.connectivity.alias LTE --downstreamKbps 12000 --upstreamKbps 12000 --latency 35 --connectivity.engine throttle --chrome.CPUThrottlingRate 4 --mobile"

Chrome3G="-c custom --browsertime.connectivity.alias 3G --downstreamKbps 1600 --upstreamKbps 768 --latency 150 --connectivity.engine throttle --chrome.CPUThrottlingRate 4 --mobile"

# Capture start of entire run
start=`date +%s`

# Run Docker tests for both desktop and mobile

for (( index=3; index < 5 ; index+=1 ))
  do
    case $index in
        1) TestType=3G
           DockerCmds=$DockerMobile
           SitespeedDirs=$Chrome3G
           RptName="$2 (Chrome $TestType)"
           sudo sysctl net.ipv4.ip_forward | grep 0 > /dev/null
           if [ $? -eq 0 ]
                then sudo sysctl net.ipv4.ip_forward=1
           fi
           sudo modprobe -c | grep ifb > /dev/null
           if [ $? -eq 1 ]
                then sudo modprobe ifb numifbs=1
           fi
           ;;

        2) TestType=Firefox
           DockerCmds=$DockerLAN
           SitespeedDirs=$FirefoxLAN
           RptName="$2 ($TestType LAN)"
           ;;

        3) TestType=LTE
           DockerCmds=$DockerMobile
           SitespeedDirs=$ChromeLTE
           RptName="$2 (Chrome $TestType)"
           sudo sysctl net.ipv4.ip_forward | grep 0 > /dev/null
           if [ $? -eq 0 ]
                then sudo sysctl net.ipv4.ip_forward=1
           fi
           sudo modprobe -c | grep ifb > /dev/null
           if [ $? -eq 1 ]
                then sudo modprobe ifb numifbs=1
           fi
           ;;

        4) TestType=LAN
           DockerCmds=$DockerLAN
           SitespeedDirs=$ChromeLAN
           RptName="$2 (Chrome $TestType)"
           ;;
    esac

    # Capture start of each test
    teststart=`date +%s`

    echo "|=============================================================================="
    echo "| $TestType start: $(TZ='America/New_York' date): $0 $@"
    echo "|=============================================================================="

    case $2 in
        MSNAKA) docker run \
                $DockerCmds \
                -e TZ=America/New_York \
                -v $(pwd)/$1:/sitespeed.io \
                -v /etc/localtime:/etc/localtime:ro \
                sitespeedio/sitespeed.io:22.1.0 \
                --config config.json \
                $SitespeedDirs \
                --preURL "https://www-msn-com.test.edgekey.net/bundles/v1/hybrid/latest/startup/vendor.07dd3255e0aa77d7d05b.js" \
                --preURL "https://www-msn-com.test.edgekey.net/bundles/v1/hub/latest/2.5c2ed4a0c8f9f40ac446.js" \
                --preURL "https://www-msn-com.test.edgekey.net/bundles/v1/views/latest/desktop-feed-views~related-article-block.93e06fe88591c428eb76.js" \
                --preURL "https://www-msn-com.test.edgekey.net/bundles/v1/hybrid/latest/social/social.f5f90ad6aaf8493453a6.js" \
                --preURL "https://www-msn-com.test.edgekey.net/bundles/v1/views/latest/common.e64567c21a5724520779.js" \
                --preURL "https://www-msn-com.test.edgekey.net/bundles/v1/views/latest/desktop-feed-views.f31c573a027c702a503b.js" \
                --preURL "https://static-global-s-msn-com.test.edgekey.net/hp-eus/en-us/homepage/_sc/css/d7cb56b9-6a80b877/direction=ltr.locales=en-us.themes=start.dpi=resolution1x/b0-c94bf6-9065abb3/77-911be0-ca35de2/7f-145015-491caa4c/7d-3d0302-6afa84ff/6e-199b4b-2e6e502e/69-158bff-ec559c31/51-e120b3-267d49e0/7a-e2312d-feaf21fa/ed-6bbb92-9371f7c7/5e-713ade-ecdc80c3/46-bedf20-ce21f2e8/15-68b83d-e8e1efc6/7a-47adc9-4e5cd0ee/b7-e7d713-eb5d7a7/ed-955bb7-6397bdd4/47-208f84-846eb25/ec-8eee22-6019ddb8/4e-3122af-e01d984a/41-2137b9-1ff68540/ab-5da68b-4f2c15df/14-e25352-1c2507c7/8f-4d6463-72d94145/35-f1f99f-358c786e/53-ac802a-e0a4caac/6f-b7ee08-bb3f087/9c-87e645-a3c980c5/ff-f11f02-c1fa9d4e/ba-cdcc9e-a1a2fb72/58-acd805-185735b/72-67ce39-89307260?ver=20220206_26930321&fdhead=msnallexpusers,muidflt11cf,muidflt15cf,muidflt48cf,muidflt260cf,mmxandroid1cf,moneyedge2cf,bingcollabedge3cf,audexhp2cf,criteo325,bingcollabhp2cf,platagyhz3cf,artgly1cf,article1cf,msnapp2cf,1s-bing-news,vebudumu04302020,weather3cf,1s-jwtuserauth,pre1s-brsagemkpr,traffic-areacamera,csmoney4cf,btrecenus,iframeflex,1s-br30min,1s-winauthservice,1s-winsegservice,wf-sunny-first,btie-aiuxasset,1s-maps-latlongkeyc,1s-pagesegservice&csopd=20210722164117&csopdb=20220120005548" \
                --preURL "https://static-global-s-msn-com.test.edgekey.net/hp-eus/en-us/homepage/_sc/css/d7cb56b9-6a80b877/direction=ltr.locales=en-us.themes=start.dpi=resolution1x/b0-c94bf6-9065abb3/77-911be0-ca35de2/7f-145015-491caa4c/7d-3d0302-6afa84ff/6e-199b4b-2e6e502e/69-158bff-ec559c31/51-e120b3-267d49e0/7a-e2312d-feaf21fa/ed-6bbb92-9371f7c7/5e-713ade-ecdc80c3/46-bedf20-ce21f2e8/15-68b83d-e8e1efc6/7a-47adc9-4e5cd0ee/b7-e7d713-eb5d7a7/ed-955bb7-6397bdd4/47-208f84-846eb25/ec-8eee22-6019ddb8/4e-3122af-e01d984a/41-2137b9-1ff68540/ab-5da68b-4f2c15df/14-e25352-1c2507c7/8f-4d6463-72d94145/35-f1f99f-358c786e/53-ac802a-e0a4caac/6f-b7ee08-bb3f087/9c-87e645-a3c980c5/ff-f11f02-c1fa9d4e/ba-cdcc9e-a1a2fb72/58-acd805-185735b/72-67ce39-89307260?ver=20220206_26930321&fdhead=msnallexpusers,muidflt13cf,muidflt19cf,muidflt298cf,audexedge3cf,starthp3cf,audexhp1cf,moneyhp1cf,moneyhp2cf,moneyhp3cf,audexhz3cf,bingcollabhz1cf,1s-brsageccitan4,1s-bing-news,vebudumu04302020,shophp1cf,shophp2cf,msnsports4cf,weather4cf,weather5cf,1s-brsagel0tpr2cc,1s-brsagetsev3,traffic-camddv2,btrecenus,iframeflex,1s-br30min,1s-winauthservice,1s-winsegservice,msnapp8cf,btie-aiux,1s-pagesegservice&csopd=20210722164117&csopdb=20220120005548" \
                --preURL "https://static-global-s-msn-com.test.edgekey.net/hp-eus/en-us/homepage/_sc/css/d7cb56b9-6a80b877/direction=ltr.locales=en-us.themes=start.dpi=resolution1x/b0-c94bf6-9065abb3/77-911be0-ca35de2/7f-145015-491caa4c/7d-3d0302-6afa84ff/6e-199b4b-2e6e502e/69-158bff-ec559c31/51-e120b3-267d49e0/7a-e2312d-feaf21fa/ed-6bbb92-9371f7c7/5e-713ade-ecdc80c3/46-bedf20-ce21f2e8/15-68b83d-e8e1efc6/7a-47adc9-4e5cd0ee/b7-e7d713-eb5d7a7/ed-955bb7-6397bdd4/47-208f84-846eb25/ec-8eee22-6019ddb8/4e-3122af-e01d984a/41-2137b9-1ff68540/ab-5da68b-4f2c15df/14-e25352-1c2507c7/8f-4d6463-72d94145/35-f1f99f-358c786e/53-ac802a-e0a4caac/6f-b7ee08-bb3f087/9c-87e645-a3c980c5/ff-f11f02-c1fa9d4e/ba-cdcc9e-a1a2fb72/58-acd805-185735b/72-67ce39-89307260?ver=20220206_26930321&fdhead=msnallexpusers,muidflt9cf,muidflt10cf,muidflt28cf,muidflt48cf,muidflt51cf,muidflt312cf,oneboxdhpcf,moneyedge1cf,starthp2cf,platagyhp1cf,moneyhp3cf,pnehz3cf,article4cf,anaheim1cf,msnapp3cf,1s-bing-news,vebudumu04302020,shophp2cf,msnsports4cf,1s-jwtuserauth,pre1s-brsagetcf6c,btrecenus,msnsapphire2cf,iframeflex,csmoney6cf,csmoney7cf,1s-br30min,1s-winauthservice,1s-winsegservice,1s-pagesegservice,routentpring2c,17hb1851&csopd=20210722164117&csopdb=20220120005548" \
                --preURL "https://static-entertainment-eus-s-msn-com.test.edgekey.net/en-us/video/_sc/css/d7cb56b9-b33277e2/direction=ltr.locales=en-us.themes=gray2.dpi=resolution1x/b0-c94bf6-e7ae6c29/ae-63f93e-c02947bd/4d-1bf494-b301d117/7a-e2312d-feaf21fa/ed-6bbb92-e9d8023a/7f-145015-491caa4c/7d-3d0302-6afa84ff/6e-199b4b-5f5ea9/24-ca6c94-55c4db71/69-158bff-a7bdf54a/51-e120b3-267d49e0/c4-e9c07b-5e873583/67-7d5e3c-d6bd9621/c1-bc5122-491caa4c/5e-713ade-28d3313e/4f-96c050-3c76dc2c/85-0332e1-ae459cf8/47-c36938-2442fa26/22-8c1ef3-b5df1c25/14-f69d09-78c03598/c2-b8eb91-68ddb2ab/b0-eba324-aeb73281?ver=20220204_26908235&fdhead=msnallexpusers,muidflt11cf,muidflt15cf,muidflt21cf,muidflt50cf,muidflt58cf,muidflt300cf,muidflt301cf,muidflt312cf,startedge3cf,complianceedge1cf,bingcollabhp1cf,starthz1cf,platagyhz2cf,audexhz3cf,moneyhz3cf,gallery3cf,gallery5cf,msnapp1cf,1s-bing-news,vebudumu04302020,1s-jwtuserauth,csmoney2cf,btrecenus,iframeflex,pro-wpo-olyprod6,1s-br30min,1s-winauthservice,1s-winsegservice,msnapp10cf,1s-pagesegservice,routentpring2c&ocid=StripeOCID&csopd=20201002173642&csopdb=20220120005548" \
                --preURL "https://static-entertainment-eus-s-msn-com.test.edgekey.net/en-us/video/_sc/css/d7cb56b9-b33277e2/direction=ltr.locales=en-us.themes=gray2.dpi=resolution1x/b0-c94bf6-ce6760c3/ae-63f93e-918f9d57/4d-1bf494-2a5ce979/7a-e2312d-feaf21fa/ed-6bbb92-2522c697/7f-145015-491caa4c/7d-3d0302-273ab94b/6e-199b4b-2be24515/24-ca6c94-c04c1473/69-158bff-5f806f97/51-e120b3-ac5c2fc8/c4-e9c07b-cb0ffa81/67-7d5e3c-d6bd9621/c1-bc5122-491caa4c/5e-713ade-28d3313e/4f-96c050-3c76dc2c/85-0332e1-3bcd53fa/47-c36938-2442fa26/22-8c1ef3-2057d327/14-f69d09-21b59ae/c2-b8eb91-68ddb2ab/b0-eba324-64df159c?ver=20220204_26908235&fdhead=msnallexpusers,muidflt12cf,muidflt19cf,muidflt21cf,muidflt49cf,muidflt118cf,oneboxdhpcf,pnehp2cf,platagyhp1cf,audexhp3cf,pnehz1cf,starthz3cf,1s-bing-news,vebudumu04302020,1s-brsagelt4,csmoney2cf,btrecenus,iframeflex,1s-br30min,1s-winauthservice,1s-winsegservice,weather10cf,msnapp6cf,btie-aiux-c,1s-maps-latlongkeyc,1s-pagesegservice,routentpring2c&ocid=StripeOCID&csopd=20201002173642&csopdb=20220120005548" \
                --preURL "https://static-entertainment-eus-s-msn-com.test.edgekey.net/en-us/video/_sc/css/d7cb56b9-b33277e2/direction=ltr.locales=en-us.themes=gray2.dpi=resolution1x/b0-c94bf6-ce6760c3/ae-63f93e-918f9d57/4d-1bf494-2a5ce979/7a-e2312d-feaf21fa/ed-6bbb92-2522c697/7f-145015-491caa4c/7d-3d0302-273ab94b/6e-199b4b-2be24515/24-ca6c94-c04c1473/69-158bff-5f806f97/51-e120b3-ac5c2fc8/c4-e9c07b-cb0ffa81/67-7d5e3c-d6bd9621/c1-bc5122-491caa4c/5e-713ade-28d3313e/4f-96c050-3c76dc2c/85-0332e1-3bcd53fa/47-c36938-2442fa26/22-8c1ef3-2057d327/14-f69d09-21b59ae/c2-b8eb91-68ddb2ab/b0-eba324-64df159c?ver=20220204_26908235&fdhead=msnallexpusers,muidflt49cf,muidflt52cf,muidflt260cf,muidflt315cf,pnehp1cf,bingcollabhp1cf,bingcollabhp3cf,compliancehz1cf,article3cf,1s-bing-news,vebudumu04302020,1s-jwtuserauth,1s-brsageldulc,1s-brsagedppz,csmoney2cf,btrecenus,iframeflex,pro-wpo-olyprod6,1s-br30min,1s-winauthservice,1s-winsegservice,wf-sunny-first,weather9cf,weather10cf,msnapp7cf,msnapp9cf,btie-aiuxasset,1s-maps-latlongkey,1s-pagesegservice,routentpring2c,1s-ceadaipalt&ocid=StripeOCID&csopd=20201002173642&csopdb=20220120005548" \
                --preURL "https://static-entertainment-eus-s-msn-com.test.edgekey.net/en-us/sports/_sc/css/d7cb56b9-efdb9e04/direction=ltr.locales=en-us.themes=darkpurple.dpi=resolution1x/b0-c94bf6-10c5b1a0/1f-206e17-d58c576a/60-2a0d9d-30acfdeb/7f-145015-491caa4c/7d-3d0302-273ab94b/6e-199b4b-a100e011/24-ca6c94-2fd1ee8b/69-158bff-792ad0b8/51-e120b3-ac5c2fc8/c4-e9c07b-cb0ffa81/67-7d5e3c-d6bd9621/7a-e2312d-feaf21fa/ed-6bbb92-2522c697/5e-713ade-83c84c02/8a-2242c8-b313acf6/64-a74063-8e853862/d3-f374f0-24287e8c/8b-617964-6d991c7e/78-d69512-f0fffa3f/cb-222073-b7b347f2/85-d603e5-491caa4c/ee-76af25-d6b6a63f/15-d14992-7127cc97/d7-b9fc60-ae503b62/d1-5000b0-175289e5?ver=20220204_26908235&fdhead=msnallexpusers,muidflt11cf,muidflt20cf,muidflt46cf,muidflt58cf,muidflt118cf,muidflt300cf,mmxios1cf,platagyedge1cf,bingcollabedge2cf,starthp2cf,audexhp3cf,criteo325,moneyhp3cf,starthz3cf,artgly3cf,gallery5cf,1s-bing-news,vebudumu04302020,1s-brsagel0tpr2cc,traffic-cameracf,btrecenus,iframeflex,1s-br30min,1s-winauthservice,1s-winsegservice,1s-maps-latlongkeyc,1s-pagesegservice,routentpring2t,0e6ia729&ocid=StripeOCID&csopd=20210720141208&csopdb=20220120005548" \
                --preURL "https://static-entertainment-eus-s-msn-com.test.edgekey.net/en-us/sports/_sc/css/d7cb56b9-efdb9e04/direction=ltr.locales=en-us.themes=darkpurple.dpi=resolution1x/b0-c94bf6-10c5b1a0/1f-206e17-40049868/60-2a0d9d-a52432e9/7f-145015-491caa4c/7d-3d0302-273ab94b/6e-199b4b-a100e011/24-ca6c94-2fd1ee8b/69-158bff-792ad0b8/51-e120b3-ac5c2fc8/c4-e9c07b-cb0ffa81/67-7d5e3c-d6bd9621/7a-e2312d-feaf21fa/ed-6bbb92-2522c697/5e-713ade-83c84c02/8a-2242c8-b313acf6/64-a74063-ad822ee/d3-f374f0-24287e8c/8b-617964-aca89e14/78-d69512-f0fffa3f/cb-222073-b7b347f2/85-d603e5-491caa4c/ee-76af25-d6b6a63f/15-d14992-7127cc97/d7-b9fc60-ae503b62/d1-5000b0-175289e5?ver=20220204_26908235&fdhead=msnallexpusers,muidflt59cf,audexedge1cf,criteo325,bingcollabhp2cf,pnehz2cf,artgly4cf,1s-bing-news,vebudumu04302020,1s-jwtuserauth,1s-brsageunifcc,1s-brsagedppb,btrecenus,iframeflex,1s-br30min,1s-winauthservice,1s-winsegservice,wf-sunny-first,weather10cf,1s-pagesegservice,routentpring2c&ocid=StripeOCID&csopd=20210720141208&csopdb=20220120005548" \
                --preURL "https://static-entertainment-eus-s-msn-com.test.edgekey.net/en-us/sports/_sc/css/d7cb56b9-efdb9e04/direction=ltr.locales=en-us.themes=darkpurple.dpi=resolution1x/b0-c94bf6-d652ef2f/1f-206e17-d58c576a/60-2a0d9d-30acfdeb/7f-145015-491caa4c/7d-3d0302-6afa84ff/6e-199b4b-8abdfbad/24-ca6c94-ba592189/69-158bff-81174a65/51-e120b3-267d49e0/c4-e9c07b-5e873583/67-7d5e3c-d6bd9621/7a-e2312d-feaf21fa/ed-6bbb92-e9d8023a/5e-713ade-83c84c02/8a-2242c8-b313acf6/64-a74063-8e853862/d3-f374f0-24287e8c/8b-617964-6d991c7e/78-d69512-f0fffa3f/cb-222073-b7b347f2/85-d603e5-491caa4c/ee-76af25-d6b6a63f/15-d14992-7127cc97/d7-b9fc60-ae503b62/d1-5000b0-175289e5?ver=20220204_26908235&fdhead=msnallexpusers,muidflt27cf,muidflt50cf,muidflt51cf,muidflt52cf,platagyhp3cf,audexhp2cf,criteo325,bingcollabhp2cf,platagyhz3cf,artgly3cf,msnapp2cf,1s-bing-news,vebudumu04302020,shophp1cf,msnsports5cf,weather2cf,1s-jwtuserauth,pre1s-brsagetcf6b,1s-brsagetsev3c2,csmoney2cf,btrecenus,iframeflex,a70j9715,620f3380,pro-wpo-olyprod6,1s-br30min,1s-winauthservice,1s-winsegservice,msnapp6cf,cstestisolationgroupcf,f-rel-all,1s-pagesegservice,routentpring2t&ocid=StripeOCID&csopd=20210720141208&csopdb=20220120005548" \
                --preURL "https://static-global-s-msn-com.test.edgekey.net/hp-eus/en-us/homepage/_sc/css/d7cb56b9-6a80b877/direction=ltr.locales=en-us.themes=start.dpi=resolution1x/b0-c94bf6-9065abb3/77-911be0-ca35de2/7f-145015-491caa4c/7d-3d0302-6afa84ff/6e-199b4b-2e6e502e/69-158bff-ec559c31/51-e120b3-267d49e0/7a-e2312d-feaf21fa/ed-6bbb92-9371f7c7/5e-713ade-ecdc80c3/46-bedf20-ce21f2e8/15-68b83d-e8e1efc6/7a-47adc9-4e5cd0ee/b7-e7d713-eb5d7a7/ed-955bb7-6397bdd4/47-208f84-846eb25/ec-8eee22-6019ddb8/4e-3122af-e01d984a/41-2137b9-1ff68540/ab-5da68b-4f2c15df/14-e25352-1c2507c7/8f-4d6463-72d94145/35-f1f99f-358c786e/53-ac802a-e0a4caac/6f-b7ee08-bb3f087/9c-87e645-a3c980c5/ff-f11f02-c1fa9d4e/ba-cdcc9e-a1a2fb72/58-acd805-185735b/72-67ce39-89307260?ver=20220206_26930321&fdhead=msnallexpusers,muidflt11cf,muidflt15cf,muidflt48cf,muidflt260cf,mmxandroid1cf,moneyedge2cf,bingcollabedge3cf,audexhp2cf,criteo325,bingcollabhp2cf,platagyhz3cf,artgly1cf,article1cf,msnapp2cf,1s-bing-news,vebudumu04302020,weather3cf,1s-jwtuserauth,pre1s-brsagemkpr,traffic-areacamera,csmoney4cf,btrecenus,iframeflex,1s-br30min,1s-winauthservice,1s-winsegservice,wf-sunny-first,btie-aiuxasset,1s-maps-latlongkeyc,1s-pagesegservice&csopd=20210722164117&csopdb=20220120005548" \
                --preURL "https://static-global-s-msn-com.test.edgekey.net/hp-eus/sc/f8/f77b07.woff2" \
                --preURL "https://static-global-s-msn-com.test.edgekey.net/hp-eus/en-us/homepage/_sc/js/d7cb56b9-d80ecde9/direction=ltr.locales=en-us.themes=start.dpi=resolution1x/97-9a8c47-68ddb2ab/1b-2f9654-265c7792/42-6ebd79-57056260/e4-0588d3-68ddb2ab/64-4c5ce6-5599dabd/9e-a7a255-68ddb2ab/a9-ac9b58-68ddb2ab/f1-d0c6aa-cae48929/c7-47822a-f41d9e92/7e-ffa9bd-f9c98504/b4-50277a-19c4a06f/a2-a23427-68ddb2ab/d2-05c949-243aa040/5e-c51c87-53568de/10-abab23-c57e93ae/4c-3cf76c-f9c98504/96-ca33d0-a7d95428/9e-639daf-68ddb2ab/dd-a09dd5-86e27032/85-0f8009-68ddb2ab?ver=20220206_26930321&fdhead=msnallexpusers,muidflt11cf,muidflt15cf,muidflt48cf,muidflt260cf,mmxandroid1cf,moneyedge2cf,bingcollabedge3cf,audexhp2cf,criteo325,bingcollabhp2cf,platagyhz3cf,artgly1cf,article1cf,msnapp2cf,1s-bing-news,vebudumu04302020,weather3cf,1s-jwtuserauth,pre1s-brsagemkpr,traffic-areacamera,csmoney4cf,btrecenus,iframeflex,1s-br30min,1s-winauthservice,1s-winsegservice,wf-sunny-first,btie-aiuxasset,1s-maps-latlongkeyc,1s-pagesegservice&csopd=20210722164117&csopdb=20220120005548" \
                --preURL "https://static-global-s-msn-com.test.edgekey.net/img-resizer/tenant/amp/entityid/BB1aj5PI.img?h=27&w=27&m=6&q=60&u=t&o=t&l=f&f=png" \
                --preURL "https://static-global-s-msn-com.test.edgekey.net/img-resizer/tenant/amp/entityid/AANw7hC.img?h=27&w=27&m=6&q=60&u=t&o=t&l=f&f=png" \
                --preURL "https://static-global-s-msn-com.test.edgekey.net/img-resizer/tenant/amp/entityid/BB14D0jG.img?h=27&w=27&m=6&q=60&u=t&o=t&l=f&f=png" \
                --preURL "https://static-global-s-msn-com.test.edgekey.net/img-resizer/tenant/amp/entityid/AAR0pJm.img?h=27&w=27&m=6&q=60&u=t&o=t&l=f&f=png" \
                --preURL "https://static-global-s-msn-com.test.edgekey.net/img-resizer/tenant/amp/entityid/BB15wfq2.img?h=27&w=27&m=6&q=60&u=t&o=t&l=f&f=png" \
                --preURL "https://static-global-s-msn-com.test.edgekey.net/hp-eus/_h/975a7d20/webcore/externalscripts/jquery/jquery-2.1.1.min.js" \
                --requestheader Pragma:akamai-x-cache-on,akamai-x-cache-remote-on,akamai-x-check-cacheable,akamai-x-feo-trace,akamai-x-get-cache-key,akamai-x-get-cache-tags,akamai-x-get-client-ip,akamai-x-get-extracted-values,akamai-x-get-request-id,akamai-x-get-ssl-client-session-id,akamai-x-get-true-cache-key,akamai-x-im-trace,akamai-x-rapid-debug,akamai-x-ro-trace,akamai-x-serial-no,akamai-x-tapioca-trace,akamai-x-write-v-log-line,edgegrid-fingerprints-on,edgegrid-trace-on,x-akamai-a2-trace \
                --firstParty $FirstParty \
                --name "$RptName" \
                --slug $2 \
                --graphite.namespace sitespeed_io.TLD \
                $url
                ;;

           MSN) docker run \
                $DockerCmds \
                -e TZ=America/New_York \
                -v $(pwd)/$1:/sitespeed.io \
                -v /etc/localtime:/etc/localtime:ro \
                sitespeedio/sitespeed.io:22.1.0 \
                --config config.json \
                $SitespeedDirs \
                --firstParty $FirstParty \
                --name "$RptName" \
                --slug $2 \
                --graphite.namespace sitespeed_io.TLD \
                $url
                ;;
    esac

    sleep 3

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
         webroot=tldroot
         webrootmobile=tldmobile
         ;;
   comp) graphdir=Competitors
         webroot=comproot
         webrootmobile=compmobile
         ;;
esac
logname=$(echo $2 | tr '[:upper:]' '[:lower:]')

# Send run duration, disk usage, and image usage to Graphite
echo "sitespeed_usage.$1.$logname.duration $runtime `date +%s`" | nc 10.128.0.11 2003
echo "sitespeed_usage.$1.$logname.disk `ssh 10.128.0.11 du -s graphite-storage/whisper/sitespeed_io/$graphdir/$2 | awk '{print $1}'` `date +%s`" | nc 10.128.0.11 2003
echo "sitespeed_usage.$1.$logname.images `du -s $(pwd)/portal/images/$2 | awk '{print $1}'` `date +%s`" | nc 10.128.0.11 2003

# Set the symlink for nginx root directive to point to the latest LAN index.html
ln -nsf $(find $(pwd)/$1/sitespeed-result/ -maxdepth 3 -name index.html | xargs ls -Art | tail -n 1 | xargs dirname) $(pwd)/portal/$webroot

# Set the symlink for nginx root directive to point to the latest Mobile index.html
ln -nsf $(find $(pwd)/$1/sitespeed-result/ -maxdepth 3 -name index.html | xargs ls -Art | tail -n 2 | xargs ls -At | tail -n 1 | xargs dirname) $(pwd)/portal/$webrootmobile

# Delete the older sitespeed-result runs
case $1 in
     tld ) find $(pwd)/$1/sitespeed-result/$2/ -mmin +240 | xargs rm -rf
           ;;
    comp ) find $(pwd)/$1/sitespeed-result/$2/ -mmin +300 | xargs rm -rf 
           ;;
esac
