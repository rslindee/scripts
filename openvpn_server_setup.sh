#!/bin/sh
su
pacman -S easy-rsa
cd /etc/easy-rsa
export EASYRSA=$(pwd)
# comment out the first line "RANDFILE..." of openssl-easyrsa.cnf since it seems to cause issues
easyrsa init-pki
easyrsa build-ca
# open up tomoato
# Under "Keys" paste the ca.crt key into the "Certificate Authority" box and click "Generate keys"
# click "Generate DH params" (this took several minutes!)
# Under "Advanced" check "Direct clients to redirect internet traffic"
# click "start server"
# 
# Under "Keys" click "Generate client config" (I had to extract the .tgz w/ dtrx for some reason)
# the generated "connection.ovpn" file @ line 12 needed a space between the number in "verb3"
