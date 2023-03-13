#!/bin/bash

############################################
#                                          #
#                push.sh                   #
#                  v 9                     #
#                                          #
############################################

# Set variables
Green='\033[0;32m'
NoColor='\033[0m'
Options="all update docker index master config seed reset nginx cron log"
Regions="US-East US-Central US-West Toronto London Frankfurt Singapore Tokyo Mumbai Sydney"
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
  if [ "$1" == "index" ]; then
     echo "Main Sitespeed portal updated"
   elif [ $successCnt -eq $(echo $Regions | wc -w) ]; then
     echo "$successCnt Linodes updated"
   elif [ $failureCnt -gt 0 ]; then
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
    sed -i .BAK ''$line's/YYY\.ZZZ/'${testType[$index]}'\.'${testName[$index]}'/' Sitespeed/mycron.UPD  
    let "line++"
  done
}

# Check to make sure ssh-add has been used to load an SSH identity
ssh-add -l &> /dev/null
if [ $? -eq 1 ]; then
   echo -e "\nSSH identify for Linode must be loaded\n"
   exit 1
fi
ssh-add -l | grep linode &> /dev/null
if [ $? -eq 1 ]; then
   echo -e "\nIt does not appear that the SSH identify for Linode is loaded\n"
   exit 1
fi

# Print help
if [[ "$1" == "--help" || "$1" == "-h" || "$1" == "/?" || $# -eq 0 ]]; then
   echo -e "\n${Green}USAGE${NoColor} push arg1 [arg2 arg3]\n"               
   echo -e "${Green}DESCRIPTION${NoColor} Automates the distribution and/or execution of key scripts across all Linodes.\nIntended to run from a local machine. If running from a Linode, be sure to modify the \nsource path of the scripts.\n"
   echo -e "The following options for arg1 are available:\n"
   echo -e "\t${Green}all${NoColor}\tCopies Sitespeed scripts across all Linodes\n"
   echo -e "\t${Green}config${NoColor}\tCopies config.json to ~/tld and ~/comp across all Linodes\n"
   echo -e "\t${Green}cron${NoColor}\tModifies crontab across all Linodes. Requires:\n"
   echo -e "\t\t${Green}arg2${NoColor} = list|update|delete\n"
   echo -e "\t${Green}docker${NoColor}\tExecutes docker commands across all Linodes. Requires:\n"
   echo -e "\t\t${Green}arg2${NoColor} = Version of Sitespeed (xx.y.z)\n"
   echo -e "\t${Green}index${NoColor}\tCopies index.html to the main Sitespeed portal\n"
   echo -e "\t${Green}log${NoColor}\tChecks for errors across all Linodes. Requires:\n"
   echo -e "\t\t${Green}arg2${NoColor} = check|delete\n"
   echo -e "\t${Green}master${NoColor}\tCopies master.sh across all Linodes\n"
   echo -e "\t${Green}nginx${NoColor}\tSets Web permissions across all Linodes\n"
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
                scp Sitespeed/*.sh greg@"$region": &> /dev/null
                chkresult
              done
              summary
              exit 0
              ;;

   config ) for region in $Regions
              do
                echo -n "Starting "$region" ... "
                scp Sitespeed/config.json greg@"$region":~/tld &> /dev/null
                scp Sitespeed/config.json greg@"$region":~/comp &> /dev/null
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
                  list ) ssh greg@us-east crontab -l
                         exit 0
                         ;;
                update ) echo -n "Starting "$region" ... "
                         sed 's/XXX/\'$region'/' Sitespeed/mycron.UPD > Sitespeed/mycron.REG
                         scp Sitespeed/mycron.REG greg@"$region":mycron &> /dev/null
                         ssh greg@"$region" crontab mycron &> /dev/null
                         chkresult
                         ssh greg@"$region" rm mycron &> /dev/null
                         ;;
                delete ) echo -n "Starting "$region" ... "
                         ssh greg@"$region" crontab -r &> /dev/null
                         chkresult
                         ;;
                esac         
              done
              if [ "$2" == "update" ]; then
                 rm Sitespeed/mycron.*
              fi
              summary
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
                ssh greg@"$region" docker system prune --all --volumes -f &> /dev/null
                ssh greg@"$region" docker pull sitespeedio/sitespeed.io:$2 &> /dev/null
                chkresult
              done
              summary
              exit 0
              ;;

    index ) echo -n "Updating Sitespeed portal ... "
            scp Portal/index.html greg@us-east:~/portal &> /dev/null
            chkresult
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
                  check ) ssh greg@"$region" ls ./logs/tld.*.msg.log &> /dev/null
                          if [ $? -eq 0 ]; then
                             tldErrorCnt=$(ssh greg@"$region" grep ERROR ./logs/tld.*.msg.log | wc -l)
                            else
                              tldErrorCnt="n/a"
                          fi
                          ssh greg@"$region" ls ./logs/comp.*.msg.log &> /dev/null
                          if [ $? -eq 0 ]; then
                             compErrorCnt=$(ssh greg@"$region" grep ERROR ./logs/comp.*.msg.log | wc -l)
                            else
                              compErrorCnt="n/a"
                          fi
                          echo ""$region" errors: tld=$tldErrorCnt comp=$compErrorCnt"
                          ;;
                 delete ) echo -n "Starting "$region" ... "
                          ssh greg@"$region" rm ./logs/*.log
                          chkresult
                          ;;
                esac         
              done
              summary
              exit 0
              ;;

   master ) for region in $Regions
              do
                echo -n "Starting "$region" ... "
                scp Sitespeed/master.sh greg@"$region": &> /dev/null
                chkresult
              done
              summary
              exit 0
              ;;
  
    nginx ) for region in $Regions
              do
                echo -n "Starting "$region" ... "
                ssh greg@"$region" sudo ./nginx.sh &> /dev/null
                chkresult
              done
              summary
              exit 0
              ;;

    reset ) for region in $Regions
              do
                echo -n "Starting "$region" ... "
                ssh -q greg@"$region" ./reset.sh 2>/dev/null
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
                scp Seeds/$3.txt greg@"$region":~/$2 &> /dev/null
                chkresult
              done
              summary
              exit 0
              ;;

   update ) for region in $Regions
              do
                echo -n "Starting "$region" ... "
                ssh greg@"$region" sudo yum -y update &> /dev/null
                chkresult
              done
              summary
              exit 0
              ;;
esac
