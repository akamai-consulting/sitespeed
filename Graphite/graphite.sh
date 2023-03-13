#!/bin/bash

#########################################
#                                       #
#             graphite.sh               #
#                  v 5                  #
#                                       #
#########################################

# Set variables
Green='\033[0;32m'
NoColor='\033[0m'
Options="start stop status"

# Print help
if [[ "$1" == "--help" || "$1" == "-h" || "$1" == "/?" || $# -eq 0 ]]; then
   echo -e "\n${Green}USAGE${NoColor} graphite arg1\n"               
   echo -e "${Green}DESCRIPTION${NoColor} Controls the stopping and starting of the Graphite Docker container\n"
   
   echo -e "The following options for arg1 are available:\n"
   
   echo -e "\t${Green}start${NoColor}\t   Starts the Graphite Docker container\n"
   
   echo -e "\t${Green}stop${NoColor}\t   Stops the Docker Graphite Docker container\n"
   
   echo -e "\t${Green}status${NoColor}\t   Displays the curent status of the Graphite Docker container\n"
   exit 0
fi

# Check for the correct number of arguments
if [ $# -ne 1 ]; then
   echo -e "\ngraphite only takes 1 argument\n"
   exit 1
fi

# Check the correct test type has been entered
echo $Options | tr ' ' '\n' | grep -F -x -q $1
if [ $? -ne 0 ]; then 
   echo -e "\narg1 must be start|stop|status\n"
   exit 1
fi

# Check the current running status
docker container ls | grep graphite > /dev/null
if [ $? -eq 0 ]; then
   status=up
 else
   status=down
fi

case $1 in
    start ) if [ "$status" == "down" ]; then
               docker run -d \
               --name graphite \
               --restart=always \
               -e TZ=[TIMEZONE] \
               -v /usr/local/graphite/graphite-conf:/opt/graphite/conf \
               -v /usr/local/graphite/graphite-storage:/opt/graphite/storage \
               -v /usr/local/graphite/log:/var/log \
               -p 8888:80 \
               -p 2003-2004:2003-2004 \
               graphiteapp/graphite-statsd:1.1.8-8
               if [ $? -eq 0 ]; then
                  echo -e "\n${Green}Graphite Docker container successfully started${NoColor}\n"
               fi
               sleep 3
             else
                  echo -e "\n${Green}Graphite Docker container is already running${NoColor}\n"
            fi
            exit 0
            ;;
     stop ) if [ "$status" == "up" ]; then
               docker container stop graphite > /dev/null && docker container rm graphite > /dev/null && echo -e "\n${Green}Graphite Docker container successfully stopped${NoColor}\n"
             else
               echo -e "\n${Green}Graphite Docker container is already stopped${NoColor}\n"
            fi
            exit 0
            ;;
   status ) if [ "$status" == "down" ]; then
               echo -e "\n${Green}Graphite Docker container is not running${NoColor}\n" 
             else
               docker container ls
            fi
            exit 0
            ;;
esac
