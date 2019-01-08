#!/bin/bash

# Backup Script CentMinMod [Local Drive Backup, Amazon Backup, FTP Backup]

# Scripted by Brijendra Sial @ Bullten Web Hosting Solutions [https://www.bullten.com]

set -e

echo " "
echo " "

echo -e "$GREEN******************************************************************************$RESET"

echo -e "   Backup Script for CentMinMod Installer [CMM]$RESET"

echo -e "    By Brijendra Sial @ Bullten Web Hosting Solutions https://www.bullten.com/"

echo -e "   Web Hosting Company Specialized in Providing Managed VPS and Dedicated Server's   "

echo -e "$GREEN******************************************************************************$RESET"

echo " "
echo " "

RED='\033[01;31m'
RESET='\033[0m'
GREEN='\033[01;32m'
YELLOW='\e[93m'
WHITE='\e[97m'
BLINK='\e[5m'

time=$(date +"%m_%d_%Y-%H.%M.%S")
rm -f /usr/local/src/centminmod_backup/backup-list.conf
bs=1
b=1

function create_path
{
        echo " "
        echo -e $RED"Backup Path Doesnt Exist"$RESET
        echo " "
        read -p "$(echo -e $GREEN"Enter Path Where You Want To Store Backups e.g /backup || /home/backup :"$RESET) " backup_path
        cat > /usr/local/src/centminmod_backup/backup_path.conf <<-EOF
        Backup_Path:$backup_path
        EOF
        echo " "
        start_display
}

function local_backup_restore
{
        export old_backup_path=/usr/local/src/centminmod_backup/backup_path.conf
        old_backup_content=$(grep "Backup_Path" /usr/local/src/centminmod_backup/backup_path.conf 2>/dev/null | cut -d":" -f2)
        files=$old_backup_content
        for bss in $files;do
                echo "Listing Content of $bss file."
                echo " "
                cf=$(ls -lht $bss | awk '{print $9}' | sed -r '/^\s*$/d' | wc -l)
                for ((i=0; i<$cf; i++)); do
                        display_backup_files=$(ls -lht $bss | awk '{print $9}' | sed -r '/^\s*$/d' | sed -n $b'p')
                        cat >> /usr/local/src/centminmod_backup/backup-list.conf<<-EOF
                        $b) $display_backup_files
                        EOF
                        b=$((b + 1))
                        done
        done
        echo -e $GREEN"Saved Backup Space in /usr/local/src/centminmod_backup/backup-list.conf"$RESET
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

        cat > $pre_backup_path/$backup_domain/mysql/mysql.conf<<-EOF
        Domain_Name:$backup_domain
        Database_Name:$pre_database_name
        Database_User:$pre_database_user
        Database_Password:$pre_database_password
        EOF

        echo " "
        echo "Compressing Backup.."
        tar -zcf $pre_backup_path/CMMBACKUP-$backup_domain-$time.tar.gz -C $pre_backup_path/$backup_domain/ .
        echo " "
        echo -e $YELLOW"Final Compressed Backup Created: $pre_backup_path/CMMBACKUP-$backup_domain-$time.tar.gz"$RESET
        rm -rf $pre_backup_path/$backup_domain
        echo " "
        echo " "
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

                cat > $backup_path/$backup_domain/mysql/mysql.conf<<-EOF
                Domain_Name:$backup_domain
                Database_Name:$backup_domain_database
                Database_User:$backup_domain_user
                Database_Password:$backup_domain_password
                EOF

                echo " "
                echo "Compressing Backup.."
                tar -zcf $backup_path/CMMBACKUP-$backup_domain-$time.tar.gz -C $backup_path/$backup_domain/ .
                echo " "
                echo -e $YELLOW"Final Compressed Backup Created: $backup_path/CMMBACKUP-$backup_domain-$time.tar.gz"$RESET

                echo " "

                cat > /usr/local/src/centminmod_backup/$backup_domain-backup.conf<<-EOF
                Domain_Name:$backup_domain
                Database_Name:$backup_domain_database
                Database_User:$backup_domain_user
                Database_Password:$backup_domain_password
                EOF

                cat > /usr/local/src/centminmod_backup/backup-path.conf<<-EOF
                Backup_Path:$backup_path
                EOF

                echo -e $GREEN"Backup Entries Saved in /usr/local/src/centminmod_backup/$backup_domain-backup.conf"$RESET
                echo " "
                cat /usr/local/src/centminmod_backup/$backup_domain-backup.conf

                echo " "
                echo -e $GREEN"Backup Path Saved in /usr/local/src/centminmod_backup/backup_path.conf"$RESET
                echo " "

                rm -rf $backup_path/$backup_domain
        else
                local_backup_auto
        fi
}

function local_disk_backup
{
                echo " "
                read -p "$(echo -e $GREEN"Enter The Domain Name You Want To Backup e.g domain.com:"$RESET) " backup_domain
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
                                                local_dir_db_backup
                                        else

                                                local_dir_db_backup
                                        fi
                        else
                                echo -e $RED"Your Domain $backup_domain Doesnt Exist"$RESET
                                echo " "
                        fi

}

function start_display
{
if [ -e "/etc/centminmod" ]; then
        echo -e $BLINK"Centminmod Installation Detected"$RESET
        echo " "
                while [ "$bs" = 1 ]; do
                        echo " "
                        echo -e $YELLOW"Select From Below options:"$RESET
                        echo " "
                        echo -e $GREEN"1) Do You Want Make Local Backup e.g /home/backup"$RESET
                        echo -e $GREEN"2) Create Amazon S3 Backup (Work in Progress)"$RESET
                        echo -e $GREEN"3) Make Remote FTP Backup (Work in Progress)"$RESET
                        echo -e $GREEN"4} Restore Backup From Local"$RESET
                        echo -e $GREEN"5) Exit"$RESET
                        echo "#?"

                        read input

                                if [ "$input" = '1' ]; then
                                        echo " "
                                        echo -e $BLINK"You Have Selected to Make Local Hardisk Backup e.g /home/backup"$RESET
                                        echo " "
                                        time=$(date +"%m_%d_%Y-%H.%M.%S")
                                        local_disk_backup

                                elif [ "$input" = '2' ]; then
                                        echo " "
                                        echo -e $BLINK"Make Amazon S3 Backup (Work in Progress)"$RESET
                                        echo " "

                                elif [ "$input" = '3' ]; then
                                        echo " "
                                        echo -e $BLINK"Make FTP Backup (Work in Progress)"$RESET
                                        echo " "

                                elif [ "$input" = '4' ]; then
                                        echo " "
                                        echo -e $BLINK"Restore from backup"$RESET
                                        echo " "
                                        local_backup_restore

                                elif [ "$input" = '5' ]; then
                                        echo -e $BLINK"Exiting"$RESET
                                        echo " "
                                        exit
                                        echo " "

                                else
                                echo " "
                                echo -e $BLINK"You have selected invalid option"$RESET
                                echo " "
                                fi
                done
else
echo " "
echo -e $RED"Centminmod Installation Not Found"$RESET
echo " "
fi
}

mkdir -p /usr/local/src/centminmod_backup

if [ -e "/usr/local/src/centminmod_backup/backup_path.conf" ]; then
        check_backup_path=$(grep "Backup_Path" /usr/local/src/centminmod_backup/backup_path.conf 2>/dev/null | cut -d":" -f2)
        if [ -n "$check_backup_path" ]; then
                echo " "
                echo "Backup Path Exist $check_backup_path"
                echo " "
                start_display
        else
                create_path
        fi
else
        create_path
fi
