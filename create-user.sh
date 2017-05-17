#!/bin/bash
#Script auto create trial user SSH
#yg akan expired setelah 1 hari
#scriptword-indo 085749237043

read -p "Username : " Login
read -p "Password : " Pass
read -p "Expired (hari): " masaaktif

IP=`dig +short myip.opendns.com @resolver1.opendns.com`
useradd -e `date -d "$masaaktif days" +"%Y-%m-%d"` -s /bin/false -M $Login
exp="$(chage -l $Login | grep "Account expires" | awk -F": " '{print $2}')"
echo -e "$Pass\n$Pass\n"|passwd $Login &> /dev/null
echo -e ""
echo -e "==========[ SSH ]==========="
echo -e "=========[account]=========="
echo -e "[Host: $IP ]" 
echo -e "[Port: 443,143,80 ]"
echo -e "[Username: $Login ]"
echo -e "[Password: $Pass ]"
echo -e "============================"
echo -e "[Expired: $exp]"
echo -e "==========================="
echo -e "Created By \e[1;33;44mTEMBEX\e[0m"