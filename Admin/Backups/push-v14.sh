#!/bin/bash

############################################
#                                          #
#                push.sh                   #
#                  v 14                    #
#                                          #
############################################

# Set variables
Green='\033[0;32m'
NoColor='\033[0m'
Options="all update docker portal seed reset nginx cron log"
Regions="PSI-CrUX US-East US-Central US-West Toronto London Frankfurt Singapore Tokyo Mumbai Sydney"
Domain="sitespeed.akadns.net"
successCnt=0
failureCnt=0
failure=""

# Function that checks the results of each primary action
function chkresult {
  if [ $? -eq 0 ]; then
     let "successCnt++"
     echo "success"
    else
     let "failureCnt++"
     echo "fail"
     failure="$failure "$region""
  fi
}

# Function that displays the results
function summary {
  if [ $successCnt -eq $(echo $Regions | wc -w) ]; then
     echo "$successCnt Linodes updated"
   else
     echo "$successCnt Linodes updated"
     echo "$failureCnt Linodes failed: $failure"
  fi
}

# Function that updates mycron template
function mycron {
  testType=( $(cat Sitespeed/mycron | awk '{print $7}') )
  testName=( $(cat Sitespeed/mycron | awk '{print $8}') )
  cp Sitespeed/mycron Sitespeed/mycron.UPD
  line=1
  for (( index=0; index < ${#testType[@]} ; index+=1 ))
   do
    sed -i ''$line's/YYY\.ZZZ/'${testType[$index]}'\.'${testName[$index]}'/' Sitespeed/mycron.UPD  
    let "line++"
  done
}

# Function that displays result of crontab -l
function cronlist {
  if [ $? -eq 0 ]; then
     echo -e "\nDisplaying "$region" ... "
     cat Sitespeed/crontab
     rm Sitespeed/crontab
    else
     echo -e "\nDisplaying "$region" ... no entry exists"
     rm Sitespeed/crontab
  fi
}

# Function that displays result of crontab -r
function crondelete {
  if [ $? -eq 0 ]; then
     echo "success"
    else
     echo "no entry to delete"
  fi
}

# Print help
if [[ "$1" == "--help" || "$1" == "-h" || "$1" == "/?" || $# -eq 0 ]]; then
   echo -e "\n${Green}USAGE${NoColor} push arg1 [arg2 arg3]\n"               
   echo -e "${Green}DESCRIPTION${NoColor} Automates the distribution and/or execution of key scripts across all Linodes.\nIntended to run from a local machine. If running from a Linode, be sure to modify the \nsource path of the scripts.\n"
   echo -e "The following options for arg1 are available:\n"
   echo -e "\t${Green}all${NoColor}\tCopies scripts and config.json across all Linodes\n"
   echo -e "\t${Green}cron${NoColor}\tModifies crontab across all Linodes. Requires:\n"
   echo -e "\t\t${Green}arg2${NoColor} = list|update|delete\n"
   echo -e "\t${Green}docker${NoColor}\tExecutes docker commands across all Linodes. Requires:\n"
   echo -e "\t\t${Green}arg2${NoColor} = Version of Sitespeed (xx.y.z)\n"
   echo -e "\t${Green}log${NoColor}\tChecks for errors across all Linodes. Requires:\n"
   echo -e "\t\t${Green}arg2${NoColor} = check|delete\n"
   echo -e "\t${Green}nginx${NoColor}\tSets Web permissions across all Linodes\n"
   echo -e "\t${Green}portal${NoColor}\tCopies portal related files across all Linodes\n"   
   echo -e "\t${Green}reset${NoColor}\tDeletes key data across all Linodes\n"
   echo -e "\t${Green}seed${NoColor}\tCopies test URL seed file to all Linodes. Requires:\n"
   echo -e "\t\t${Green}arg2${NoColor} = tld|comp"
   echo -e "\t\t${Green}arg3${NoColor} = Name of URL seed file\n" 
   echo -e "\t${Green}update${NoColor}\tUpdates YUM packages across all Linodes\n"
   exit 0
fi

# Check to make sure a valid argument was sumbitted
echo $Options | tr ' ' '\n' | grep -F -x -q $1
if [ $? -eq 1 ]; then
   echo -e "\n$1 is not a valid argument\n"
   exit 1
fi

# Process each option
case $1 in
      all ) for region in $Regions
              do
                echo -n "Starting "$region" ... "
                scp Sitespeed/*.sh "$region".$Domain: &> /dev/null
                scp Sitespeed/config.json "$region".$Domain:~/tld &> /dev/null
                scp Sitespeed/config.json "$region".$Domain:~/comp &> /dev/null
                chkresult
              done
            summary
            exit 0
            ;;

     cron ) if [ $# -ne 2 ]; then
               echo -e "\ncron requires 1 argument: list|update|delete\n"
               exit 1
            fi
            echo "list update delete" | tr ' ' '\n' | grep -F -x -q $2
            if [ $? -eq 1 ]; then
               echo -e "\narg2 must be list, update, or delete\n"
               exit 1
            fi
            if [ "$2" == "update" ]; then
               mycron
            fi           
            for region in $Regions
              do
                case $2 in
                  list ) ssh "$region".$Domain crontab -l &> Sitespeed/crontab
                         cronlist
                         ;;
                update ) echo -n "Starting "$region" ... "
                         sed 's/XXX/'$region'/' Sitespeed/mycron.UPD > Sitespeed/mycron.REG                         
                         scp Sitespeed/mycron.REG "$region".$Domain:mycron &> /dev/null
                         ssh "$region".$Domain crontab mycron &> /dev/null
                         chkresult
                         ssh "$region".$Domain rm mycron &> /dev/null
                         ;;
                delete ) echo -n "Starting "$region" ... "
                         ssh "$region".$Domain crontab -r &> /dev/null
                         crondelete
                         ;;
                esac         
              done
            if [ "$2" == "update" ]; then
               rm Sitespeed/mycron.*
            fi
            ### summary
            exit 0
            ;;

   docker ) if [ $# -ne 2 ]; then
               echo -e "\nMust provide a Docker image tag to be pulled\n"
               exit 1
            fi
            docker manifest inspect sitespeedio/sitespeed.io:$2 &> /dev/null
            if [ $? -eq 1 ]; then
               echo -e "\nDocker image tag $2 does not exist\n"
               exit 1
            fi
            for region in $Regions
              do
                echo -n "Starting "$region" ... "
                ssh "$region".$Domain docker system prune --all --volumes -f &> /dev/null
                ssh "$region".$Domain docker pull sitespeedio/sitespeed.io:$2 &> /dev/null
                chkresult
              done
            summary
            exit 0
            ;;
         
      log ) if [ $# -ne 2 ]; then
               echo -e "\nlog requires 1 argument: check|delete\n"
               exit 1
            fi
            echo "check delete" | tr ' ' '\n' | grep -F -x -q $2
            if [ $? -eq 1 ]; then
               echo -e "\narg2 must be check or delete\n"
               exit 1
            fi
            for region in $Regions
              do
                case $2 in
                  check ) ssh "$region".$Domain ls ./logs/tld.*.msg.log &> /dev/null
                          if [ $? -eq 0 ]; then
                             tldErrorCnt=$(ssh "$region".$Domain grep ERROR ./logs/tld.*.msg.log | wc -l)
                            else
                              tldErrorCnt="n/a"
                          fi
                          ssh "$region".$Domain ls ./logs/comp.*.msg.log &> /dev/null
                          if [ $? -eq 0 ]; then
                             compErrorCnt=$(ssh "$region".$Domain grep ERROR ./logs/comp.*.msg.log | wc -l)
                            else
                              compErrorCnt="n/a"
                          fi
                          echo ""$region" errors: tld=$tldErrorCnt comp=$compErrorCnt"
                          ;;
                 delete ) echo -n "Starting "$region" ... "
                          ssh "$region".$Domain rm ./logs/*.log
                          chkresult
                          ;;
                esac         
              done
            exit 0
            ;;
  
    nginx ) for region in $Regions
              do
                echo -n "Starting "$region" ... "
                ssh "$region".$Domain sudo ./nginx.sh &> /dev/null
                chkresult
              done
            summary
            exit 0
            ;;
            
            
   portal ) for region in $Regions
              do
                echo -n "Starting "$region" ... "
                scp -r Portal/* "$region".$Domain:~/portal/ &> /dev/null
                chkresult
              done
            summary
            exit 0
            ;;
      
    reset ) for region in $Regions
              do
                echo -n "Starting "$region" ... "
                ssh -q "$region".$Domain ./reset.sh 2>/dev/null
                chkresult
              done
            summary
            exit 0
            ;;

     seed ) if [ $# -ne 3 ]; then
               echo -e "\nseed requires 2 arguments\n"
               exit 1
            fi
            echo "tld comp" | tr ' ' '\n' | grep -F -x -q $2
            if [ $? -eq 1 ]; then
               echo -e "\narg2 must be tld or comp\n"
               exit 1
            fi
            if [ ! -f Seeds/$3.txt ]; then
               echo -e "\n$3.txt does not exist\n"
               exit 1
            fi
            for region in $Regions
              do
                echo -n "Starting "$region" ... "
                scp Seeds/$3.txt "$region".$Domain:~/$2 &> /dev/null
                chkresult
              done
            summary
            exit 0
            ;;
           
   update ) for region in $Regions
              do
                echo -n "Starting "$region" ... "
                ssh "$region".$Domain sudo yum -y update &> /dev/null
                chkresult
              done
            summary
            exit 0
            ;;
esac