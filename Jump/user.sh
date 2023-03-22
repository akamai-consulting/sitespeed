#!/bin/bash

############################################
#                                          #
#               user.sh                    #
#                  v1                      #
#                                          #
############################################

# Set variables
Host=[HOST]
Domain=[DOMAIN]
Servers="[SERVERS]"
Google=[GOOGLE]
Graphite=[GRAPHITE]
Key=/home/$(logname)/.ssh/sitespeed

# Make sure the script runs as root
if [ "$EUID" -ne 0 ]
  then echo -e "\nNeed to run script as root\n"
  exit 1
fi

# Set Username
function setusername {
   User=""   
   until [ "$taken" == "false"  ]
     do
       read -p "Username: " User
       grep -i -q $User /etc/passwd
       if [ "$?" == "0" ]; then
          echo "Name already exists"
          taken=true
         else
          taken=false
       fi
     done
}

# Set Password
function setpassword {
   Pass1=""
   Pass2=""
   until [ "$match" == "true" ]
     do
       read -s -p "Password: " Pass1 && echo
       read -s -p "Enter again: " Pass2 && echo
       if [ "$Pass1" == "$Pass2" ]; then
          match=true
          Password=$Pass1
        else
          match=false
          echo "Passwords do not match"
       fi
   done
}

# Process each option
case $1 in
    add ) setusername
          setpassword
          echo "Creating $User on $Host ..."
          useradd $User
          echo $Password | passwd $User --stdin
          usermod -aG wheel $User
          usermod -aG sitespeed $User
          mkdir /home/$User/.ssh
          tar --warning=none --no-same-owner -C /home/$User/.ssh -xf /sshkeys.tgz *.pub sitespeed
          mv /home/$User/.ssh/jump.pub /home/$User/.ssh/authorized_keys
          chown $User /home/$User/.ssh
          chgrp $User /home/$User/.ssh
          chmod 600 /home/$User/.ssh/authorized_keys
          chown $User /home/$User/.ssh/authorized_keys
          chgrp $User /home/$User/.ssh/authorized_keys
          chmod 600 /home/$User/.ssh/sitespeed
          chown $User /home/$User/.ssh/sitespeed
          chgrp $User /home/$User/.ssh/sitespeed
          sudo -u $User ln -s /usr/local/sitespeed/admin.sh /home/$User/admin.sh
          sudo -u $User ln -s /usr/local/sitespeed/cron/ /home/$User/cron
          sudo -u $User ln -s /usr/local/sitespeed/seeds/ /home/$User/seeds
          echo -e "function jump() {\n  ssh -i /home/$User/.ssh/sitespeed \$1.$Domain\n}\nexport PS1='[$Host \u@\h \W]\$ '" >> /home/$User/.bash_profile
          echo         
          All="$Google $Graphite $Servers"
          for region in $All
            do
              echo "Creating $User on $region ..."
              ssh -i $Key $(logname)@"$region".$Domain sudo useradd $User
              # This is not working properly over SSH
              # ssh -i $Key $(logname)@"$region".$Domain "sudo echo $Password | passwd $User --stdin"
              ssh -i $Key $(logname)@"$region".$Domain sudo usermod -aG wheel $User
              ssh -i $Key $(logname)@"$region".$Domain sudo usermod -aG sitespeed $User
              ssh -i $Key $(logname)@"$region".$Domain sudo mkdir /home/$User/.ssh
              ssh -i $Key $(logname)@"$region".$Domain sudo tar --warning=none --no-same-owner -C /home/$User/.ssh -xf /sshkeys.tgz *.pub sitespeed
              ssh -i $Key $(logname)@"$region".$Domain sudo mv /home/$User/.ssh/jump.pub /home/$User/.ssh/authorized_keys
              ssh -i $Key $(logname)@"$region".$Domain sudo chown -R $User /home/$User/.ssh
              ssh -i $Key $(logname)@"$region".$Domain sudo chgrp -R $User /home/$User/.ssh            
              ssh -i $Key $(logname)@"$region".$Domain sudo chmod 600 /home/$User/.ssh/authorized_keys
              sed -i "/export PATH/a export PS1=\'[$Host \u@\h \W]\$ \'" /home/$User/.bash_profile
              echo
            done
          ;;
          
 delete ) # need to validate username exists
          # chkusername
          exit 0
           ;;
esac
