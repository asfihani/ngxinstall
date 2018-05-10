#!/bin/sh
# set smartindent tabstop=4 shiftwidth=4 expandtab
# ngxinstall-installer.sh
# Copyright 2018 ServerPartners - http://svrpnr.net
# Simple script to install nginx with Wordpress and WP Super Cache plugin.
# User is jailed using chroot setup to improve security.
# Comments, bugs, and improvement: asfik@svrpnr.net

log=/root/ngxinstall-installer.log

RED="$(tput setaf 1)"
GREEN="$(tput setaf 2)"
YELLOW="$(tput setaf 3)"
CYAN="$(tput setaf 6)"
NORMAL="$(tput sgr0)"

# disable selinux
/sbin/setenforce 0
sed -i 's/^SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux

# install necessary packages
printf "${GREEN}▣▣ installing packages...${NORMAL}" 
yum -y install epel-release > $log 2>&1
yum -y install git wget vim-enhanced curl yum-utils gcc make unzip lsof telnet bind-utils postfix certbot shadow-utils >> $log 2>&1
yum -y install http://rpms.remirepo.net/enterprise/remi-release-7.rpm >> $log 2>&1
printf "${CYAN}done.${NORMAL}\n"

# download config files from git repository
printf "${GREEN}▣▣ cloning config files from git repository...${NORMAL}"
mkdir -p /root/tmp >> $log
cd /root/tmp 
rm -rf ngxinstall
printf "${GREEN}▣▣ downloading files from git repo...${NORMAL}" >> $log
git clone https://github.com/asfihani/ngxinstall.git >> $log 2>&1
printf "${CYAN}done.${NORMAL}\n"

# setup jailkit and account
printf "${GREEN}▣▣ installing jailkit...${NORMAL}"
cd /root/tmp
rm -rf jailkit-2.19.tar.gz jailkit-2.19
wget http://olivier.sessink.nl/jailkit/jailkit-2.19.tar.gz  >> $log 2>&1
tar -xzf jailkit-2.19.tar.gz  >> $log 2>&1
cd jailkit-2.19 >> $log
./configure  >> $log 2>&1
make  >> $log 2>&1
make install  >> $log 2>&1
cat >> /etc/jailkit/jk_init.ini <<'EOF'
[basicid]
comment = basic id command
paths_w_setuid = /usr/bin/id
EOF
printf "${CYAN}done.${NORMAL}\n"

printf "${GREEN}▣▣ configure account...${NORMAL}\n"
read -p "Enter domainname : " DOMAINNAME
read -p "Enter username   : " USERNAME

mkdir /chroot >> $log 2>&1
PASSWORD=$(</dev/urandom tr -dc '12345!@#$%qwertQWERTasdfgASDFGzxcvbZXCVB' | head -c16; echo "")
adduser ${USERNAME}
echo "${USERNAME}:${PASSWORD}" | chpasswd
mkdir -p /chroot/${USERNAME}
jk_init -j /chroot/${USERNAME} basicshell editors extendedshell netutils ssh sftp scp basicid >> $log 2>&1
jk_jailuser -s /bin/bash -m -j /chroot/${USERNAME} ${USERNAME} >> $log 2>&1
mkdir -p /chroot/${USERNAME}/home/${USERNAME}/{public_html,logs}
echo '<?php phpinfo(); ?>' > /chroot/${USERNAME}/home/${USERNAME}/public_html/info.php 
chown -R ${USERNAME}: /chroot/${USERNAME}/home/${USERNAME}/{public_html,logs}
chmod 755  /chroot/${USERNAME}/home/${USERNAME} /chroot/${USERNAME}/home/${USERNAME}/{public_html,logs}
printf "${CYAN}done.${NORMAL}\n"

printf "${GREEN}▣▣ configure nginx...${NORMAL}"
cp -p /root/tmp/ngxinstall/config/nginx.repo /etc/yum.repos.d/nginx.repo
yum -y install nginx >> $log 2>&1
mv /etc/nginx/nginx.conf{,.orig}
cp -p /root/tmp/ngxinstall/config/nginx.conf /etc/nginx/nginx.conf
mkdir -p /etc/nginx/sites-enabled/ /etc/nginx/conf.d/ >> $log 2>&1
cp -p /root/tmp/ngxinstall/config/vhost.tpl /etc/nginx/sites-enabled/${DOMAINNAME}.conf
sed -i "s/%%domainname%%/${DOMAINNAME}/g" /etc/nginx/sites-enabled/${DOMAINNAME}.conf
sed -i "s/%%username%%/${USERNAME}/g" /etc/nginx/sites-enabled/${DOMAINNAME}.conf
cp -p /root/tmp/ngxinstall/config/wordpress.tpl /etc/nginx/includes.d/wordpress.conf
cp -p /root/tmp/ngxinstall/config/wp_super_cache.tpl /etc/nginx/includes.d/wp_super_cache.conf 
openssl dhparam -dsaparam -out /etc/nginx/dhparam.pem 4096 >> $log 2>&1
systemctl enable nginx >> $log 2>&1
systemctl start nginx >> $log 2>&1
printf "${CYAN}done.${NORMAL}\n"
