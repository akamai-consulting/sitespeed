#!/bin/bash

############################################
#                                          #
#                push.sh                   #
#                 v 24                     #
#                                          #
############################################

# Set variables
Green='\033[0;32m'
NoColor='\033[0m'
Options="all update docker portal seed reset nginx cron logs custom cert graphite grafana storage core"
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

# Function that updates mycron template
function mycron {
   testType=( $(cat $1 | awk '{print $7}') )
   testName=( $(cat $1 | awk '{print $8}') )
   cp $1 $1.UPD
   line=1
   for (( index=0; index < ${#testType[@]} ; index+=1 ))
     do
       sed -i ''$line's/YYY\.ZZZ/'${testType[$index]}'\.'${testName[$index]}'/' $1.UPD  
       let "line++"
     done
}

# Function that displays result of crontab -l
function cronlist {
  if [ $? -eq 0 ]; then
     echo -e "\nDisplaying "$region" ... "
     grep -v -e '^$' Sitespeed/crontab
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
   echo -e "${Green}DESCRIPTION${NoColor} Automates the distribution and/or execution of key scripts across all Linodes\n"
   
   echo -e "The following options for arg1 are available:\n"
   
   echo -e "\t${Green}all${NoColor}\t   Copies scripts and config.json across all Linodes\n"
   
   echo -e "\t${Green}cert${NoColor}\t   Checks the certificate renewal date across all Linodes\n"
   
   echo -e "\t${Green}core${NoColor}\t   Checks for core files across all Linodes. Requires:"
   echo -e "\t\t   ${Green}arg2${NoColor} = check|delete\n"

   echo -e "\t${Green}cron${NoColor}\t   Modifies crontab across all Linodes. Requires:"
   echo -e "\t\t   ${Green}arg2${NoColor} = check|update|delete\n"
   
   echo -e "\t${Green}docker${NoColor}\t   Executes various docker commands across all Linodes. Requires:"
   echo -e "\t\t   ${Green}arg2${NoColor} = check|clean\n"
   
   echo -e "\t${Green}grafana${NoColor}    Update Grafana\n"

   echo -e "\t${Green}graphite${NoColor}   Manages the size of graphite.db. Requires:"
   echo -e "\t\t   ${Green}arg2${NoColor} = check|reduce\n"
   
   echo -e "\t${Green}logs${NoColor}\t   Checks for errors across all Linodes. Requires:"
   echo -e "\t\t   ${Green}arg2${NoColor} = check|delete\n"
   
   echo -e "\t${Green}nginx${NoColor}\t   Sets Web permissions across all Linodes\n"
   
   echo -e "\t${Green}portal${NoColor}\t   Copies portal related files across all Linodes\n"
      
   echo -e "\t${Green}reset${NoColor}\t   Deletes key data across all Linodes\n"
   
   echo -e "\t${Green}seed${NoColor}\t   Copies test URL seed file to all Linodes. Requires:"
   echo -e "\t\t   ${Green}arg2${NoColor} = tld|comp"
   echo -e "\t\t   ${Green}arg3${NoColor} = URL seed file\n"
   
   echo -e "\t${Green}storage${NoColor}\t   Checks the amount of storage used on all Linodes\n"
   
   echo -e "\t${Green}update${NoColor}\t   Updates YUM packages across all Linodes\n"
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
                if [ "$region" == "PSI-CrUX" ]; then
                   scp PSI-CrUX/google.sh "$region".$Domain: &> /dev/null
                 else
                   scp Sitespeed/*.sh "$region".$Domain: &> /dev/null
                   scp Sitespeed/config.json "$region".$Domain:~/tld &> /dev/null
                   scp Sitespeed/config.json "$region".$Domain:~/comp &> /dev/null
                fi
                chkresult
              done
            exit 0
            ;;
            
     cert ) echo -e "\nStarting Grafana/Graphite ... "
            ssh grafana.$Domain sudo certbot certificates 
            for region in $Regions
              do
                echo -e "\nStarting "$region" ... "
                ssh "$region".$Domain sudo certbot certificates 
              done
              
            exit 0
            ;;

     core ) if [ $# -ne 2 ]; then
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
                  check ) echo -n "Checking "$region" ... "
                          ssh "$region".$Domain find ~/ -maxdepth 2 -name core* -type f | wc -l
                          ;;
                 delete ) echo -n "Starting "$region" ... "
                          ssh "$region".$Domain find /home/greg -maxdepth 2 -name core* -type f -delete &> /dev/null
                          chkresult
                          ;;
                esac         
              done
            exit 0
            ;;

     cron ) if [ $# -ne 2 ]; then
               echo -e "\ncron requires 1 argument: check|update|delete\n"
               exit 1
            fi
            echo "check update delete" | tr ' ' '\n' | grep -F -x -q $2
            if [ $? -eq 1 ]; then
               echo -e "\narg2 must be check, update, or delete\n"
               exit 1
            fi
            if [ "$2" == "update" ]; then
               mycron "PSI-CrUX/psicron"
               mycron "Sitespeed/sitecron"
            fi           
            case $2 in
               check ) crontab -l &> Sitespeed/crontab
                       if [ $? -eq 0 ]; then
                           echo -e "\nDisplaying Jump ... "
                           grep -v -e '^$' Sitespeed/crontab
                           rm Sitespeed/crontab
                       else
                           echo -e "\nDisplaying Jump ... no entry exists"
                           rm Sitespeed/crontab
                       fi
                       ;;
              update ) crontab jumpcron &> /dev/null
                       ;;
              delete ) crontab -r                 
                       ;;
            esac
            for region in $Regions
              do
                case $2 in
                 check ) ssh "$region".$Domain crontab -l &> Sitespeed/crontab
                         cronlist
                         ;;
                update ) echo -n "Starting "$region" ... "
                         if [ "$region" == "PSI-CrUX" ]; then
                             sed 's/XXX/'$region'/' PSI-CrUX/psicron.UPD > PSI-CrUX/psicron.REG                         
                             scp PSI-CrUX/psicron.REG "$region".$Domain:crondata &> /dev/null
                             ssh "$region".$Domain crontab crondata &> /dev/null
                             ssh "$region".$Domain rm crondata &> /dev/null
                           else
                             sed 's/XXX/'$region'/' Sitespeed/sitecron.UPD > Sitespeed/sitecron.REG                         
                             scp Sitespeed/sitecron.REG "$region".$Domain:crondata &> /dev/null
                             ssh "$region".$Domain crontab crondata &> /dev/null
                             ssh "$region".$Domain rm crondata &> /dev/null
                         fi
                         chkresult
                         ;;

                delete ) echo -n "Starting "$region" ... "
                         ssh "$region".$Domain crontab -r &> /dev/null
                         crondelete
                         ;;
                esac         
              done
            echo ""
            if [ "$2" == "update" ]; then
               rm Sitespeed/sitecron.*
               rm PSI-CrUX/psicron.*
            fi
            exit 0
            ;;

   docker ) if [ $# -ne 2 ]; then
               echo -e "\ndocker requires 1 argument: check|clean\n"
               exit 1
            fi
            echo "check clean" | tr ' ' '\n' | grep -F -x -q $2
            if [ $? -eq 1 ]; then
               echo -e "\narg2 must be check or clean\n"
               exit 1
            fi
            for region in $Regions
              do
                case $2 in
                 check ) echo -e "\nChecking "$region" ... "
                         ssh "$region".$Domain docker image ls
                         ssh "$region".$Domain docker container ls
                         ;;
                 clean ) echo -n "Cleaning "$region" ... "
                         ssh "$region".$Domain docker stop $(docker ps -a -q) &> /dev/null
                         sleep 5
                         ssh "$region".$Domain docker rm -f $(docker ps -a -q) &> /dev/null
                         sleep 5
                         ssh "$region".$Domain docker system prune --all --volumes -f &> /dev/null
                         chkresult
                         ;;
                esac         
              done
            exit 0
            ;;
         
  grafana ) echo -n "Updating Grafana ... "
            ssh grafana.$Domain sudo yum update -y grafana-enterprise &> /dev/null
            ssh grafana.$Domain sudo systemctl restart grafana-server &> /dev/null
            chkresult
            exit 0
            ;;

 graphite ) if [ $# -ne 2 ]; then
               echo -e "\nlog requires 1 argument: check|reduce\n"
               exit 1
            fi
            echo "check reduce" | tr ' ' '\n' | grep -F -x -q $2
            if [ $? -eq 1 ]; then
               echo -e "\narg2 must be check or reduce\n"
               exit 1
            fi
               case $2 in
                  check ) echo ""
                          ssh graphite.$Domain ls -l graphite-storage/graphite.db
                          ssh graphite.$Domain du -sh graphite-storage/graphite.db
                          echo ""
                          ;;
                 reduce ) echo -n "Reducing graphite.db on Graphite ... "
                          ssh graphite.$Domain sudo  ./sqlite.sh &> /dev/null
                          if [ $? -eq 0 ]; then
                             echo "success"
                           else
                             echo "fail"
                          fi
                          ;;
               esac         
            exit 0
            ;;

     logs ) if [ $# -ne 2 ]; then
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
                  check ) ssh "$region".$Domain ls logs/tld.*.msg.log &> /dev/null
                          if [ $? -eq 0 ]; then
                             tldErrorCnt=$(ssh "$region".$Domain grep -i error logs/tld.*.msg.log | wc -l)
                            else
                              tldErrorCnt="n/a"
                          fi
                          ssh "$region".$Domain ls logs/comp.*.msg.log &> /dev/null
                          if [ $? -eq 0 ]; then
                             compErrorCnt=$(ssh "$region".$Domain grep -i error logs/comp.*.msg.log | wc -l)
                            else
                              compErrorCnt="n/a"
                          fi
                          echo ""$region" errors: tld=$tldErrorCnt comp=$compErrorCnt"
                          ;;
                 delete ) echo -n "Starting "$region" ... "
                          ssh "$region".$Domain rm logs/*.*.log
                          chkresult
                          ;;
                esac         
              done
            exit 0
            ;;
  
    nginx ) for region in $Regions
              do
                echo -n "Starting "$region" ... "
                if [ "$region" != "PSI-CrUX" ]; then
                   ssh "$region".$Domain sudo ./nginx.sh &> /dev/null
                   chkresult
                fi
              done
            exit 0
            ;;
            
            
   portal ) for region in $Regions
              do
                echo -n "Starting "$region" ... "
                scp -r Portal/* "$region".$Domain:~/portal/ &> /dev/null
                chkresult
              done
            exit 0
            ;;
      
    reset ) for region in $Regions
              do
                echo -n "Starting "$region" ... "
                if [ "$region" != "PSI-CrUX" ]; then
                   ssh -q "$region".$Domain ./reset.sh 2>/dev/null
                   chkresult
                fi
              done
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
            exit 0
            ;;
            
  storage ) echo ""
            for region in $Regions
              do
                if [ "$region" != "PSI-CrUX" ]; then
                   echo "Starting "$region" ... "
                   ssh "$region".$Domain du -sh ~/portal
                   ssh "$region".$Domain du -sh ~/tld
                   ssh "$region".$Domain du -sh ~/comp
                   echo ""
                fi
              done
            exit 0
            ;;
           

   update ) for region in $Regions
              do
                echo -n "Starting "$region" ... "
                ssh "$region".$Domain sudo yum -y update &> /dev/null
                chkresult
              done
            exit 0
            ;;
            
## This is an undocumented argument to perform ad-hoc commands
   custom ) Regions="US-East US-Central US-West Toronto London Frankfurt Singapore Tokyo Mumbai Sydney"
            for region in $Regions
              do
                echo "Starting "$region" ... "
                ssh "$region".$Domain ls -l
              done
            exit 0
            ;;
esac