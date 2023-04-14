#!/bin/bash

############################################
#                                          #
#               user.sh                    #
#                  v22                     #
#                                          #
############################################

# Make sure the script runs as root
if [ "$EUID" -ne 0 ]
  then echo -e "\nNeed to run script as root\n"
  exit 1
fi

# Set variables
Key=/home/$(logname)/.ssh/sitespeed
Root=/usr/local/sitespeed
Domain=$(cat $Root/config/domain)

# Function that checks the results of each primary action
function chkresult {
  if [ $? -eq 0 ]; then
     echo "Success"
    else
     echo "Fail"
  fi
}

# Create new user
function adduser {
   User=""
   Type=""   
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
   until [ "$valid" == "true" ]
     do
       read -p "Access level (Admin or User): " Type
       if [[ "$Type" == "Admin" || "$Type" == "User" ]]; then
          valid=true
       fi
     done     
}

# Delete existing user
function deluser {
   Admin=$(grep Admin $Root/config/users | awk -F '-' '{print $1}')
   User=""
   until [ "$valid" == "true"  ]
     do
       read -p "Username: " User
       if [ "$User" == "$(logname)" ]; then
          echo "Cannot delete yourself"
        elif [ "$User" == "$Admin" ]; then
          echo "Cannot delete the Admin user"
        else
          grep -i -q $User /etc/passwd
          if [ "$?" == "1" ]; then
             echo "$User does not exist"
             valid=false
            else
             valid=true
          fi
       fi   
     done
}

# Read servers and set Servers variable
Servers=""
end=$(cat $Root/config/servers | wc -l)
exec 3<$Root/config/servers
read data <&3
for (( index=1; index <= $end; index+=1 ))
  do
    Servers="$Servers$data "
    read data <&3
  done

# Process each option
All="google graphite $Servers"
case $1 in
    add ) adduser
          # Create user on Jump server
          echo -n "Creating $User on Jump ... "
          useradd $User
          echo $User-$Type >> $Root/config/users
          usermod -aG wheel $User
          usermod -aG sitespeed $User
          mkdir /home/$User/.ssh
          tar --warning=none --no-same-owner -C /home/$User/.ssh -xf /sshkeys.tgz jump.pub sitespeed
          mv /home/$User/.ssh/jump.pub /home/$User/.ssh/authorized_keys
          chown $User /home/$User/.ssh
          chgrp $User /home/$User/.ssh
          chmod 600 /home/$User/.ssh/authorized_keys
          chown $User /home/$User/.ssh/authorized_keys
          chgrp $User /home/$User/.ssh/authorized_keys
          chmod 600 /home/$User/.ssh/sitespeed
          chown $User /home/$User/.ssh/sitespeed
          chgrp $User /home/$User/.ssh/sitespeed
          sudo cp /home/$(logname)/.ssh/known_hosts /home/$User/.ssh/known_hosts
          sudo chown $User /home/$User/.ssh/known_hosts
          sudo chgrp $User /home/$User/.ssh/known_hosts
          sudo chmod 644 /home/$User/.ssh/known_hosts
          sudo -u $User ln -s $Root/admin.sh /home/$User/admin.sh
          sudo -u $User ln -s $Root/cron/ /home/$User/cron
          sudo -u $User ln -s $Root/seeds/ /home/$User/seeds
          echo -e "function jump() {\n  ssh -i /home/$User/.ssh/sitespeed \$1.$Domain\n}\nexport PS1='[Jump \u@\h \W]\$ '" >> /home/$User/.bash_profile
          chkresult         
          for region in $All
            do
              # Create users on remote servers
              echo -n "Creating $User on $region ... "
              ssh -i $Key $(logname)@$region.$Domain sudo useradd $User &> /dev/null
              ssh -i $Key $(logname)@$region.$Domain sudo usermod -aG wheel $User &> /dev/null
              ssh -i $Key $(logname)@$region.$Domain sudo usermod -aG sitespeed $User &> /dev/null
              ssh -i $Key $(logname)@$region.$Domain sudo usermod -aG docker $User &> /dev/null
              ssh -i $Key $(logname)@$region.$Domain sudo mkdir /home/$User/.ssh &> /dev/null
              ssh -i $Key $(logname)@$region.$Domain sudo tar --warning=none --no-same-owner -C /home/$User/.ssh -xf /sshkeys.tgz sitespeed.pub &> /dev/null
              ssh -i $Key $(logname)@$region.$Domain sudo mv /home/$User/.ssh/sitespeed.pub /home/$User/.ssh/authorized_keys &> /dev/null
              ssh -i $Key $(logname)@$region.$Domain sudo chown -R $User /home/$User/.ssh &> /dev/null
              ssh -i $Key $(logname)@$region.$Domain sudo chgrp -R $User /home/$User/.ssh &> /dev/null           
              ssh -i $Key $(logname)@$region.$Domain sudo chmod 600 /home/$User/.ssh/authorized_keys &> /dev/null
              sudo -u $User ssh -i /home/$User/.ssh/sitespeed $User@$region.$Domain "echo "export PS1=\\\'[$region \\\\u@\\\\h \\\\W]\$ \\\'"  >> /home/$User/.bash_profile" &> /dev/null
              chkresult
            done
            exit 0
          ;;
          
 delete ) deluser
          # Delete user on Jump server
          echo -n "Deleting $User on Jump ... "
          userdel -r $User
          chkresult
          sed -i "/$User/d" $Root/config/users
          # Delete user on remote servers
          for region in $All
            do
              echo -n "Deleting $User on $region ... "
              ssh -i $Key $(logname)@$region.$Domain sudo userdel -r $User &> /dev/null
              chkresult
            done  
          exit 0
          ;;
esac
