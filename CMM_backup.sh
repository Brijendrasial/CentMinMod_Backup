#!/bin/bash

# Create Staging Wordpress Site on Centminmod [CMM]

# Scripted by Brijendra Sial @ Bullten Web Hosting Solutions [https://www.bullten.com]

RED='\033[01;31m'
RESET='\033[0m'
GREEN='\033[01;32m'
YELLOW='\e[93m'
WHITE='\e[97m'
BLINK='\e[5m'

#set -x

echo " "
echo -e "$GREEN*******************************************************************************$RESET"
echo " "
echo -e $YELLOW"Create Staging Wordpress Site on Centminmod [CMM]$RESET"
echo " "
echo -e $YELLOW"By Brijendra Sial @ Bullten Web Hosting Solutions [https://www.bullten.com]"$RESET
echo " "
echo -e $YELLOW"Web Hosting Company Specialized in Providing Managed VPS and Dedicated Server's"$RESET
echo " "
echo -e "$GREEN*******************************************************************************$RESET"

echo " "


MAINDOMAIN="$2"
STAGINGDOMAIN="$3"
DATABASENAME="wpdb_$(openssl rand -hex 4)"
DATABASEUSER="wpuser_$(openssl rand -hex 4)"
DATABASEPASS="wppass_$(openssl rand -hex 8)"
DOMAIN_PATH=/home/nginx/domains
MYSQL_ROOT=$(cat /root/.my.cnf | grep password | cut -d' ' -f1 | cut -d'=' -f2)
RANDOMUSER=$(openssl rand -hex 4)
RANDOMPASS=$(openssl rand -hex 8)
SAVEDPATH=/root/staging-production

case $1 in
--staging )
echo ""
if [ -d $DOMAIN_PATH/$MAINDOMAIN ]; then
  echo "domain exist"
  echo ""
  echo "Checking if website is in wordpress"
  if ! wp core --allow-root --path=$DOMAIN_PATH/$MAINDOMAIN/public is-installed; then
    echo ""
    echo "wordpress is not installed"
  else
    echo ""
    echo "Wordpress is installed"
    echo ""
    echo "Creating Sub Domain"
    if [ -z "$STAGINGDOMAIN" ]; then
      echo ""
      echo "Staging Domain Cant be Empty"
    else
      if [ -d $DOMAIN_PATH/$STAGINGDOMAIN ]; then
        echo ""
        echo "Staging Domain Already Exist. Please Delete it First"
      else
        mkdir -p $DOMAIN_PATH/$STAGINGDOMAIN
        cp -rf $DOMAIN_PATH/$MAINDOMAIN/* $DOMAIN_PATH/$STAGINGDOMAIN/
        chown -R nginx:nginx $DOMAIN_PATH/$STAGINGDOMAIN/
        echo ""
        echo "Creating Database, User and Password"
        echo ""
        RESULTDB=$(mysql -uroot -p$MYSQL_ROOT --skip-column-names -e "SHOW DATABASES LIKE '$DATABASENAME'")
        RESULTUSER=$( mysql -uroot -p$MYSQL_ROOT -e "SELECT USER FROM mysql.user;" | jq -rR . | grep $DATABASEUSER)
        if [ "$RESULTDB" == "$DATABASENAME" ] || [ -n "$RESULTUSER" ]; then
          echo "Please create new database or user as it already exist"
        else
          echo "Database does not exist Creating new".
          mysql -uroot -p$MYSQL_ROOT -e "CREATE DATABASE $DATABASENAME;"
          mysql -uroot -p$MYSQL_ROOT -e "CREATE USER $DATABASEUSER@localhost IDENTIFIED BY '$DATABASEPASS';"
          mysql -uroot -p$MYSQL_ROOT -e "GRANT ALL PRIVILEGES ON $DATABASENAME.* TO '$DATABASEUSER'@'localhost';"
          mysql -uroot -p$MYSQL_ROOT -e "FLUSH PRIVILEGES;"
          rm -rf /home/nginx/domains/$3/public/wp-config.php
          wp --allow-root  --path=$DOMAIN_PATH/$STAGINGDOMAIN/public config create --dbname=$DATABASENAME --dbuser=$DATABASEUSER --dbpass=$DATABASEPASS --dbprefix=$(wp --allow-root db prefix --path=/home/nginx/domains/$MAINDOMAIN/public)
          wp --allow-root  --path=$DOMAIN_PATH/$MAINDOMAIN/public db export ~/production-db.sql
          wp --allow-root  --path=$DOMAIN_PATH/$STAGINGDOMAIN/public db import ~/production-db.sql
          PRODUCTIONURL=$(wp option --allow-root --path=/home/nginx/domains/$MAINDOMAIN/public get siteurl)
          wp --allow-root search-replace --path=$DOMAIN_PATH/$STAGINGDOMAIN/public $PRODUCTIONURL https://$STAGINGDOMAIN --skip-columns=guid
          chown -R nginx:nginx $DOMAIN_PATH/$STAGINGDOMAIN/public
          echo ""
          echo "Generating SSL for staging domain"
          echo ""
          echo ""
          echo "Creating Virtual Host"
          echo ""
          cat nginx_vhost.inc > /usr/local/nginx/conf/conf.d/$STAGINGDOMAIN.ssl.conf
          sed -i "s/demo.com/$STAGINGDOMAIN/g" /usr/local/nginx/conf/conf.d/$STAGINGDOMAIN.ssl.conf
          echo ""
          echo "Removing Old Certificate"
          echo ""
          rm -rf /root/.acme.sh/$STAGINGDOMAIN
          /usr/local/src/centminmod/addons/acmetool.sh issue $STAGINGDOMAIN lived
          echo ""
          echo "Creating ftp"
          echo ""
          (echo $RANDOMPASS;echo $RANDOMPASS) | pure-pw useradd $RANDOMUSER -u nginx -g nginx -d /home/nginx/domains/$STAGINGDOMAIN
          pure-pw mkdb
          echo ""
          echo "Your ftp User is : $RANDOMUSER"
          echo "Your ftp Pass is : $RANDOMPASS"
          mkdir -p $SAVEDPATH
          echo -e "production=$MAINDOMAIN\nstaging=$STAGINGDOMAIN" > $SAVEDPATH/$MAINDOMAIN.conf

        fi
      fi
   fi
fi
else
  echo "domain not found"
fi
;;
--production )
echo ""
echo "production"
echo ""
PRODUCTION_SAVED=$(grep "production" $SAVEDPATH/$MAINDOMAIN.conf | cut -d'=' -f2)
STAGING_SAVED=$(grep "staging" $SAVEDPATH/$MAINDOMAIN.conf | cut -d'=' -f2)
if [ "$MAINDOMAIN" == "$PRODUCTION_SAVED" ] && [ "$STAGINGDOMAIN" == "$STAGING_SAVED" ]; then
  echo ""
  echo "Copying Staging to Production"
  echo ""
  rsync -rlptDu --exclude='wp-config.php' $DOMAIN_PATH/$STAGINGDOMAIN/public/* $DOMAIN_PATH/$MAINDOMAIN/public
  PRODUCTIONURL=$(wp option --allow-root --path=/home/nginx/domains/$MAINDOMAIN/public get siteurl)
  wp --allow-root  --path=$DOMAIN_PATH/$STAGINGDOMAIN/public db export ~/staging-db.sql
  wp --allow-root  --path=$DOMAIN_PATH/$MAINDOMAIN/public db import ~/staging-db.sql
  wp --allow-root search-replace --path=$DOMAIN_PATH/$MAINDOMAIN/public https://$STAGINGDOMAIN $PRODUCTIONURL --skip-columns=guid
  echo ""
  echo "Staging to Production is Done"
else
  echo ""
  echo "Wrong Production or Staging Domain Entered"
fi
;;

esac
