#!/bin/bash

############################################
#                                          #
#                admin.sh                  #
#                 v 44                     #
#                                          #
############################################

# Set variables
Green='\033[0;32m'
NoColor='\033[0m'
Options="all update docker seed reset cron logs cert graphite grafana storage core user server"
Domain=[DOMAIN]
Key=$HOME/.ssh/sitespeed
Root=/usr/local/sitespeed
successCnt=0
failureCnt=0
failure=""

# Function that reads servers and sets Servers variable
function popservers {
  Servers=""
  end=$(cat $Root/config/servers | wc -l)
  exec 3<$Root/config/servers
  read data <&3
  for (( index=1; index <= $end; index+=1 ))
    do
      Servers="$Servers$data "
      read data <&3
    done
}

# Function that reads users and sets Users variable
function popusers {
  Users=""
  end=$(cat $Root/config/users | wc -l)
  exec 3<$Root/config/users
  read data <&3
  for (( index=1; index <= $end; index+=1 ))
    do
      Users="$Users$data "
      read data <&3
    done
}

# Invoke popserver function immediately to populate Servers variable
popservers

# Function that gets the name of new server
function servername {
  case $1 in
      add ) until [ "$exists" == "false" ]
              do
                read -p "Server name to add: " Server
                chkname "$Server"
                if [ "$exists" == "true" ]; then
                   echo "$Server already exists"
                fi
              done
            ;;

   delete ) until [ "$exists" == "true" ]
              do
                read -p "Server name to delete: " Server
                chkname "$Server" "delete"
                if [ "$exists" == "false" ]; then
                   echo "$Server does not exist"
                fi
              done
            ;;
  esac     
}

# Function that checks for the existence of server name
function chkname {
  for name in $Servers
   do
    if [ "$(echo $name | tr [:upper:] [:lower:])" == "$(echo $1 | tr [:upper:] [:lower:])" ]; then
       exists=true
       if [ "$2" == "delete" ]; then
          Server=$name
       fi
       break
     else
       exists=false
    fi
   done
}

# Function that modifies index.html
function modifyindex {
  sortedSERVERS=$(echo $Servers | xargs -n 1 | sort | xargs)
  count=$(echo $sortedSERVERS | wc -w)
  line=1
  for (( index=0; index < count ; index+=1 ))
    do
      Region=$(echo $sortedSERVERS | awk -v var=$line '{print $var}')
      echo "     <option value=\"http://$Region.$Domain/\">$Region</option>" >> $Root/foo
      let "line++"
    done
  sudo sed -E -i "/option value.+$Domain/d" $Root/portal/index.html
  sudo sed -i "/<!-- ServerDropDown -->/r $Root/foo" $Root/portal/index.html
  rm $Root/foo
}

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
   echo -e "\n${Green}USAGE${NoColor} admin command [arg1 arg2]\n"               
   echo -e "${Green}DESCRIPTION${NoColor} Automates the distribution files and execution of scripts across servers\n"
   
   echo -e "The following commands are available:\n"
   
   echo -e "\t${Green}all${NoColor}\t   Copies customized files across servers\n"
   
   echo -e "\t${Green}cert${NoColor}\t   Checks the certificate renewal date on servers\n"
   
   echo -e "\t${Green}core${NoColor}\t   Checks for core files on servers. Requires:"
   echo -e "\t\t   ${Green}arg1${NoColor} = check|delete\n"

   echo -e "\t${Green}cron${NoColor}\t   Schedules cron jobs on servers. Requires:"
   echo -e "\t\t   ${Green}arg1${NoColor} = check|update|delete\n"
   
   echo -e "\t${Green}docker${NoColor}\t   Performs various docker functions on servers. Requires:"
   echo -e "\t\t   ${Green}arg1${NoColor} = check|clean\n"
   
   echo -e "\t${Green}grafana${NoColor}    Updates Grafana to the latest version. Requires:"
   echo -e "\t\t   ${Green}arg1${NoColor} = update|provision\n"

   echo -e "\t${Green}graphite${NoColor}   Manages the size of graphite.db. Requires:"
   echo -e "\t\t   ${Green}arg1${NoColor} = check|reduce\n"
   
   echo -e "\t${Green}logs${NoColor}\t   Checks for errors on servers. Requires:"
   echo -e "\t\t   ${Green}arg1${NoColor} = check|delete\n"
   
   echo -e "\t${Green}reset${NoColor}\t   Deletes Sitespeed data on servers\n"
   
   echo -e "\t${Green}seed${NoColor}\t   Manages the seed files on servers. Requires:"
   echo -e "\t\t   ${Green}arg1${NoColor} = tld|comp|delete"
   echo -e "\t\t   ${Green}arg2${NoColor} = seed file\n"
   
   echo -e "\t${Green}server${NoColor}     Adds and removes servers. Requires:"
   echo -e "\t\t   ${Green}arg1${NoColor} = add|delete|names\n"
    
   echo -e "\t${Green}storage${NoColor}\t   Checks the amount of storage used on servers\n"
   
   echo -e "\t${Green}update${NoColor}\t   Updates packages on all servers\n"
   
   echo -e "\t${Green}user${NoColor}\t   Manages user accounts on servers. Requires:"
   echo -e "\t\t   ${Green}arg1${NoColor} = add|delete|names\n"
  
   exit 0
fi

# Make sure the user has a known_hosts file
if [ ! -f $HOME/.ssh/known_hosts ]; then
   echo -e "\nCreating an SSH known_hosts file"
   All="$Servers google graphite"
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
   scp -q -i $Key $(whoami)@google.$Domain:$Root/google.sh $Root/google/
   echo ""
   for region in $Servers
    do
     echo "Updating index.html on "$region" ... "
     scp -q -i $Key $Root/portal/index.html $(whoami)@"$region".$Domain:$Root/portal/
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
      all ) echo -n "Updating Google ... "
            scp -q -i $Key $Root/google/google.sh $(whoami)@google.$Domain:$Root
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
 
     cert ) echo -e "\nChecking Graphite ... "
            ssh -i $Key $(whoami)@graphite.$Domain sudo certbot certificates 
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
            All="google $Servers"
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
                           echo -e "\nDisplaying Jump ... "
                           grep -v -e '^$' cron/crontab
                           rm cron/crontab
                       else
                           echo -e "\nDisplaying Jump ... no entry exists"
                           rm cron/crontab
                       fi
                       ;;
              update ) echo -n "Updating Jump ... "
                       sudo -u sitespeed crontab /home/sitespeed/jumpcron &> /dev/null
                       chkresult
                       ;;
              delete ) echo -n "Updating Jump ... "
                       sudo -u sitespeed crontab -r &> /dev/null
                       crondelete                
                       ;;
            esac
            All="google $Servers"
            for region in $All
              do
                case $2 in
                 check ) ssh -i $Key $(whoami)@"$region".$Domain sudo -u sitespeed crontab -l &> cron/crontab
                         cronlist
                         ;;
                update ) echo -n "Updating "$region" ... "
                         if [ "$region" == "google" ]; then
                             sed 's/XXX/'$region'/' cron/psicron.UPD > cron/psicron.REG
                             echo "" >> cron/psicron.REG                  
                             scp -q -i $Key cron/psicron.REG $(whoami)@"$region".$Domain:crondata
                             ssh -i $Key $(whoami)@"$region".$Domain sudo mv crondata /home/sitespeed/
                             ssh -i $Key $(whoami)@"$region".$Domain sudo chown sitespeed /home/sitespeed/crondata                         
                             ssh -i $Key $(whoami)@"$region".$Domain sudo -u sitespeed crontab /home/sitespeed/crondata &> /dev/null
                             ssh -q -i $Key $(whoami)@"$region".$Domain sudo rm /home/sitespeed/crondata
                           else
                             sed 's/XXX/'$region'/' cron/sitecron.UPD > cron/sitecron.REG
                             echo "" >> cron/sitecron.REG                       
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
            All="google $Servers"
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
                    update ) echo -n "Updating Graphite ... "
                             ssh -q -i $Key $(whoami)@graphite.$Domain sudo yum -y update grafana-enterprise &> /dev/null
                             ssh -q -i $Key $(whoami)@graphite.$Domain sudo systemctl restart grafana-server &> /dev/null
                             chkresult
                             ;;
                 provision ) echo -n "Provisioning new Grafana dashboards ... "            
                             ssh -q -i $Key $(whoami)@graphite.$Domain sudo /usr/local/graphite/provision.sh update
                             ssh -q -i $Key $(whoami)@graphite.$Domain sudo mv -f /provision.sh /usr/local/graphite/provision.sh
                             ssh -q -i $Key $(whoami)@graphite.$Domain sudo chmod 755 /usr/local/graphite/provision.sh
                             ssh -q -i $Key $(whoami)@graphite.$Domain sudo /usr/local/graphite/provision.sh
                             chkresult
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
                  check ) echo "Checking graphite.db on Graphite ... "
                          ssh -i $Key $(whoami)@graphite.$Domain du -sh /usr/local/graphite/graphite-storage/graphite.db
                          ;;
                 reduce ) echo -n "Reducing graphite.db on Graphite ... "
                          ssh -q -i $Key $(whoami)@graphite.$Domain sudo /usr/local/graphite/sqlite.sh
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
            All="google $Servers"
            for region in $All
              do
                case $2 in
                  check ) ssh -i $Key $(whoami)@"$region".$Domain ls $Root/logs/tld.*.msg.log &> /dev/null
                          if [ $? -eq 0 ]; then
                             tldErrorCnt=$(ssh -q -i $Key $(whoami)@"$region".$Domain grep -i error $Root/logs/tld.*.msg.log | wc -l)
                            else
                              tldErrorCnt="n/a"
                          fi
                          ssh -i $Key $(whoami)@"$region".$Domain ls $Root/logs/comp.*.msg.log &> /dev/null
                          if [ $? -eq 0 ]; then
                             compErrorCnt=$(ssh -q -i $Key $(whoami)@"$region".$Domain grep -i error $Root/logs/comp.*.msg.log | wc -l)
                            else
                              compErrorCnt="n/a"
                          fi
                          echo ""$region" errors: tld=$tldErrorCnt comp=$compErrorCnt"
                          ;;
                 delete ) echo -n "Starting "$region" ... "
                          ssh -i $Key $(whoami)@"$region".$Domain "rm $Root/logs/*log" &> /dev/null
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
            echo "tld comp delete" | tr ' ' '\n' | grep -F -x -q $2
            if [ $? -eq 1 ]; then
               echo -e "\narg2 must be tld|comp|delete\n"
               exit 1
            fi
            if [ ! -f $Root/seeds/$3.txt ]; then
               echo -e "\n$3.txt does not exist\n"
               exit 1
            fi
            All="google $Servers"
            for region in $All
              do
                echo -n "Starting "$region" ... "
                if [ "$2" == "delete" ]; then
                   ssh -i $Key $(whoami)@"$region".$Domain "rm $Root/tld/$3.txt || rm $Root/comp/$3.txt" &> /dev/null
                 else
                   scp -q -i $Key $Root/seeds/$3.txt $(whoami)@"$region".$Domain:$Root/$2
                   ssh -i $Key $(whoami)@"$region".$Domain sudo chgrp sitespeed $Root/$2/$3.txt
                fi
                chkresult
              done
            exit 0
            ;;
            
   server ) if [ $# -ne 2 ]; then
               echo -e "\nserver requires 1 argument: add|delete|names\n"
               exit 1
            fi
            echo "add delete names" | tr ' ' '\n' | grep -F -x -q $2
            if [ $? -eq 1 ]; then
               echo -e "\narg2 must be add|delete|names\n"
               exit 1
            fi
            case $2 in
               add ) servername "add"
                     curl $Server.$Domain &> /dev/null
                     if [ $? -ne 0 ]; then
                        echo "$Server must be onlne to continue"
                        exit 1
                       else
                        echo -e "\nUpdating known_hosts with $Server"
                        ssh -i $Key $Server.$Domain ls
                        sudo cp -f $HOME/.ssh/known_hosts /home/sitespeed/.ssh/known_hosts
                        sudo chown sitespeed /home/sitespeed/.ssh/known_hosts
                        sudo chgrp sitespeed /home/sitespeed/.ssh/known_hosts
                        sudo chmod 644 /home/sitespeed/.ssh/known_hosts
                        echo
                        echo $Server >> $Root/config/servers
                        popservers
                        modifyindex
                        for region in $Servers
                          do
                            echo -n "Updating "$region" ... "           
                            scp -q -i $Key $Root/portal/index.html $(whoami)@"$region".$Domain:$Root/portal
                            chkresult
                          done                               
                     fi
                     ;;
                          
            delete ) servername "delete"
                     echo -n "Deleting $Server ..."
                     chkresult
                     sudo sed -i "/$Server/d" $Root/config/servers
                     popservers
                     modifyindex       
                     for region in $Servers
                       do
                         echo -n "Updating "$region" ... "           
                         scp -q -i $Key $Root/portal/index.html $(whoami)@"$region".$Domain:$Root/portal
                         chkresult
                       done                  
                     ;;
             names ) echo "Active servers"
                     echo google
                     echo graphite
                     sortedSERVERS=$(echo $Servers | xargs -n 1 | sort | xargs)
                     for data in $sortedSERVERS
                       do
                         echo $data
                       done
                     ;;
            esac
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
     
   update ) All="google $Servers"
            for region in $All
              do
                echo -n "Updating "$region" ... "
                ssh -i $Key $(whoami)@"$region".$Domain sudo yum -y update &> /dev/null
                chkresult
              done
            exit 0
            ;;
            
     user ) if [ $# -ne 2 ]; then
               echo -e "\nuser requires 1 argument: add|delete|names\n"
               exit 1
            fi
            echo "add delete names" | tr ' ' '\n' | grep -F -x -q $2
            if [ $? -eq 1 ]; then
               echo -e "\narg2 must be add|delete|names\n"
               exit 1
            fi            
            case $2 in
                 add ) sudo $Root/user.sh add
                       ;;
              delete ) sudo $Root/user.sh delete
                       ;;
               names ) popusers        
                       sortedUSERS=$(echo $Users | xargs -n 1 | sort | xargs)
                       echo "Sitespeed users"
                       for data in $sortedUSERS
                         do
                           echo $data
                         done
                       ;;
            esac
            exit 0
            ;;
esac
