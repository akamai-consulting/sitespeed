#!/bin/bash

############################################
#                                          #
#                admin.sh                  #
#                 v 24                     #
#                                          #
############################################

# Set variables
Green='\033[0;32m'
NoColor='\033[0m'
Options="all update docker seed reset cron logs cert graphite grafana storage core"
Host=[HOST]
Domain=[DOMAIN]
Servers="[SERVERS]"
Google=[GOOGLE]
Graphite=[GRAPHITE]
Key=$HOME/.ssh/sitespeed
Root=/usr/local/sitespeed
successCnt=0
failureCnt=0
failure=""

# Function that checks the results of each primary action
function chkresult {
  if [ $? -eq 0 ]; then
     let "successCnt++"
     echo "Success"
    else
     let "failureCnt++"
     echo "Fail"
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
     grep -v -e '^$' cron/crontab
     rm cron/crontab
    else
     echo -e "\nDisplaying "$region" ... No entry exists"
     rm cron/crontab
  fi
}

# Function that displays result of crontab -r
function crondelete {
  if [ $? -eq 0 ]; then
     echo "success"
    else
     echo "No entry to delete"
  fi
}

# Print help
if [[ "$1" == "--help" || "$1" == "-h" || "$1" == "/?" || $# -eq 0 ]]; then
   echo -e "\n${Green}USAGE${NoColor} admin arg1 [arg2 arg3]\n"               
   echo -e "${Green}DESCRIPTION${NoColor} Automates the distribution files and execution of scripts across servers\n"
   
   echo -e "The following options are available:\n"
   
   echo -e "\t${Green}all${NoColor}\t   Copies customized files across servers\n"
   
   echo -e "\t${Green}cert${NoColor}\t   Checks the certificate renewal date on servers\n"
   
   echo -e "\t${Green}core${NoColor}\t   Checks for core files on servers. Requires:"
   echo -e "\t\t   ${Green}arg2${NoColor} = check|delete\n"

   echo -e "\t${Green}cron${NoColor}\t   Schedules cron jobs on servers. Requires:"
   echo -e "\t\t   ${Green}arg2${NoColor} = check|update|delete\n"
   
   echo -e "\t${Green}docker${NoColor}\t   Performs various docker functions on servers. Requires:"
   echo -e "\t\t   ${Green}arg2${NoColor} = check|clean\n"
   
   echo -e "\t${Green}grafana${NoColor}    Updates Grafana to the latest version. Requires:\n"
   echo -e "\t\t   ${Green}arg2${NoColor} = update|provision\n"

   echo -e "\t${Green}graphite${NoColor}   Manages the size of graphite.db. Requires:"
   echo -e "\t\t   ${Green}arg2${NoColor} = check|reduce\n"
   
   echo -e "\t${Green}logs${NoColor}\t   Checks for errors on servers. Requires:"
   echo -e "\t\t   ${Green}arg2${NoColor} = check|delete\n"
   
   echo -e "\t${Green}reset${NoColor}\t   Deletes Sitespeed data on servers\n"
   
   echo -e "\t${Green}seed${NoColor}\t   Manages the seed files on servers. Requires:"
   echo -e "\t\t   ${Green}arg2${NoColor} = tld|comp|delete"
   echo -e "\t\t   ${Green}arg3${NoColor} = seed file\n"
   
   echo -e "\t${Green}storage${NoColor}\t   Checks the amount of storage used on servers\n"
   
   echo -e "\t${Green}update${NoColor}\t   Updates packages on all servers\n"
   exit 0
fi

# Make sure the user has a known_hosts file
if [ ! -f $HOME/.ssh/known_hosts ]; then
   echo -e "\nCreating an SSH known_hosts file"
   All="$Servers $Google $Graphite"
   for region in $All
     do
      echo -e "\nAdding "$region" ... "
      ssh -i $Key "$region".$Domain ls
     done
fi

# Make sure sitespeed user has a known_hosts file
sudo ls /home/sitespeed/.ssh/known_hosts &> /dev/null
if [ "$?" -ne "0" ]; then
   sudo cp $HOME/.ssh/known_hosts /home/sitespeed/.ssh/known_hosts
   sudo chown sitespeed /home/sitespeed/.ssh/known_hosts
   sudo chgrp sitespeed /home/sitespeed/.ssh/known_hosts
   sudo chmod 644 /home/sitespeed/.ssh/known_hosts
fi

# First time initialization
if [ ! -f $Root/google/google.sh ]; then
   scp -q -i $Key $(whoami)@$Google.$Domain:$Root/google.sh /usr/local/sitespeed/google/
   echo ""
   for region in $Servers
    do
     echo "Updating index.html on "$region" ... "
     until [ $? ]
       do
         scp -q -i $Key $Root/portal/index.html $(whoami)@"$region".$Domain:$Root/portal/
       done
    done
fi

# Check to make sure a valid argument was sumbitted
echo $Options | tr ' ' '\n' | grep -F -x -q $1
if [ $? -eq 1 ]; then
   echo -e "\n$1 is not a valid argument\n"
   exit 1
fi

# Process each option
case $1 in
      all ) echo -n "Updating "$Google" ... "
            scp -q -i $Key $Root/google/google.sh $(whoami)@"$Google".$Domain:$Root
            chkresult
            for region in $Servers
              do
                echo -n "Updating "$region" ... "           
                   scp -q -i $Key $Root/sitespeed/*.sh $(whoami)@"$region".$Domain:$Root
                   scp -q -i $Key $Root/sitespeed/config.json $(whoami)@"$region".$Domain:$Root/tld
                   scp -q -i $Key $Root/sitespeed/config.json $(whoami)@"$region".$Domain:$Root/comp
                   scp -q -i $Key $Root/portal/index.html $(whoami)@"$region".$Domain:$Root/portal
                chkresult
              done
            exit 0
            ;;
 
     cert ) echo -e "\nChecking "$Graphite" ... "
            ssh -i $Key $(whoami)@$Graphite.$Domain sudo certbot certificates 
            for region in $Servers
              do
                echo -e "\nChecking "$region" ... "
                ssh -i $Key $(whoami)@"$region".$Domain sudo certbot certificates 
              done              
            exit 0
            ;;

     core ) if [ $# -ne 2 ]; then
               echo -e "\ncore requires 1 argument: check|delete\n"
               exit 1
            fi
            echo "check delete" | tr ' ' '\n' | grep -F -x -q $2
            if [ $? -eq 1 ]; then
               echo -e "\narg2 must be check or delete\n"
               exit 1
            fi
            All="$Google $Servers"
            for region in $All
              do
                case $2 in
                  check ) echo -n "Checking "$region" ... "
                          ssh -i $Key $(whoami)@"$region".$Domain find $Root/ -maxdepth 2 -name core* -type f | wc -l
                          ;;
                 delete ) echo -n "Deleting core files on "$region" ... "
                          ssh -q -i $Key $(whoami)@"$region".$Domain find $Root/ -maxdepth 2 -name core* -type f -delete
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
               mycron "cron/psicron"
               mycron "cron/sitecron"
            fi           
            case $2 in
               check ) sudo -u sitespeed crontab -l &> cron/crontab
                       if [ $? -eq 0 ]; then
                           echo -e "\nDisplaying "$Host" ... "
                           grep -v -e '^$' cron/crontab
                           rm cron/crontab
                       else
                           echo -e "\nDisplaying "$Host" ... no entry exists"
                           rm cron/crontab
                       fi
                       ;;
              update ) echo -n "Updating "$Host" ... "
                       sudo -u sitespeed crontab /home/sitespeed/jumpcron &> /dev/null
                       chkresult
                       ;;
              delete ) echo -n "Updating "$Host" ... "
                       sudo -u sitespeed crontab -r &> /dev/null
                       crondelete                
                       ;;
            esac
            All="$Google $Servers"
            for region in $All
              do
                case $2 in
                 check ) ssh -i $Key $(whoami)@"$region".$Domain sudo -u sitespeed crontab -l &> cron/crontab
                         cronlist
                         ;;
                update ) echo -n "Updating "$region" ... "
                         if [ "$region" == "$Google" ]; then
                             sed 's/XXX/'$region'/' cron/psicron.UPD > cron/psicron.REG                     
                             scp -q -i $Key cron/psicron.REG $(whoami)@"$region".$Domain:crondata
                             ssh -i $Key $(whoami)@"$region".$Domain sudo mv crondata /home/sitespeed/
                             ssh -i $Key $(whoami)@"$region".$Domain sudo chown sitespeed /home/sitespeed/crondata                         
                             ssh -i $Key $(whoami)@"$region".$Domain sudo -u sitespeed crontab /home/sitespeed/crondata &> /dev/null
                             ssh -q -i $Key $(whoami)@"$region".$Domain sudo rm /home/sitespeed/crondata
                           else
                             sed 's/XXX/'$region'/' cron/sitecron.UPD > cron/sitecron.REG                         
                             scp -q -i $Key cron/sitecron.REG $(whoami)@"$region".$Domain:crondata
                             ssh -i $Key $(whoami)@"$region".$Domain sudo mv crondata /home/sitespeed/
                             ssh -i $Key $(whoami)@"$region".$Domain sudo chown sitespeed /home/sitespeed/crondata                         
                             ssh -i $Key $(whoami)@"$region".$Domain sudo -u sitespeed crontab /home/sitespeed/crondata &> /dev/null
                             ssh -q -i $Key $(whoami)@"$region".$Domain sudo rm /home/sitespeed/crondata
                         fi
                         chkresult
                         ;;

                delete ) echo -n "Updating "$region" ... "
                         ssh -i $Key $(whoami)@"$region".$Domain sudo -u sitespeed crontab -r &> /dev/null
                         crondelete
                         ;;
                esac         
              done
            echo ""
            if [ "$2" == "update" ]; then
               rm cron/sitecron.*
               rm cron/psicron.*
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
            All="$Google $Servers"
            for region in $All
              do
                case $2 in
                 check ) echo -e "\nChecking "$region" ... "
                         ssh -i $Key $(whoami)@"$region".$Domain docker image ls
                         ssh -i $Key $(whoami)@"$region".$Domain docker container ls
                         ;;
                 clean ) echo -n "Cleaning "$region" ... "
                         ssh -i $Key $(whoami)@"$region".$Domain docker stop $(ssh -i $Key $(whoami)@"$region".$Domain docker ps -a -q) &> /dev/null
                         sleep 3
                         ssh -i $Key $(whoami)@"$region".$Domain docker rm -f $(ssh -i $Key $(whoami)@"$region".$Domain docker ps -a -q) &> /dev/null
                         sleep 3
                         ssh -i $Key $(whoami)@"$region".$Domain docker system prune --all --volumes -f &> /dev/null
                         chkresult
                         ;;
                esac         
              done
            exit 0
            ;;
                 
  grafana ) if [ $# -ne 2 ]; then
               echo -e "\ngrafana requires 1 argument: update|provision\n"
               exit 1
            fi
            echo "update provision" | tr ' ' '\n' | grep -F -x -q $2
            if [ $? -eq 1 ]; then
               echo -e "\narg2 must be update or provision\n"
               exit 1
            fi
            case $2 in
                    update ) echo -n "Updating "$Graphite" ... "
                             ssh -q -i $Key $(whoami)@$Graphite.$Domain sudo yum -y update grafana-enterprise &> /dev/null
                             ssh -q -i $Key $(whoami)@$Graphite.$Domain sudo systemctl restart grafana-server &> /dev/null
                             chkresult
                             exit 0
                             ;;
                 provision ) echo -n "Provisioning new dashboards on "$Graphite" ... "            
                             ssh -q -i $Key $(whoami)@$Graphite.$Domain sudo /usr/local/graphite/provision.sh update
                             ssh -q -i $Key $(whoami)@$Graphite.$Domain sudo mv -f /provision.sh /usr/local/graphite/provision.sh
                             ssh -q -i $Key $(whoami)@$Graphite.$Domain sudo chmod 755 /usr/local/graphite/provision.sh
                             ssh -q -i $Key $(whoami)@$Graphite.$Domain sudo /usr/local/graphite/provision.sh
                             chkresult
                             exit 0
                             ;;
            esac
            exit 0
            ;;
            
 graphite ) if [ $# -ne 2 ]; then
               echo -e "\ngraphite requires 1 argument: check|reduce\n"
               exit 1
            fi
            echo "check reduce" | tr ' ' '\n' | grep -F -x -q $2
            if [ $? -eq 1 ]; then
               echo -e "\narg2 must be check or reduce\n"
               exit 1
            fi
               case $2 in
                  check ) echo "Checking graphite.db on "$Graphite" ... "
                          ssh -i $Key $(whoami)@$Graphite.$Domain du -sh /usr/local/graphite/graphite-storage/graphite.db
                          ;;
                 reduce ) echo -n "Reducing graphite.db on "$Graphite" ... "
                          ssh -q -i $Key $(whoami)@$Graphite.$Domain sudo /usr/local/graphite/sqlite.sh
                          chkresult
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
            All="$Google $Servers"
            for region in $All
              do
                case $2 in
                  check ) ssh -i $Key $(whoami)@"$region".$Domain ls logs/tld.*.msg.log &> /dev/null
                          if [ $? -eq 0 ]; then
                             tldErrorCnt=$(ssh -q -i $Key $(whoami)@"$region".$Domain grep -i error logs/tld.*.msg.log | wc -l)
                            else
                              tldErrorCnt="n/a"
                          fi
                          ssh -i $Key $(whoami)@"$region".$Domain ls logs/comp.*.msg.log &> /dev/null
                          if [ $? -eq 0 ]; then
                             compErrorCnt=$(ssh -q -i $Key $(whoami)@"$region".$Domain grep -i error logs/comp.*.msg.log | wc -l)
                            else
                              compErrorCnt="n/a"
                          fi
                          echo ""$region" errors: tld=$tldErrorCnt comp=$compErrorCnt"
                          ;;
                 delete ) echo -n "Starting "$region" ... "
                          ssh -i $Key $(whoami)@"$region".$Domain rm logs/*log &> /dev/null
                          chkresult
                          ;;
                esac         
              done
            exit 0
            ;;
      
    reset ) for region in $Servers
              do
                echo -n "Resetting "$region" ... "
                ssh -i $Key $(whoami)@"$region".$Domain rm $Root/logs/* &> /dev/null
                ssh -i $Key $(whoami)@"$region".$Domain rm $Root/tld/*.txt &> /dev/null
                ssh -i $Key $(whoami)@"$region".$Domain rm $Root/comp/*.txt &> /dev/null
                ssh -i $Key $(whoami)@"$region".$Domain rm $Root/portal/tld* &> /dev/null
                ssh -i $Key $(whoami)@"$region".$Domain rm $Root/portal/comp* &> /dev/null
                ssh -i $Key $(whoami)@"$region".$Domain sudo rm -Rf $Root/tld/sitespeed-result &> /dev/null
                ssh -i $Key $(whoami)@"$region".$Domain sudo rm -Rf $Root/comp/sitespeed-result &> /dev/null
                ssh -i $Key $(whoami)@"$region".$Domain sudo rm -Rf $Root/portal/images &> /dev/null
                chkresult
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
            if [ ! -f $Root/seeds/$3.txt ]; then
               echo -e "\n$3.txt does not exist\n"
               exit 1
            fi
            All="$Google $Servers"
            for region in $All
              do
                echo -n "Starting "$region" ... "
                scp -q -i $Key $Root/seeds/$3.txt $(whoami)@"$region".$Domain:$Root/$2
                chkresult
              done
            exit 0
            ;;
            
  storage ) echo ""
            for region in $Servers
              do
                echo "Checking "$region" ... "
                ssh -i $Key $(whoami)@"$region".$Domain du -sh $Root/portal
                ssh -i $Key $(whoami)@"$region".$Domain du -sh $Root/tld
                ssh -i $Key $(whoami)@"$region".$Domain du -sh $Root/comp
                echo ""
              done
            exit 0
            ;;
     
   update ) All="$Google $Servers"
            for region in $All
              do
                echo -n "Updating "$region" ... "
                ssh -i $Key $(whoami)@"$region".$Domain sudo yum -y update &> /dev/null
                chkresult
              done
            exit 0
            ;;
            
esac
