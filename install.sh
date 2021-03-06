#!/bin/bash

apt update
apt install -y ubuntu-drivers-common apache2-utils nginx ocl-icd-opencl-dev

export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

ubuntu-drivers devices
ubuntu-drivers autoinstall

# defaults
USER="anonymous"
ADMINUSER="admin"
PASSKEY=""
TEAM="0"
PASSWORD="password1"

for i in "$@"
do
	case $i in
			--user=*)
			USER="${i#*=}"
			;;
			--passkey=*)
			PASSKEY="${i#*=}"
			;;
			--team=*)
			TEAM="${i#*=}"
			;;
			--password=*)
			PASSWORD="${i#*=}"
			;;
			--adminuser=*)
			ADMINUSER="${i#*=}"
			;;
			*)
			;;
	esac
done

echo "fahclient       fahclient/user  string  $USER
fahclient       fahclient/autostart     boolean true
fahclient       fahclient/power select  full
fahclient       fahclient/passkey       string $PASSKEY
fahclient       fahclient/team  string  $TEAM" > ~/conf.txt

debconf-set-selections ~/conf.txt

mkdir -p /etc/fahclient/

anon='false'
if [ "$USER" = "anonymous" ]; then
    anon='true'
fi

echo "<config>
  <user value='$USER'/>
  <team value='$TEAM'/>
  <passkey value='$PASSKEY'/>
  <power value='full'/>
  <gpu value='true'/>
  <fold-anon value='$anon'/>
  <allow>127.0.0.1 0.0.0.0/0</allow>
  <web-allow>127.0.0.1 0.0.0.0/0</web-allow>
  <password>$PASSWORD</password>
</config>
" > /etc/fahclient/config.xml

wget https://download.foldingathome.org/releases/public/release/fahclient/debian-stable-64bit/v7.6/latest.deb

dpkg -i --force-depends latest.deb

openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 -subj "/C=US/ST=WA/L=REDMOND/O=Dis/CN=www.example.com" -keyout /etc/nginx/fah.key  -out /etc/nginx/fah.cert

htpasswd -b -c /etc/nginx/.htpasswd $ADMINUSER $PASSWORD

echo "server {
	listen              443 ssl;
	server_name         www.example.com;
	keepalive_timeout   70;

	ssl_certificate     /etc/nginx/fah.cert;
	ssl_certificate_key /etc/nginx/fah.key;
	ssl_protocols       TLSv1 TLSv1.1 TLSv1.2;
	ssl_ciphers         HIGH:!aNULL:!MD5;

	location / {
		proxy_pass http://localhost:7396;
		auth_basic 'Administrators Area';
		auth_basic_user_file /etc/nginx/.htpasswd;
	}
}
" > /etc/nginx/sites-available/default

systemctl restart nginx

