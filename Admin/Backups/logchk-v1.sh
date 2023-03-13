#!/bin/bash

# Check that an argument has been passed
if [ $# -ne 1 ]
	then
    	echo -e "\nNeed to pass log name of interest: tld or comp\n"
            exit 1
fi

# Check the correct log name has been entered
if [[ ! "$1" == "tld" && ! "$1" == "comp" ]]
    then 
        echo -e "\nLog name must be either tld or comp\n"
        exit 1
fi

cat /home/greg/logs/$1.run.log | awk '{print $11 " " $4 " " $5 " " $6 " " $1 " " $13}' | sort

