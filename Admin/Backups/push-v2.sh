#!/bin/bash

############################################
#                                          #
#                push.sh                   #
#                  v 2                     #
#                                          #
############################################

# Set variables
Green='\033[0;32m'
NoColor='\033[0m' # No Color
Options="all update docker master config seed reset nginx cron"
Regions="US-East US-Central US-West Toronto London Frankfurt Singapore Tokyo Mumbai Sydney"

Regions="US-East"

successCnt=0
failureCnt=0
failure=""

# Function that checks the results of each primary action
function chkresult {
  if [ $? -eq 0 ]
    then
      let "successCnt++"
      echo "success"
    else
      let "failureCnt++"
      echo "fail"
      failure="$failure "$region" "
  fi
}

# Function that displays the results
function summary {
  if [ $successCnt -eq $(echo $Regions | wc -w) ]
    then
      echo "All $successCnt Linodes updated"
    else
      echo "Only $successCnt Linode(s) updated"
      echo "The following $failureCnt Linode(s) failed: $failure"
  fi
}

# Check to make sure ssh-add has been used to load an SSH identity
ssh-add -l > /dev/null
if [ $? -eq 1 ]
  then
    echo -e "\nSSH identify for Linode must be loaded\n"
    exit 1
fi
ssh-add -l | grep linode > /dev/null
if [ $? -eq 1 ]
  then
    echo -e "\nIt does not appear that the SSH identify for Linode is loaded\n"
    exit 1
fi

# Print help
if [[ "$1" == "--help" || "$1" == "-h" || "$1" == "/?" || $# -eq 0 ]]
    then
        echo -e "\n${Green}USAGE${NoColor} push arg1 [arg2 arg3]\n"
                
        echo -e "${Green}DESCRIPTION${NoColor} Automates the distribution and/or execution of key scripts across all Linodes.\nIntended to run from a local machine. If running from a Linode, be sure to modify the \nsource path of the scripts.\n"

        echo -e "The following options for arg1 are available:\n"

        echo -e "\t${Green}all${NoColor}\tCopies Sitespeed scripts across all Linodes\n"
        echo -e "\t${Green}config${NoColor}\tCopies config.json to /home/greg/tld and /home/greg/comp across all Linodes\n"
        echo -e "\t${Green}cron${NoColor}\tModifies crontab across all Linodes. Requires:\n"
        echo -e "\t\t${Green}arg2${NoColor} = list|update|delete\n"
        echo -e "\t${Green}docker${NoColor}\tExecutes docker commands across all Linodes. Requires:\n"
        echo -e "\t\t${Green}arg2${NoColor} = Version of Sitespeed (xx.y.z)\n"
        echo -e "\t${Green}master${NoColor}\tCopies master.sh to /home/greg across all Linodes\n"
        echo -e "\t${Green}nginx${NoColor}\tSets Web permissions across all Linodes by executing nginx.sh\n"
        echo -e "\t${Green}reset${NoColor}\tDeletes key data across all Linodes by executing reset.sh\n"
        echo -e "\t${Green}seed${NoColor}\tCopies test URL seed file to all Linodes. Requires:\n"
        echo -e "\t\t${Green}arg2${NoColor} = tld|comp"
        echo -e "\t\t${Green}arg3${NoColor} = Name of URL seed file\n"      
        echo -e "\t${Green}update${NoColor}\tUpdates YUM packages across all Linodes\n"
        exit 0
fi

# Check to make sure a valid argument was sumbitted
echo $Options | tr ' ' '\n' | grep -F -x -q $1
if [ $? -eq 1 ]
  then
    echo -e "\nIncorrect option was entered\n"
    exit 1
fi

# Process each option
case $1 in
      all ) for region in $Regions
              do
                echo -n "Starting "$region" ... "
                
                scp test.txt greg@"$region":./logs
                
                # scp -q Sitespeed/*.sh greg@"$region":/home/greg 2>/dev/null
                chkresult
              done
              summary
              exit 0
              ;;

   config ) for region in $Regions
              do
                echo -n "Starting "$region" ... "
                scp -q Sitespeed/config.json greg@"$region":/home/greg/tld 2>/dev/null
                scp -q Sitespeed/config.json greg@"$region":/home/greg/comp 2>/dev/null
                chkresult
              done
              summary
              exit 0
              ;;

     cron ) if [ $# -ne 2 ]
              then
                echo -e "\ncron requires 1 argument\n"
                exit 1
            fi
            echo "list update delete" | tr ' ' '\n' | grep -F -x -q $2
            if [ $? -eq 1 ]
              then
                echo -e "\narg2 must be list, update, or delete\n"
                exit 1
            fi
            for region in $Regions
              do
                case $2 in
                  list ) ssh greg@us-east crontab -l
                         exit 0
                         ;;
                update ) echo -n "Starting "$region" ... "
                         sed 's/XXX/\'$region'/' Sitespeed/mycron > Sitespeed/mycron.TMP
                         scp -q Sitespeed/mycron.TMP greg@"$region":/home/greg/mycron 2>/dev/null
                         ssh -q greg@"$region" crontab mycron 2>/dev/null
                         chkresult
                         ssh -q greg@"$region" rm /home/greg/mycron 2>/dev/null
                         rm Sitespeed/mycron.TMP
                         ;;
                delete ) echo -n "Starting "$region" ... "
                         ssh -q greg@"$region" crontab -r 2>/dev/null
                         chkresult
                         ;;
                esac         
              done
              summary
              exit 0
              ;;

   docker )   if [ $# -ne 2 ]
                then
                  echo -e "\nMust provide a Docker image version to be pulled\n"
                  exit 1
              fi
              for region in $Regions
                do
                  echo -n "Starting "$region" ... "
                  ssh -q greg@"$region" docker system prune --all --volumes -f > /dev/null
                  ssh -q greg@"$region" docker pull sitespeedio/sitespeed.io:$2 > /dev/null
                  chkresult
                done
                summary
                exit 0
                ;;

   master ) for region in $Regions
              do
                echo -n "Starting "$region" ... "
                scp -q Sitespeed/master.sh greg@"$region":/home/greg 2>/dev/null
                chkresult
              done
              summary
              exit 0
              ;;

    nginx ) for region in $Regions
              do
                echo -n "Starting "$region" ... "
                ssh -q greg@"$region" sudo /home/greg/nginx.sh 2&>/dev/null
                chkresult
              done
              summary
              exit 0
              ;;

    reset ) for region in $Regions
              do
                echo -n "Starting "$region" ... "
                ssh -q greg@"$region" /home/greg/reset.sh 2>/dev/null
                chkresult
              done
              summary
              exit 0
              ;;

     seed ) if [ $# -ne 3 ]
              then
                echo -e "\nseed requires 2 arguments\n"
                exit 1
            fi
            echo "tld comp" | tr ' ' '\n' | grep -F -x -q $2
            if [ $? -eq 1 ]
              then
                echo -e "\narg2 must be tld or comp\n"
                exit 1
            fi
            if [ ! -f Seeds/$3.txt ]
              then
                echo -e "\n$3.txt does not exist\n"
                exit 1
            fi
            for region in $Regions
              do
                echo -n "Starting "$region" ... "
                scp -q Seeds/$3.txt greg@"$region":/home/greg/$2 2>/dev/null
                chkresult
              done
              summary
              exit 0
              ;;

   update ) for region in $Regions
              do
                echo -n "Starting "$region" ... "
                ssh -q greg@"$region" sudo yum -y update 2&>/dev/null
                chkresult
              done
              summary
              exit 0
              ;;
esac