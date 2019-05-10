#!/bin/bash

# Backup Script CentMinMod [Local Drive Backup, Amazon Backup, FTP Backup & Restore]

# Scripted by Brijendra Sial @ Bullten Web Hosting Solutions [https://www.bullten.com]

RED='\033[01;31m'
RESET='\033[0m'
GREEN='\033[01;32m'
YELLOW='\e[93m'
WHITE='\e[97m'
BLINK='\e[5m'

#set -e
#set -x

echo " "
echo -e "$GREEN*******************************************************************************$RESET"
echo " "
echo -e $YELLOW"Backup & Restoration Script for CentMinMod Installer [CMM]$RESET"
echo " "
echo -e $YELLOW"Local, Amazon S3, FTP Backup & Restoration"$RESET
echo " "
echo -e $YELLOW"By Brijendra Sial @ Bullten Web Hosting Solutions [https://www.bullten.com]"$RESET
echo " "
echo -e $YELLOW"Web Hosting Company Specialized in Providing Managed VPS and Dedicated Server's"$RESET
echo " "
echo -e "$GREEN*******************************************************************************$RESET"

echo " "



function backup_all_db
{
        time=$(date +"%m_%d_%Y-%H.%M.%S")
        mkdir -p /home/backup
        mkdir -p /home/backup/$time/mysql
        mkdir -p /home/backup/$time/files
        password=$(cat /root/.my.cnf | grep password | cut -d' ' -f1 | cut -d'=' -f2)
        dbs=$(mysql -u root --password=$password -B -N -e 'show databases;' | egrep -v '^mysql|_schema$')
                if [ $? = '0' ]; then
                        for db in $dbs; do
                        echo -e $YELLOW"Full Database Backup in Progress"$RESET
                        sleep 5
                        xyz=$(mysql -u root --password=$password -B -N -e 'show databases;' | egrep -v '^mysql|_schema$' | wc -l)
                                for ((x=1; x<$xyz; x++)); do
                                        /usr/bin/mysqldump -u root --password=$password $db | gzip > /home/backup/$time/mysql/$db.sql.gz
                                        x=$((x + 1))
                                        echo -e $GREEN"Database Backup Completed in /home/backup/$time/mysql/$db.sql.gz"$RESET
                                        echo " "
                                done
                        done
                else
                        echo -e $RED"Database Connection Failed. Please check Your Database Password in /root/.my.cnf File"$RESET
                        echo " "
                        exit
                fi

}


function backup_all_files_uncompressed
{
echo " "
echo -e $GREEN"Making Files Backup"$RESET
echo " "
rsync -vr /home/nginx/domains/* /home/backup/$time/files/
echo " "
echo -e $GREEN"All Files Backup Completed in /home/backup/$time/files/"$RESET
echo " "
}

        case $1 in




                -f )
                        backup_all_db
                        exit
                ;;

                -u )
                        password=$(cat /root/.my.cnf | grep password | cut -d' ' -f1 | cut -d'=' -f2)
                        dbs=$(mysql -u root --skip-column-names -B -N -e "SHOW DATABASES LIKE '$2'")
                                if [ "$dbs" == "$2"  ]; then
                                        echo " "
                                        echo -e $YELLOW"Making Database Backup $dbs"$RESET
                                        sleep 5
                                        time=$(date +"%m_%d_%Y-%H.%M.%S")
                                        /usr/bin/mysqldump -u root --password=$password $dbs | gzip > /home/$dbs-$time.sql.gz
                                        echo -e $GREEN"Database Backup Completed /home/$dbs-$time.sql.gz"$RESET
                                        echo " "
                                else
                                        echo -e $RED"Database Not Found. Please Recheck"$RESET
                                        echo " "
                                fi

                        exit
                ;;


                -b )
                        echo " "
                        echo "Backup All Files and Database"
                        echo " "
                        backup_all_db
                        backup_all_files_uncompressed
                        exit
                ;;

                -h )

                                echo "This is Help Section for CMM Backup by Brijendra Sial"
                                echo " "
                                echo "-f  | Force Full Database Backup Saved (/home/)"
                                echo " "
                                echo "-u DB_NAME | Make Single Database Backup"
                                echo " "
                                echo "-b | Backup All Database and Files Uncompressed"
                                echo " "
                                echo "-h | Help Section"
                                echo " "
                                exit
                ;;

        esac
bs=1
b=1
bsc=1
bsf=1
bb=2
cc=1
s3cmd_name="s3cmd-2.0.2-1.el7.noarch.rpm"
backup_path=$(grep "Backup_Path" /usr/local/src/centminmod_backup/backup_path.conf 2>/dev/null | cut -d":" -f2)

function create_path
{
        echo " "
        echo -e $RED"Backup Path Doesnt Exist"$RESET
        echo " "
        read -p "$(echo -e $GREEN"Enter Path Where You Want To Store Backups e.g /backup || /home/backup :"$RESET) " backup_path
        mkdir -p $backup_path
        cat > /usr/local/src/centminmod_backup/backup_path.conf <<EOF
        Backup_Path:$backup_path
EOF
        echo " "
        start_display
}


function check_ssh_connection
{
        ssh -o PasswordAuthentication=no -i ~/.ssh/cmm.key $destination_ip /bin/true
        if [ $? -eq 0 ]; then
                echo " "
                echo -e $GREEN"Passworless SSH Connection is successfully without Password."$RESET
                echo " "
                site_copy
        else
                echo " "
                echo -e $RED"SSH Connection is not Possible.."$RESET
                rm -rf ~/.ssh/cmm.key
                read -p "$(echo -e $GREEN"Enter Destination Root Password:"$RESET) " destination_password
                ssh-keygen -t rsa -N "" -f ~/.ssh/cmm.key
                #sshpass -p "$destination_password"  ssh -i ~/.ssh/cmm.key root@$destination_ip
                sshpass -p "$destination_password" ssh-copy-id -i ~/.ssh/cmm.key root@$destination_ip
                #ssh -i ~/.ssh/cmm.key root@$destination_ip
                create_connection
        fi

}


function create_connection
{
        echo " "
        read -p "$(echo -e $GREEN"Enter Destination IP:"$RESET) " destination_ip
        check_ssh_connection
}

function site_copy
{
        read -p "$(echo -e $GREEN"Enter Domain Your Want to Copy:"$RESET) " domain_name
        if [ -f /home/nginx/domains/$domain_name/public/wp-config.php ]; then
                echo " "
                echo  -e $YELLOW"Wordpress Installation Found"$RESET
                echo " "
                echo "Moving Site In Progress"
                if ssh -qnx -i ~/.ssh/cmm.key root@$destination_ip "test -d /home/nginx/domains/$domain_name" ; then
                        echo " "
                        echo -e $RED"Site already exist on Destination Server. Quitting copy"$RESET
                        echo " "
                        exit
                else
                        echo " "
                        echo -e $GREEN"Site doesnt exist on Destination Server. Copying in Progress"$RESET
                        echo " "
                        ssh -qnx -i ~/.ssh/cmm.key root@$destination_ip "mkdir -p /home/nginx/domains/$domain_name"
                        mkdir -p /home/nginx/domains/$domain_name/vhosts
                        mkdir -p /home/nginx/domains/$domain_name/mysql
                        mkdir -p /home/nginx/domains/$domain_name/ftp
                        cp /usr/local/nginx/conf/conf.d/$domain_name* /home/nginx/domains/$domain_name/vhosts
                        DATABASE_NAME=$(grep -ir "DB_NAME" /home/nginx/domains/$domain_name/public/wp-config.php | awk {'print $3'} | sed -n "s/^.*'\(.*\)'.*$/\1/ p")
                        DATABASE_USER=$(grep -ir "DB_USER" /home/nginx/domains/$domain_name/public/wp-config.php | awk {'print $3'} | sed -n "s/^.*'\(.*\)'.*$/\1/ p")
                        DATABASE_PASSWORD=$(grep -ir "DB_PASSWORD" /home/nginx/domains/$domain_name/public/wp-config.php | awk {'print $3'} | sed -n "s/^.*'\(.*\)'.*$/\1/ p")
                        mysqldump -u $DATABASE_USER --password=$DATABASE_PASSWORD $DATABASE_NAME > /home/nginx/domains/$domain_name/mysql/$DATABASE_NAME.sql
                        ftp_details=$(grep -ri "$domain_name" /etc/pure-ftpd/pureftpd.passwd)
                        echo $ftp_details > /home/nginx/domains/$domain_name/ftp/pureftpd.passwd
                        rsync -hrtplu  -e 'ssh -p 22 -i ~/.ssh/cmm.key' --ignore-existing --progress /home/nginx/domains/$domain_name root@$destination_ip:/home/nginx/domains/
                        ssh -qnx -i ~/.ssh/cmm.key root@$destination_ip "chown -R nginx:nginx /home/nginx/domains/$domain_name"
                        site_restore
                fi
        else
                echo " "
                echo -e $RED"Wordpress Installation Not Found"$RESET
                echo " "
        fi
}

function site_restore
{
        ROOT_PASSWORD=$(ssh -i ~/.ssh/cmm.key root@$destination_ip "cat /root/.my.cnf | grep password | cut -d' ' -f1 | cut -d'=' -f2")
        #ssh -i ~/.ssh/cmm.key root@$destination_ip "mysql -u root -p$ROOT_PASSWORD -e 'DROP USER $DATABASE_USER@localhost;'"
        ssh -i ~/.ssh/cmm.key root@$destination_ip "mysql -u root -p$ROOT_PASSWORD -e 'CREATE DATABASE $DATABASE_NAME /*\!40100 DEFAULT CHARACTER SET utf8 */;'"
        ssh -i ~/.ssh/cmm.key root@$destination_ip "mysql -u root -p$ROOT_PASSWORD -e 'CREATE USER '$DATABASE_USER'@'localhost' IDENTIFIED BY \"$DATABASE_PASSWORD\";'"
        ssh -i ~/.ssh/cmm.key root@$destination_ip "mysql -u root -p$ROOT_PASSWORD -e 'GRANT ALL PRIVILEGES ON $DATABASE_NAME.* TO '$DATABASE_USER'@'localhost';'"
        ssh -i ~/.ssh/cmm.key root@$destination_ip "mysql -u root -p$ROOT_PASSWORD -e 'FLUSH PRIVILEGES;'"
        ssh -i ~/.ssh/cmm.key root@$destination_ip "mysql -u $DATABASE_USER --password=$DATABASE_PASSWORD $DATABASE_NAME < /home/nginx/domains/$domain_name/mysql/$DATABASE_NAME.sql"
        ssh -i ~/.ssh/cmm.key root@$destination_ip "cp /home/nginx/domains/$domain_name/vhosts/* /usr/local/nginx/conf/conf.d/"
        FTP_USER=$(ssh -i ~/.ssh/cmm.key root@$destination_ip "cat /home/nginx/domains/$domain_name/ftp/pureftpd.passwd | cut -d":" -f1")
        RANDOM_PASS=$(ssh -i ~/.ssh/cmm.key root@$destination_ip "pwgen 8 1")
        ssh -i ~/.ssh/cmm.key root@$destination_ip "(echo $RANDOM_PASS;echo $RANDOM_PASS) | pure-pw useradd $FTP_USER -u nginx -g nginx -d /home/nginx/domains/$domain_name"
        ssh -i ~/.ssh/cmm.key root@$destination_ip "pure-pw mkdb"
        echo " "
        echo "New FTP Password is $RANDOM_PASS"
        echo " "
        echo -e $GREEN"Restore is Successfull"$RESET
        echo " "
}

function site_migration
{
        echo " "
        if  rpm -q sshpass > /dev/null ; then
                echo -e $YELLOW"sshpass Installation Found. Skipping Its Installation"$RESET
                create_connection
        else
        echo -e $RED"sshpass Installation Not Found. Installing it"$RESET
        echo " "
        yum install sshpass -y
        echo " "
        create_connection
        fi

}


function ftp_backup_restore
{
        rm -f /usr/local/src/centminmod_backup/backup-list.conf
        FTP_HOST=$(grep "FTP_HOST" /usr/local/src/centminmod_backup/$backup_domain-ftp_path.conf 2>/dev/null | cut -d":" -f2)
        FTP_PATH=$(grep "FTP_PATH" /usr/local/src/centminmod_backup/$backup_domain-ftp_path.conf 2>/dev/null | cut -d":" -f2)
        FTP_USER=$(grep "FTP_USER" /usr/local/src/centminmod_backup/$backup_domain-ftp_path.conf 2>/dev/null | cut -d":" -f2)
        FTP_PASSWORD=$(grep "FTP_PASSWORD" /usr/local/src/centminmod_backup/$backup_domain-ftp_path.conf 2>/dev/null | cut -d":" -f2)
        old_backup_content=$(grep "Backup_Path" /usr/local/src/centminmod_backup/backup_path.conf 2>/dev/null | cut -d":" -f2)
        for bsss in $FTP_PATH;do
                echo "Listing Content of $bsss file."
                echo " "
                cfz=$(lftp -c "open -u $FTP_USER,$FTP_PASSWORD $FTP_HOST; ls $bsss" | awk '{print $9}' | sed -r '/^\s*$/d' | wc -l)
                for ((j=2; j<$cfz; j++)); do
                        display_backup_files=$(lftp -c "open -u $FTP_USER,$FTP_PASSWORD $FTP_HOST; ls -lht $bsss" | awk '{print $9}' | sed -r '/^\s*$/d' | sed -n $bb'p')
                        cat >> /usr/local/src/centminmod_backup/backup-list.conf<<EOF
                        $cc) $display_backup_files
EOF
                        cc=$((cc + 1))
                done
        done
        echo -e $GREEN"Saved List Of Backups in /usr/local/src/centminmod_backup/backup-list.conf"$RESET
        echo ""
        cat /usr/local/src/centminmod_backup/backup-list.conf
        echo " "
        echo -e $YELLOW"Select The Number of Which You Want To Restore Backup?"$RESET
        echo " "

        read -p "$(echo -e $GREEN"Enter Which Backup Number You Want to Rest e.g 1 , 2 , 3 ..:"$RESET) " bn
        fetch_backup=$(grep -i "$bn)" /usr/local/src/centminmod_backup/backup-list.conf | awk '{print $2}')
        echo " "
        echo "Fetched Backup is $fetch_backup"
        echo " "
        fetch_domain=$(grep -i "$bn)" /usr/local/src/centminmod_backup/backup-list.conf | awk '{print $2}' | awk -F'[-]' '{print $1"-"$2"-"$3}' | cut -d"-" -f2)
        echo " "
        echo "Backup Restoration for $fetch_domain"

        if [ -e "/home/nginx/domains/$fetch_domain" ]; then
                echo " "
                echo -e $RED"Domain Already Exist on Server /home/nginx/domains/$fetch_domain .Delete It First to Continue Backup Restoration"$RESET
                echo " "
        else
                echo "Restoring Backup Please Wait.."
                new_name=$(grep -i "$bn)" /usr/local/src/centminmod_backup/backup-list.conf | awk '{print $2}' | awk -F'[-]' '{print $1"-"$2"-"$3}')
                mkdir -p $old_backup_content/$new_name
                tar -zxvf $old_backup_content/$fetch_backup -C $old_backup_content/$new_name
                cp -r $old_backup_content/$new_name/$fetch_domain /home/nginx/domains/
                cp -r $old_backup_content/$new_name/nginx_vhost/* /usr/local/nginx/conf/conf.d/
                res_database_name=$(grep "Database_Name" $old_backup_content/$new_name/mysql/mysql.conf 2>/dev/null | cut -d":" -f2)
                res_database_user=$(grep "Database_User" $old_backup_content/$new_name/mysql/mysql.conf 2>/dev/null | cut -d":" -f2)
                res_database_password=$(grep "Database_Password" $old_backup_content/$new_name/mysql/mysql.conf 2>/dev/null | cut -d":" -f2)

                if [  -d "/var/lib/mysql/$res_database_name" ] ; then
                        echo " "
                        echo "Database ALready Exist. Delete It to Continue The installation"
                        echo " "
                else
                echo " "
                echo "Creating Database, User & Password Using Root Login"

                                root_password=$(cat /root/.my.cnf | grep password | cut -d' ' -f1 | cut -d'=' -f2)
                                if [ -z "$root_password" ]; then
                                        echo " "
                                        echo -e $RED"Mysql Root Password Not Found in /root/.my.cnf. Exiting Restoration"$RESET
                                        echo " "
                                else
                                        mysql -uroot -p$root_password -e "DROP USER $res_database_user@localhost;"
                                        mysql -uroot -p$root_password -e "CREATE DATABASE $res_database_name /*\!40100 DEFAULT CHARACTER SET utf8 */;"
                                        mysql -uroot -p$root_password -e "CREATE USER $res_database_user@localhost IDENTIFIED BY '$res_database_password';"
                                        mysql -uroot -p$root_password -e "GRANT ALL PRIVILEGES ON $res_database_name.* TO '$res_database_user'@'localhost';"
                                        mysql -uroot -p$root_password -e "FLUSH PRIVILEGES;"
                                        echo " "
                                        echo "Restoring Mysql Database $res_database_name"
                                        echo " "
                                        mysql -u $res_database_user -p$res_database_password $res_database_name < $old_backup_content/$new_name/mysql/$res_database_name.sql
                                        echo "Success"
                                        echo " "
                                fi

                echo "Changing Permission of files to nginx:nginx"
                chown -R nginx:nginx /home/nginx/domains/$fetch_domain
                rm -rf $old_backup_content/$new_name
                echo " "
                echo "Success"
                echo  " Restarting Server"
                nprestart
                echo " "
                echo -e $YELLOW"Restoration Completed Successfully."$RESET
                echo " "
                fi
        fi
                ftp_display
}


function local_backup_restore
{
        rm -f /usr/local/src/centminmod_backup/backup-list.conf
        export old_backup_path=/usr/local/src/centminmod_backup/backup_path.conf
        old_backup_content=$(grep "Backup_Path" /usr/local/src/centminmod_backup/backup_path.conf 2>/dev/null | cut -d":" -f2)
        files=$old_backup_content
        for bss in $files;do
                echo "Listing Content of $bss file."
                echo " "
                cf=$(ls -lht $bss | awk '{print $9}' | sed -r '/^\s*$/d' | wc -l)
                for ((i=0; i<$cf; i++)); do
                        display_backup_files=$(ls -lht $bss | awk '{print $9}' | sed -r '/^\s*$/d' | sed -n $b'p')
                        cat >> /usr/local/src/centminmod_backup/backup-list.conf<<EOF
                        $b) $display_backup_files
EOF
                        b=$((b + 1))
                done
        done
        echo -e $GREEN"Saved List Of Backups in /usr/local/src/centminmod_backup/backup-list.conf"$RESET
        echo ""
        cat /usr/local/src/centminmod_backup/backup-list.conf
        echo " "
        echo -e $YELLOW"Select The Number of Which You Want To Restore Backup?"$RESET
        echo " "

        read -p "$(echo -e $GREEN"Enter Which Backup Number You Want to Rest e.g 1 , 2 , 3 ..:"$RESET) " bn
        fetch_backup=$(grep -i "$bn)" /usr/local/src/centminmod_backup/backup-list.conf | awk '{print $2}')
        echo " "
        echo "Fetched Backup is $fetch_backup"
        echo " "
        fetch_domain=$(grep -i "$bn)" /usr/local/src/centminmod_backup/backup-list.conf | awk '{print $2}' | awk -F'[-]' '{print $1"-"$2"-"$3}' | cut -d"-" -f2)
        echo " "
        echo "Backup Restoration for $fetch_domain"

        if [ -e "/home/nginx/domains/$fetch_domain" ]; then
                echo " "
                echo -e $RED"Domain Already Exist on Server /home/nginx/domains/$fetch_domain .Delete It First to Continue Backup Restoration"$RESET
                echo " "
        else
                echo "Restoring Backup Please Wait.."
                new_name=$(grep -i "$bn)" /usr/local/src/centminmod_backup/backup-list.conf | awk '{print $2}' | awk -F'[-]' '{print $1"-"$2"-"$3}')
                mkdir -p $old_backup_content/$new_name
                tar -zxvf $old_backup_content/$fetch_backup -C $old_backup_content/$new_name
                cp -r $old_backup_content/$new_name/$fetch_domain /home/nginx/domains/
                cp -r $old_backup_content/$new_name/nginx_vhost/* /usr/local/nginx/conf/conf.d/
                res_database_name=$(grep "Database_Name" $old_backup_content/$new_name/mysql/mysql.conf 2>/dev/null | cut -d":" -f2)
                res_database_user=$(grep "Database_User" $old_backup_content/$new_name/mysql/mysql.conf 2>/dev/null | cut -d":" -f2)
                res_database_password=$(grep "Database_Password" $old_backup_content/$new_name/mysql/mysql.conf 2>/dev/null | cut -d":" -f2)

                if [  -d "/var/lib/mysql/$res_database_name" ] ; then
                        echo " "
                        echo "Database ALready Exist. Delete It to Continue The installation"
                        echo " "
                else
                echo " "
                echo "Creating Database, User & Password Using Root Login"

                                root_password=$(cat /root/.my.cnf | grep password | cut -d' ' -f1 | cut -d'=' -f2)
                                if [ -z "$root_password" ]; then
                                        echo " "
                                        echo -e $RED"Mysql Root Password Not Found in /root/.my.cnf. Exiting Restoration"$RESET
                                        echo " "
                                else
                                        mysql -uroot -p$root_password -e "DROP USER $res_database_user@localhost;"
                                        mysql -uroot -p$root_password -e "CREATE DATABASE $res_database_name /*\!40100 DEFAULT CHARACTER SET utf8 */;"
                                        mysql -uroot -p$root_password -e "CREATE USER $res_database_user@localhost IDENTIFIED BY '$res_database_password';"
                                        mysql -uroot -p$root_password -e "GRANT ALL PRIVILEGES ON $res_database_name.* TO '$res_database_user'@'localhost';"
                                        mysql -uroot -p$root_password -e "FLUSH PRIVILEGES;"
                                        echo " "
                                        echo "Restoring Mysql Database $res_database_name"
                                        echo " "
                                        mysql -u $res_database_user -p$res_database_password $res_database_name < $old_backup_content/$new_name/mysql/$res_database_name.sql
                                        echo "Success"
                                        echo " "
                                fi

                echo "Changing Permission of files to nginx:nginx"
                chown -R nginx:nginx /home/nginx/domains/$fetch_domain
                rm -rf $old_backup_content/$new_name
                echo " "
                echo "Success"
                echo  " Restarting Server"
                nprestart
                echo " "
                echo -e $YELLOW"Restoration Completed Successfully."$RESET
                echo " "
                fi
        fi
}


function local_backup_auto
{
        mkdir -p $pre_backup_path/$backup_domain/mysql
        mkdir -p $pre_backup_path/$backup_domain/nginx_vhost
        echo " "
        echo "Copying All Files From /home/nginx/domains/$backup_domain/ to $pre_backup_path/$backup_domain"
        rsync -vr /home/nginx/domains/$backup_domain $pre_backup_path/$backup_domain/

        echo " "
        echo "Copying Virtual Host File For $backup_domain"
        rsync -vr /usr/local/nginx/conf/conf.d/$backup_domain*.conf $pre_backup_path/$backup_domain/nginx_vhost/

        echo " "
        echo "Copying FTP Details From /etc/pure-ftpd/pureftpd.passwd to $pre_backup_path/$backup_domain/pureftpd.passwd"
        ftp_details=$(grep -ri "$backup_domain" /etc/pure-ftpd/pureftpd.passwd)
        echo $ftp_details > $pre_backup_path/$backup_domain/pureftpd.passwd

        echo " "
        echo "Creating Database Backup"
        mysqldump -u $pre_database_user -p$pre_database_password $pre_database_name > $pre_backup_path/$backup_domain/mysql/$pre_database_name.sql

        cat > $pre_backup_path/$backup_domain/mysql/mysql.conf<<EOF
        Domain_Name:$backup_domain
        Database_Name:$pre_database_name
        Database_User:$pre_database_user
        Database_Password:$pre_database_password
EOF

        mkdir -p $pre_backup_path/$backup_domain/ftp_path
        rsync -vr /usr/local/src/centminmod_backup/$backup_domain-ftp_path.conf $pre_backup_path/$backup_domain/ftp_path/

        echo " "
        echo "Compressing Backup.."
        tar -zcf $pre_backup_path/CMMBACKUP-$backup_domain-$time.tar.gz -C $pre_backup_path/$backup_domain/ .
        echo " "
        echo -e $YELLOW"Final Compressed Backup Created: $pre_backup_path/CMMBACKUP-$backup_domain-$time.tar.gz"$RESET
        rm -rf $pre_backup_path/$backup_domain
        echo " "
        echo " "

                        if [[ $inputs = '1' ]]; then
                                echo " "
                                echo "Sending Generated Backup CMMBACKUP-$backup_domain-$time.tar.gz to s3://$bucket_name"
                                aws s3 cp $backup_path/CMMBACKUP-$backup_domain-$time.tar.gz s3://$bucket_name
                                echo " "
                                echo "Backup Sent To Amazon s3://$bucket_name/$backup_domain-$time.tar.gz"
                                echo " "
                        elif [[ $inputss = '1' ]]; then
                                echo " "
                                echo "FTP Upload In Progress"
                                echo " "
                                lftp -c "open -u $FTP_USER,$FTP_PASSWORD $FTP_HOST; put -O $FTP_PATH $pre_backup_path/CMMBACKUP-$backup_domain-$time.tar.gz"

                        elif [[ $inputss = '1' ]]; then
                                echo " "
                                echo "FTP Upload In Progress"
                                echo " "
                                lftp -c "open -u $FTP_USER,$FTP_PASSWORD $FTP_HOST; put -O $FTP_PATH $pre_backup_path/CMMBACKUP-$backup_domain-$time.tar.gz"

                        elif [[ $input = '6' ]]; then
                                echo " "
                                echo "Uploading backup to gdrive"
                                echo " "
                                gdrive upload $backup_path/CMMBACKUP-$backup_domain-$time.tar.gz
                        else
                                echo "Exiting..."
                                echo " "
                        fi
}


function local_dir_db_backup
{
        if [ -z "$pre_backup_path" ] || [ -z "$pre_domain_name" ] || [ -z "$pre_database_name" ] || [ -z "$pre_database_user" ] || [ -z "$pre_database_password" ]; then
                echo -e $RED"Previous Saved Backed File for $backup_domain Doesnt Exist. Creating New"$RESET
                echo ""
                mkdir -p $backup_path/$backup_domain/mysql
                mkdir -p $backup_path/$backup_domain/nginx_vhost
                read -p "$(echo -e $GREEN"Enter Database Name:"$RESET) " backup_domain_database
                read -p "$(echo -e $GREEN"Enter Database User:"$RESET) " backup_domain_user
                read -p "$(echo -e $GREEN"Enter Database Password:"$RESET) " backup_domain_password

                echo "Your Entered Database User is: $backup_domain_user"
                echo "Your Entered Database Name is: $backup_domain_database"
                echo "Your Entered Database User is: $backup_domain_password"
                echo " "

                echo " "
                echo "Copying All Files From /home/nginx/domains/$backup_domain/ to $backup_path/$backup_domain"
                rsync -vr /home/nginx/domains/$backup_domain $backup_path/$backup_domain/

                echo " "
                echo "Copying Virtual Host File For $backup_domain"
                rsync -vr /usr/local/nginx/conf/conf.d/$backup_domain*.conf $backup_path/$backup_domain/nginx_vhost/

                echo " "
                echo "Copying FTP Details From /etc/pure-ftpd/pureftpd.passwd to $backup_path/$backup_domain/pureftpd.passwd"
                ftp_details=$(grep -ri "$backup_domain" /etc/pure-ftpd/pureftpd.passwd)
                echo $ftp_details > $backup_path/$backup_domain/pureftpd.passwd

                echo " "
                echo "Creating Database Backup"
                mysqldump -u $backup_domain_user -p$backup_domain_password $backup_domain_database > $backup_path/$backup_domain/mysql/$backup_domain_database.sql

                cat > $backup_path/$backup_domain/mysql/mysql.conf<<EOF
                Domain_Name:$backup_domain
                Database_Name:$backup_domain_database
                Database_User:$backup_domain_user
                Database_Password:$backup_domain_password
EOF

                mkdir -p $backup_path/$backup_domain/ftp_path
                rsync -vr /usr/local/src/centminmod_backup/$backup_domain-ftp_path.conf $backup_path/$backup_domain/ftp_path/

                echo " "
                echo "Compressing Backup.."
                tar -zcf $backup_path/CMMBACKUP-$backup_domain-$time.tar.gz -C $backup_path/$backup_domain/ .
                echo " "
                echo -e $YELLOW"Final Compressed Backup Created: $backup_path/CMMBACKUP-$backup_domain-$time.tar.gz"$RESET

                echo " "

                cat > /usr/local/src/centminmod_backup/$backup_domain-backup.conf<<EOF
                Domain_Name:$backup_domain
                Database_Name:$backup_domain_database
                Database_User:$backup_domain_user
                Database_Password:$backup_domain_password
EOF


                echo -e $GREEN"Backup Entries Saved in /usr/local/src/centminmod_backup/$backup_domain-backup.conf"$RESET
                echo " "
                cat /usr/local/src/centminmod_backup/$backup_domain-backup.conf

                echo " "
                echo -e $GREEN"Backup Path Saved in /usr/local/src/centminmod_backup/backup_path.conf"$RESET
                echo " "

                rm -rf $backup_path/$backup_domain

                        if [[ $inputs = '1' ]]; then
                                echo " "
                                echo "Sending Generated Backup CMMBACKUP-$backup_domain-$time.tar.gz to s3://$bucket_name"
                                aws s3 cp $backup_path/CMMBACKUP-$backup_domain-$time.tar.gz s3://$bucket_name
                                echo " "
                                echo "Backup Sent To Amazon s3://$bucket_name/$backup_domain-$time.tar.gz"
                                echo " "
                        elif [[ $inputss = '1' ]]; then
                                echo " "
                                echo "FTP Upload In Progress"
                                echo " "
                                lftp -c "open -u $FTP_USER,$FTP_PASSWORD $FTP_HOST; put -O $FTP_PATH $backup_path/CMMBACKUP-$backup_domain-$time.tar.gz"

                        elif [[ $input = '6' ]]; then
                                echo " "
                                echo "Uploading backup to gdrive"
                                echo " "
                                gdrive upload $backup_path/CMMBACKUP-$backup_domain-$time.tar.gz
                        fi
        else
                local_backup_auto
                        fi


}

function local_disk_backup
{
        echo " "
        read -p "$(echo -e $GREEN"Enter The Domain Name You Want To Backup e.g domain.com:"$RESET) " backup_domain
        if [ $inputss = '2' ]; then
                ftp_backup_restore
        fi
        echo " "
        echo -e $BLINK"Domain You entered is $backup_domain"$RESET
        echo " "
                if [ -e "/home/nginx/domains/$backup_domain/public" ]; then
                        echo -e $WHITE"Your Domain $backup_domain exist"$RESET
                        echo " "
                        local_display_path=/home/nginx/domains/$backup_domain/public
                        echo $local_display_path
                        echo " "
                                if [ -e "/usr/local/src/centminmod_backup/backup_path.conf" ] && [ -e "/usr/local/src/centminmod_backup/$backup_domain-backup.conf" ]; then
                                        pre_backup_path=$(grep "Backup_Path" /usr/local/src/centminmod_backup/backup_path.conf 2>/dev/null | cut -d":" -f2)
                                        pre_domain_name=$(grep "Domain_Name" /usr/local/src/centminmod_backup/$backup_domain-backup.conf 2>/dev/null | cut -d":" -f2)
                                        pre_database_name=$(grep "Database_Name" /usr/local/src/centminmod_backup/$backup_domain-backup.conf 2>/dev/null | cut -d":" -f2)
                                        pre_database_user=$(grep "Database_User" /usr/local/src/centminmod_backup/$backup_domain-backup.conf 2>/dev/null | cut -d":" -f2)
                                        pre_database_password=$(grep "Database_Password" /usr/local/src/centminmod_backup/$backup_domain-backup.conf 2>/dev/null | cut -d":" -f2)
                                                if [ $inputss = '1' ]; then
                                                        ftp_connection_check
                                                fi
                                        local_dir_db_backup

                                else
                                                if [ $inputss = '1' ]; then
                                                        ftp_connection_check
                                                fi
                                        local_dir_db_backup
                                fi
                else
                        echo -e $RED"Your Domain $backup_domain Doesnt Exist"$RESET
                        echo " "
                fi
}

function amazon_backup_check
{
        echo " "
        bucket_name=$(grep -i "Bucket_Name" /usr/local/src/centminmod_backup/bucket_name.conf | cut -d':' -f2)
        check_bucket_names=$(aws s3api head-bucket --bucket $check_bucket_name 2> /tmp/bullten)
        if [ -z /tmp/bullten ]; then
                        echo " "
                        echo "Bucket Found. Creating Backup"
                        local_disk_backup
                else
                        echo " "
                        echo "Bucket Not Found. Creating Bucket"
                        aws s3 mb s3://$check_bucket_name
                        local_disk_backup
        fi

}

function amazon_aws_config
{
        echo -e $YELLOW"Checking If required Software is installed"$RESET
        echo " "
        if  rpm -q awscli > /dev/null ; then
                echo -e $GREEN"aws Installation Found. Skipping Its Installation"$RESET
        else
                echo -e $RED"aws Installation Not Found. Installing it"$RESET
                echo " "
                yum install awscli -y
                echo " "
        fi

        read -p "$(echo -e $GREEN"Enter Bucket Name:"$RESET) " bucket_name
        cat > /usr/local/src/centminmod_backup/bucket_name.conf <<EOF
                        Bucket_Name:$bucket_name
EOF
        if aws s3api head-bucket --bucket $bucket_name > /dev/null ; then
                echo " "
                echo "Configuration is Working Fine. "
                echo " "
                amazon_display
        else

                read -p "$(echo -e $GREEN"Enter Access Key:"$RESET) " access_key
                read -p "$(echo -e $GREEN"Enter Secret Key:"$RESET) " secret_key
                read -p "$(echo -e $GREEN"Enter Bucket Location e.g US:"$RESET) " bucket_location
                aws configure set aws_access_key_id $access_key
                aws configure set aws_secret_access_key $secret_key
                aws configure set output json --profile CMM
                aws configure set region $bucket_location --profile CMM
                aws configure set ca_bundle /etc/pki/tls/certs/ca-bundle.crt --profile CMM
                amazon_backup_check
        fi
}


function ftp_software_check
{
echo -e $YELLOW"Checking If required FTP Software is installed"$RESET
echo " "
        if  rpm -q lftp > /dev/null ; then
                echo -e $GREEN"lftp Installation Found. Skipping Its Installation"$RESET
                ftp_display
        fi
                echo -e $RED"lftp Installation Not Found. Installing it"$RESET
                echo " "
                yum install lftp -y
                echo "set ssl:verify-certificate no" >> /etc/lftp.conf
                echo " "
                ftp_display
}


function ftp_backup_check
{
        if [ -f /usr/local/src/centminmod_backup/$backup_domain-ftp_path.conf  ]; then
                echo "FTP configuration file exist. Check if variables are set right"

                FTP_HOST=$(grep -i "FTP_HOST" /usr/local/src/centminmod_backup/$backup_domain-ftp_path.conf | cut -d':' -f2)
                FTP_PATH=$(grep -i "FTP_PATH" /usr/local/src/centminmod_backup/$backup_domain-ftp_path.conf | cut -d':' -f2)
                FTP_USER=$(grep -i "FTP_USER" /usr/local/src/centminmod_backup/$backup_domain-ftp_path.conf | cut -d':' -f2)
                FTP_PASSWORD=$(grep -i "FTP_PASSWORD" /usr/local/src/centminmod_backup/$backup_domain-ftp_path.conf | cut -d':' -f2)

                wget --spider --tries=1 --user=$FTP_USER --password=$FTP_PASSWORD ftps://$FTP_HOST --no-check-certificate

                        if [ $? -ne 0 ]; then
                        echo -e $GREEN"Failed to connect to ftp host."$RESET
                                echo " "
                                echo "Create FTP config again"
                                ftp_backup_config
                        else
                                echo $RED"Connected to FTP host successfully."$RESET
                                echo " "
                                ftp_display
                        fi

        else
                echo "Making new ftp configuration file"
                ftp_backup_config
        fi

}


function ftp_connection_check
{
        FTP_HOST=$(grep -i "FTP_HOST" /usr/local/src/centminmod_backup/$backup_domain-ftp_path.conf | cut -d':' -f2)
        FTP_PATH=$(grep -i "FTP_PATH" /usr/local/src/centminmod_backup/$backup_domain-ftp_path.conf | cut -d':' -f2)
        FTP_USER=$(grep -i "FTP_USER" /usr/local/src/centminmod_backup/$backup_domain-ftp_path.conf | cut -d':' -f2)
        FTP_PASSWORD=$(grep -i "FTP_PASSWORD" /usr/local/src/centminmod_backup/$backup_domain-ftp_path.conf | cut -d':' -f2)

        wget --spider --tries=1 --user=$FTP_USER --password=$FTP_PASSWORD ftps://$FTP_HOST --no-check-certificate
                if [ $? -ne 0 ]; then
                        echo " "
                        echo -e $GREEN"Failed to connect to ftp host."$RESET
                        echo " "
                        echo "Create FTP config again"
                        ftp_backup_config
                else
                        echo $RED"Connected to FTP host successfully."$RESET
                        echo " "
                fi
}

function ftp_backup_config
{
        echo " "
        read -p "$(echo -e $GREEN"Enter FTP Hostname:"$RESET) " ftp_host
        read -p "$(echo -e $GREEN"Enter FTP Backup Path e.g /backup:"$RESET) " ftp_path
        read -p "$(echo -e $GREEN"Enter FTP user:"$RESET) " ftp_user
        read -p "$(echo -e $GREEN"Enter FTP password:"$RESET) " ftp_password

        cat > /usr/local/src/centminmod_backup/$backup_domain-ftp_path.conf <<EOF
        FTP_HOST:$ftp_host
        FTP_PATH:$ftp_path
        FTP_USER:$ftp_user
        FTP_PASSWORD:$ftp_password
EOF
        ftp_connection_check
}

function gdrive_software_check
{
if [ -f "/usr/bin/gdrive" ]; then
        echo " "
        echo "gdrive Exist"
        local_disk_backup
else
        echo " "
        wget "https://docs.google.com/uc?id=0B3X9GlR6EmbnQ0FtZmJJUXEyRTA&export=download" -O /usr/bin/gdrive
        chmod 777 /usr/bin/gdrive
        echo " "
        local_disk_backup
fi
}


function start_display
{
        if [ -e "/etc/centminmod" ]; then
                echo -e $BLINK"Centminmod Installation Detected"$RESET
                echo " "
                        while [ "$bs" = 1 ]; do
                                echo -e $YELLOW"Select Main Menu Backup & Restore Options From Below:"$RESET
                                echo " "
                                echo -e $GREEN"1) Do You Want Make Local Backup e.g [/home/backup]"$RESET
                                echo " "
                                echo -e $GREEN"2) Create or Restore Amazon S3 Backup i.e [s3://bucket_name]"$RESET
                                echo " "
                                echo -e $GREEN"3) Make Remote FTP Backup"$RESET
                                echo " "
                                echo -e $GREEN"4} Restore Backup From Local"$RESET
                                echo " "
                                echo -e $GREEN"5) Site Migration CMM Source to CMM Destination"$RESET
                                echo " "
                                echo -e $GREEN"6) Make Gdrive Backup"$RESET
                                echo " "
                                echo -e $GREEN"7) Exit"$RESET
                                echo "#?"

                                read input

                                        if [ "$input" = '1' ]; then
                                                echo " "
                                                echo -e $BLINK"You Have Selected to Make Local Hardisk Backup e.g /home/backup"$RESET
                                                time=$(date +"%m_%d_%Y-%H.%M.%S")
                                                local_disk_backup

                                        elif [ "$input" = '2' ]; then
                                                echo " "
                                                echo -e $BLINK"Making Amazon S3 Backup"$RESET
                                                echo " "
                                                amazon_aws_config

                                        elif [ "$input" = '3' ]; then
                                                echo " "
                                                echo -e $BLINK"Make FTP Backup"$RESET
                                                ftp_software_check

                                        elif [ "$input" = '4' ]; then
                                                echo " "
                                                echo -e $BLINK"Restore From Local Backup"$RESET
                                                echo " "
                                                local_backup_restore

                                        elif [ "$input" = '5' ]; then
                                                echo " "
                                                echo -e $BLINK"Site Migration from CMM to CMM"$RESET
                                                echo " "
                                                site_migration

                                        elif [ "$input" = '6' ]; then
                                                echo " "
                                                echo -e $BLINK"Making Gdrive Backup"$RESET
                                                echo " "
                                                time=$(date +"%m_%d_%Y-%H.%M.%S")
                                                gdrive_software_check

                                        elif [ "$input" = '7' ]; then
                                                echo " "
                                                echo -e $BLINK"Exiting"$RESET
                                                echo " "
                                                exit

                                        else
                                                echo " "
                                                echo -e $RED"You have Selected An Invalid Option"$RESET
                                                echo " "
                                        fi
                        done
        else

                echo " "
                echo -e $RED"Centminmod Installation Not Found"$RESET
                echo " "

        fi
}


function amazon_display
{
        while [ "$bsc" = 1 ]; do
             echo " "
             echo -e $YELLOW"Select Amazon Backup Options From Below:"$RESET
             echo " "
             echo -e $GREEN"1) Do You Want To Make Amazon Backup i.e [s3://bucket_name]"$RESET
             echo " "
             echo -e $GREEN"2) Do You Want To Restore Backup From Amazon [s3://bucket_name/backup_name]"$RESET
             echo " "
             echo -e $GREEN"3) Back To Previous Screen"$RESET
             echo "#?"

             read inputs

                if [ "$inputs" = '1' ]; then
                        echo " "
                        echo -e $BLINK"You Have Selected to Make Amazon Backup i.e [s3://BUCKET]"$RESET
                        time=$(date +"%m_%d_%Y-%H.%M.%S")
                        local_disk_backup

                elif [ "$inputs" = '2' ]; then
                        echo " "
                        echo "Restoring Amazon Backup"
                        echo " "
                        echo "Coming Soon"
                        echo " "

                elif [ "$inputs" = '3' ]; then
                        echo " "
                        start_display
                        echo " "
                else

                        echo " "
                        echo -e $RED"You Have Selected An Invalid Option"$RESET
                        echo " "
                fi
        done
}


function ftp_display

{
        while [ "$bsf" = 1 ]; do
             echo " "
             echo -e $YELLOW"Select FTP Backup Options From Below:"$RESET
             echo " "
             echo -e $GREEN"1) Do You Want To Make FTP Backup"$RESET
             echo " "
             echo -e $GREEN"2) Do You Want To Restore FTP Backup"$RESET
             echo " "
             echo -e $GREEN"3) Back To Previous Screen"$RESET
             echo "#?"

             read inputss

                if [ "$inputss" = '1' ]; then
                        echo " "
                        echo -e $BLINK"You Have Selected to Make FTP Backup i.e [s3://BUCKET]"$RESET
                        time=$(date +"%m_%d_%Y-%H.%M.%S")
                        local_disk_backup

                elif [ "$inputss" = '2' ]; then
                        echo " "
                        echo "Restoring fTP Backup"
                        echo " "
                        local_disk_backup
                       echo " "

                elif [ "$inputss" = '3' ]; then
                        echo " "
                        start_display
                        echo " "
                else

                        echo " "
                        echo -e $RED"You Have Selected An Invalid Option"$RESET
                        echo " "
                fi
        done
}

mkdir -p /usr/local/src/centminmod_backup

        if [ -e "/usr/local/src/centminmod_backup/backup_path.conf" ]; then
                check_backup_path=$(grep "Backup_Path" /usr/local/src/centminmod_backup/backup_path.conf 2>/dev/null | cut -d":" -f2)

                        if [ -n "$check_backup_path" ]; then
                                echo -e $BLINK"Backup Path Exist: $check_backup_path"$RESET

                                        if [ -e "$check_backup_path" ]; then
                                                echo " "
                                                start_display
                                                echo " "
                                        else
                                                echo " "
                                                mkdir -p $check_backup_path
                                                echo  " "
                                                start_display
                                        fi
                        fi
        else
                create_path
        fi
