#!/bin/sh
## vim: set expandtab sw=4 ts=4 sts=4:
##
## ngxinstall-installer.sh
##   © Copyright 2018 ServerPartners 
##      http://serverpartners.net
##
## Simple shell script to install nginx with Wordpress, user is jailed 
## using chroot setup to improve security. Send bug report to asfik@svrpnr.net.
##

log=/root/ngxinstall-installer.log

RED="$(tput setaf 1)"
GREEN="$(tput setaf 2)"
YELLOW="$(tput setaf 3)"
CYAN="$(tput setaf 6)"
NORMAL="$(tput sgr0)"

usage () {
    echo
    printf "Usage: %s %s ${NORMAL}--domainname ${GREEN}<domainname>${NORMAL} ${NORMAL}--username ${GREEN}<username>${NORMAL} ${NORMAL}--email ${GREEN}<email>\n" "${CYAN}" $(basename "$0") 
    printf "${NORMAL}"
    echo 
}

if [[ $# -eq 0 || $# -lt 6 ]];then
    usage
    exit 1
fi

while [ "$1" != "" ]; do
  case $1 in
    --help)
    usage
    exit 0
    ;;
    --domainname)
    shift
    DOMAINNAME=$1
    shift
    ;;
    --username)
    shift
    USERNAME=$1
    shift
    ;;
    --email)
    shift
    EMAIL=$1
    shift
    ;;
    *)
    printf "Unrecognized option: $1\n\n"
    usage
    exit 1
    ;;
  esac
done

# disable selinux
/sbin/setenforce 0
sed -i 's/^SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux

# install necessary packages
printf "${GREEN}▣ installing packages...${NORMAL}" 
yum -y install epel-release > $log 2>&1
yum -y install git wget vim-enhanced curl yum-utils gcc make unzip lsof telnet bind-utils postfix certbot shadow-utils sudo >> $log 2>&1
yum -y install http://rpms.remirepo.net/enterprise/remi-release-7.rpm >> $log 2>&1
printf "${CYAN}done ✔${NORMAL}\n"

# download config files from git repository
printf "${GREEN}▣ cloning config files from git repository...${NORMAL}"
cd /tmp 
rm -rf ngxinstall
git clone https://github.com/asfihani/ngxinstall.git >> $log 2>&1
printf "${CYAN}done ✔${NORMAL}\n"

# setup jailkit and account
printf "${GREEN}▣ installing jailkit...${NORMAL}"
cd /tmp
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
printf "${CYAN}done ✔${NORMAL}\n"

# setup chroot for account
printf "${GREEN}▣ configuring account...${NORMAL}"
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
printf "${CYAN}done ✔${NORMAL}\n"

# configure nginx
printf "${GREEN}▣ configuring nginx...${NORMAL}"
cp -p /tmp/ngxinstall/config/nginx.repo /etc/yum.repos.d/nginx.repo
yum -y install nginx >> $log 2>&1
mv /etc/nginx/nginx.conf{,.orig}
cp -p /tmp/ngxinstall/config/nginx.conf /etc/nginx/nginx.conf
mkdir -p /etc/nginx/sites-enabled/ /etc/nginx/conf.d/ >> $log 2>&1
cp -p /tmp/ngxinstall/config/vhost.tpl /etc/nginx/sites-enabled/${DOMAINNAME}.conf
sed -i "s/%%domainname%%/${DOMAINNAME}/g" /etc/nginx/sites-enabled/${DOMAINNAME}.conf
sed -i "s/%%username%%/${USERNAME}/g" /etc/nginx/sites-enabled/${DOMAINNAME}.conf
cp -p /tmp/ngxinstall/config/wordpress.tpl /etc/nginx/conf.d/wordpress.conf
cp -p /tmp/ngxinstall/config/wp_super_cache.tpl /etc/nginx/conf.d/wp_super_cache.conf 
openssl dhparam -dsaparam -out /etc/nginx/dhparam.pem 4096 >> $log 2>&1
systemctl enable nginx >> $log 2>&1
systemctl start nginx >> $log 2>&1
printf "${CYAN}done ✔${NORMAL}\n"

# configure php-fpm
printf "${GREEN}▣ configuring php-fpm...${NORMAL}"
yum-config-manager --enable remi-php72 >> $log 2>&1
yum -y -q install php php-mysqlnd php-curl php-simplexml \
php-devel php-gd php-json php-pecl-mcrypt php-mbstring php-opcache php-pear \
php-pecl-apcu php-pecl-geoip php-pecl-json-post php-pecl-memcache php-pecl-xmldiff \
php-pecl-zip php-pspell php-soap php-tidy php-xml php-xmlrpc php-fpm >> $log 2>&1
sed -i 's/^max_execution_time =.*/max_execution_time = 300/g' /etc/php.ini
sed -i 's/^memory_limit =.*/memory_limit = 256M/g' /etc/php.ini
sed -i 's/^upload_max_filesize =.*/upload_max_filesize = 64M/g' /etc/php.ini
sed -i 's/^post_max_size =.*/post_max_size = 64M/g' /etc/php.ini
sed -i 's/^;opcache.revalidate_freq=2/opcache.revalidate_freq=60/g' /etc/php.d/10-opcache.ini
sed -i 's/^;opcache.fast_shutdown=0/opcache.fast_shutdown=1/g' /etc/php.d/10-opcache.ini
mv /etc/php-fpm.d/www.conf{,.orig}
touch /etc/php-fpm.d/www.conf
cp -p /tmp/ngxinstall/config/php-fpm.tpl /etc/php-fpm.d/${DOMAINNAME}.conf 
sed -i "s/%%domainname%%/${DOMAINNAME}/g" /etc/php-fpm.d/${DOMAINNAME}.conf
sed -i "s/%%username%%/${USERNAME}/g" /etc/php-fpm.d/${DOMAINNAME}.conf
systemctl enable php-fpm >> $log 2>&1
systemctl start php-fpm >> $log 2>&1
printf "${CYAN}done ✔${NORMAL}\n"

# configure MariaDB
printf "${GREEN}▣ configuring MariaDB...${NORMAL}"
cp -p /tmp/ngxinstall/config/mariadb.repo /etc/yum.repos.d/mariadb.repo
yum -y -q install MariaDB-server MariaDB-client MariaDB-compat MariaDB-shared >> $log 2>&1
systemctl enable mariadb >> $log 2>&1
systemctl start mariadb >> $log 2>&1
MYSQL_PASS==$(</dev/urandom tr -dc '12345!@#$%qwertQWERTasdfgASDFGzxcvbZXCVB' | head -c16; echo "")
mysqladmin -u root password "${MYSQL_PASS}"
mysql -u root -p"${MYSQL_PASS}" -e "UPDATE mysql.user SET Password=PASSWORD('${MYSQL_PASS}') WHERE User='root'"
mysql -u root -p"${MYSQL_PASS}" -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1')"
mysql -u root -p"${MYSQL_PASS}" -e "DELETE FROM mysql.user WHERE User=''"
mysql -u root -p"${MYSQL_PASS}" -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%'"
mysql -u root -p"${MYSQL_PASS}" -e "FLUSH PRIVILEGES"

cat > ~/.my.cnf <<EOF
[client]
password = '${MYSQL_PASS}'
EOF
printf "${CYAN}done ✔${NORMAL}\n"

# create MySQL database for Wordpress
printf "${GREEN}▣ configuring Wordpress database...${NORMAL}"
WP_PASS=$(</dev/urandom tr -dc '12345!@#$%qwertQWERTasdfgASDFGzxcvbZXCVB' | head -c16; echo "")
cat > /tmp/create.sql <<EOF
create database ${USERNAME}_wp;
grant all privileges on ${USERNAME}_wp.* to ${USERNAME}_wp@localhost identified by '${WP_PASS}';
flush privileges;
EOF
mysql < /tmp/create.sql 
rm -rf /tmp/create.sql
printf "${CYAN}done ✔${NORMAL}\n"

# installing WPCLI
printf "${GREEN}▣ installing WPCLI...${NORMAL}"
wget https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -O /tmp/wp >> $log 2>&1
chmod 755 /tmp/wp >> $log 2>&1
mv /tmp/wp /usr/local/bin/wp >> $log 2>&1
printf "${CYAN}done ✔${NORMAL}\n"

# install Wordpress
printf "${GREEN}▣ installing Wordpress...${NORMAL}"
cd /chroot/${USERNAME}/home/${USERNAME}/public_html
ADMIN_PASS=$(</dev/urandom tr -dc '12345!@#$%qwertQWERTasdfgASDFGzxcvbZXCVB' | head -c16; echo "")
sudo -u ${USERNAME} bash -c "/usr/local/bin/wp core download" >> $log 2>&1
sudo -u ${USERNAME} bash -c "/usr/local/bin/wp core config --dbname=${USERNAME}_wp --dbuser=${USERNAME}_wp --dbpass=${WP_PASS} --dbhost=localhost --dbprefix=wp_" >> $log 2>&1
sudo -u ${USERNAME} bash -c "/usr/local/bin/wp core install --url=${DOMAINNAME} --title='Just another Wordpress site' --admin_user=${USERNAME} --admin_password=${ADMIN_PASS} --admin_email=${EMAIL}" >> $log 2>&1
sudo -u ${USERNAME} bash -c "/usr/local/bin/wp plugin install really-simple-ssl wp-super-cache" >> $log 2>&1
printf "${CYAN}done ✔${NORMAL}\n"

# Configuring Let's Encrypt
printf "${GREEN}▣ configuring Let's Encrypt...${NORMAL}"

WEB_IP=$(dig +short ${DOMAINNAME})
CURR_IP=$(curl -sSL http://cpanel.com/showip.cgi)

if [ "${WEB_IP}" == "${CURR_IP}" ]; then
    mkdir -p /etc/letsencrypt
    cp -p /tmp/ngxinstall/config/cli.ini /etc/letsencrypt/cli.ini 
    sed -i "s{%%email%%{${EMAIL}{g" /etc/letsencrypt/cli.ini
    
    # check if www record exist
    WWW_IP=$(dig +short www.${DOMAINNAME})
    if [ "${WWW_IP}" == "${CURR_IP}" ]; then
        certbot certonly --webroot -w /chroot/${USERNAME}/home/${USERNAME}/public_html -d ${DOMAINNAME} -d www.${DOMAINNAME} >> $log 2>&1
    else
        certbot certonly --webroot -w /chroot/${USERNAME}/home/${USERNAME}/public_html -d ${DOMAINNAME} >> $log 2>&1
    fi

    sed -i "s{^#{{g" /etc/nginx/sites-enabled/${DOMAINNAME}.conf
    systemctl restart nginx >> $log 2>&1
    echo "0 0,12 * * * /usr/bin/python -c 'import random; import time; time.sleep(random.random() * 3600)' && /usr/bin/certbot renew -q --post-hook 'systemctl restart nginx'" > /tmp/le.cron
    crontab /tmp/le.cron
    rm -rf /tmp/le.cron
    cd /chroot/${USERNAME}/home/${USERNAME}/public_html
    printf "${CYAN}done ✔${NORMAL}\n"
else
    printf "${RED}skipped, IP address probably not pointed to this server ⛔.${NORMAL}\n"
fi

# Configuring Postfix
printf "${GREEN}▣ configuring Postfix...${NORMAL}"
rpm -e --nodeps sendmail* >> $log 2>&1
yum -y install postfix >> $log 2>&1
systemctl enable postfix >> $log 2>&1
systemctl start postfix >> $log 2>&1
printf "${CYAN}done ✔${NORMAL}\n"

# print all details
echo
printf "===========================================================================\n"
printf "SFTP\n"
printf "Domain name : ${DOMAINNAME}\n"
printf "Username    : ${USERNAME}\n"
printf "Password    : ${PASSWORD}\n\n"
printf "Wordpress\n"
printf "Username    : ${USERNAME}\n"
printf "Password    : ${WP_PASS}\n\n"
printf "Don't forget to enable Really Simple SSL plugin if Let's Encrypt available\n"
printf "and configure WP Super Cache as well. Enjoy!\n"
printf "===========================================================================\n"
echo

# clean all temporary files
rm -rf /tmp/ngxinstall /tmp/jailkit*
