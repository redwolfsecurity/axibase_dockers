#!/bin/bash

password="$RANDOM-$RANDOM-$RANDOM"
echo $password | tee /opt/$ftpuser-password

echo "$ftpuser:$password" | chpasswd

echo "y" | ssh-keygen -q -f /etc/ssh/ssh_host_rsa_key -N '' -t rsa
echo "y" | ssh-keygen -q -f /etc/ssh/ssh_host_dsa_key -N '' -t dsa
echo "y" | ssh-keygen -q -f /etc/ssh/ssh_host_ecdsa_key -N '' -t ecdsa
echo "y" | ssh-keygen -q -f /etc/ssh/ssh_host_ed25519_key -N '' -t ed25519
/usr/sbin/sshd -D

