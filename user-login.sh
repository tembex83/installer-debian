#!/bin/bash
# Script by Tembex AN - 085749237043


data=( `ps aux | grep -i dropbear | awk '{print $2}'`);

echo "===========User Login============";
echo "=================================";

for PID in "${data[@]}"
do
    #echo "check $PID";
    NUM=`cat /var/log/secure | grep -i dropbear | grep -i "Password auth succeeded" | grep "dropbear\[$PID\]" | wc -l`;
    USER=`cat /var/log/secure | grep -i dropbear | grep -i "Password auth succeeded" | grep "dropbear\[$PID\]" | awk '{print $10}'`;
    IP=`cat /var/log/secure | grep -i dropbear | grep -i "Password auth succeeded" | grep "dropbear\[$PID\]" | awk '{print $12}'`;
    if [ $NUM -eq 1 ]; then
        echo "$PID - $USER - $IP";
    fi
done
echo "_________________________________";

data=( `ps aux | grep "\[priv\]" | sort -k 72 | awk '{print $2}'`);


for PID in "${data[@]}"
do
        #echo "check $PID";
        NUM=`cat /var/log/secure | grep -i sshd | grep -i "Accepted password for" | grep "sshd\[$PID\]" | wc -l`;
        USER=`cat /var/log/secure | grep -i sshd | grep -i "Accepted password for" | grep "sshd\[$PID\]" | awk '{print $9}'`;
        IP=`cat /var/log/secure | grep -i sshd | grep -i "Accepted password for" | grep "sshd\[$PID\]" | awk '{print $11}'`;
        if [ $NUM -eq 1 ]; then
                echo "$PID - $USER - $IP";
        fi
done
echo "=================================="
echo -e "Created by \e[1;33;44m TEMBEX \e[0m"