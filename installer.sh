#!/bin/sh
# set smartindent tabstop=4 shiftwidth=4 expandtab
# ngxinstall-installer.sh
# Copyright 2018 ServerPartners - http://svrpnr.net
# Simple script to install nginx with Wordpress and WP Super Cache plugin.
# User is jailed using chroot setup to improve security.
# Comments, bugs, and improvement: asfik@svrpnr.net

log=/root/ngxinstall-installer.log

RED="$(tput setaf 1)"
YELLOW="$(tput setaf 3)"
CYAN="$(tput setaf 6)"
NORMAL="$(tput sgr0)"

# install necessary packages
echo "${YELLOW}Installing packages..."
yum -y install epel-release > $log
yum -y install git wget vim curl epel-release yum-utils gcc make unzip lsof telnet bind-utils postfix certbot >> $log
yum -y install http://rpms.remirepo.net/enterprise/remi-release-7.rpm >> $log

# download config files from git
git clone 
## CHROOT
echo
echo "$(tput setab 7; tput setaf 1)(2) Installing jailkit & setup account...$(tput sgr 0)"
cd /tmp
wget -q http://olivier.sessink.nl/jailkit/jailkit-2.19.tar.gz
tar -xzf jailkit-2.19.tar.gz 
cd jailkit-2.19
./configure > /dev/null
make  > /dev/null 2>&1
make install  > /dev/null 2>&1
cat >> /etc/jailkit/jk_init.ini <<'EOF'
[basicid]
comment = basic id command
paths_w_setuid = /usr/bin/id
EOF

## Account Setup
read -p "Enter user name   : " username
read -p "Enter domain name : " domainname

mkdir /chroot
pass=$(</dev/urandom tr -dc '12345!@#$%qwertQWERTasdfgASDFGzxcvbZXCVB' | head -c16; echo "")
adduser ${username}
echo "${username}:${pass}" | chpasswd
mkdir -p /chroot/${username}
jk_init -j /chroot/${username} basicshell editors extendedshell netutils ssh sftp scp basicid > /dev/null
jk_jailuser -s /bin/bash -m -j /chroot/${username} ${username} > /dev/null
mkdir -p /chroot/${username}/home/${username}/{public_html,logs}
echo "${domainname}" > /chroot/${username}/home/${username}/public_html/index.html
echo '<?php phpinfo(); ?>' > /chroot/${username}/home/${username}/public_html/info.php 
chown -R ${username}:${username} /chroot/${username}/home/${username}/{public_html,logs}
chmod 755  /chroot/${username}/home/${username} /chroot/${username}/home/${username}/{public_html,logs}

## NGINX
echo "$(tput setab 7; tput setaf 1)(3) Configuring nginx...$(tput sgr 0)"
yum -y install nginx
mv /etc/nginx/nginx.conf{,.bak}
wget -q -O /etc/nginx/nginx.conf ${base_repo}/nginx/nginx.conf
mkdir -p /etc/nginx/sites-enabled/ /etc/nginx/global/
wget -q -O /etc/nginx/sites-enabled/${domainname}.conf ${base_repo}/nginx/vhost.tpl
sed -i "s/%%domainname%%/${domainname}/g" /etc/nginx/sites-enabled/${domainname}.conf
sed -i "s/%%username%%/${username}/g" /etc/nginx/sites-enabled/${domainname}.conf
wget -q -O /etc/nginx/global/wordpress.conf ${base_repo}/nginx/wordpress.conf
wget -q -O /etc/nginx/global/wp_super_cache.conf ${base_repo}/nginx/wp_super_cache.conf
openssl dhparam -dsaparam -out /etc/nginx/dhparam.pem 4096
systemctl enable nginx
systemctl start nginx

## PHP FPM ##
echo "$(tput setab 7; tput setaf 1)(4) Configuring PHP...$(tput sgr 0)"
echo "Select PHP version:
1) 5.4
2) 5.5 
3) 5.6 
4) 7.0
5) 7.1
6) 7.2
"
read n
case $n in
    1) yum-config-manager --enable remi-php54;;
    2) yum-config-manager --enable remi-php55;;
    3) yum-config-manager --enable remi-php56;;
    4) yum-config-manager --enable remi-php70;;
    5) yum-config-manager --enable remi-php71;;
    6) yum-config-manager --enable remi-php72;;
    *) invalid option;;
esac

yum -y install php php-mysqlnd php-curl php-simplexml \
php-devel php-gd php-json php-mcrypt php-mbstring php-opcache php-pear \
php-pecl-apcu php-pecl-geoip php-pecl-json-post php-pecl-memcache php-pecl-xmldiff \
php-pecl-zip php-pspell php-soap php-tidy php-xml php-xmlrpc php-fpm

sed -i 's/^max_execution_time =.*/max_execution_time = 300/g' /etc/php.ini
sed -i 's/^memory_limit =.*/memory_limit = 256M/g' /etc/php.ini
sed -i 's/^upload_max_filesize =.*/upload_max_filesize = 64M/g' /etc/php.ini
sed -i 's/^post_max_size =.*/post_max_size = 64M/g' /etc/php.ini

mv /etc/php-fpm.d/www.conf /etc/php-fpm.d/www.conf.orig
touch /etc/php-fpm.d/www.conf

wget -q -O /etc/php-fpm.d/${domainname}.conf ${base_repo}/nginx/php-fpm.tpl
sed -i "s/%%domainname%%/${domainname}/g" /etc/php-fpm.d/${domainname}.conf
sed -i "s/%%username%%/${username}/g" /etc/php-fpm.d/${domainname}.conf

systemctl enable php-fpm
systemctl start php-fpm

## MARIADB ##
echo "$(tput setab 7; tput setaf 1)(5) Configuring MariaDB...$(tput sgr 0)"
wget -q -O /etc/yum.repos.d/mariadb.repo ${base_repo}/nginx/mariadb.repo
yum -y install MariaDB-server MariaDB-client MariaDB-compat MariaDB-shared
systemctl enable mariadb
systemctl start mariadb

mysql_pass=$(pwgen -s -N 1 -cn 14)
mysqladmin -u root password "${mysql_pass}"
mysql -u root -p"${mysql_pass}" -e "UPDATE mysql.user SET Password=PASSWORD('${mysql_pass}') WHERE User='root'"
mysql -u root -p"${mysql_pass}" -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1')"
mysql -u root -p"${mysql_pass}" -e "DELETE FROM mysql.user WHERE User=''"
mysql -u root -p"${mysql_pass}" -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%'"
mysql -u root -p"${mysql_pass}" -e "FLUSH PRIVILEGES"

cat > ~/.my.cnf <<EOF
[client]
password = '${mysql_pass}'
EOF

wp_pass=$(pwgen -s -N 1 -cn 14)
cat > /tmp/create.sql <<EOF
create database ${username}_wp;
grant all privileges on ${username}_wp.* to ${username}_wp@localhost identified by '${wp_pass}';
flush privileges;
EOF
mysql < /tmp/create.sql 
rm -rf /tmp/create.sql

## MARIADB ##
echo "$(tput setab 7; tput setaf 1)(6) Installing WPCLI...$(tput sgr 0)"
wget -q https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod 755 wp-cli.phar
mv wp-cli.phar /usr/local/bin/wp

## END
echo -e "user: ${username}\npass: ${pass}"
echo -e "db username: ${username}_wp\ndb pass: ${wp_pass}"

