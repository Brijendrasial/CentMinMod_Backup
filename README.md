# CentMinMod_Backup
Backup Sites on CMM <br/>

Important Files Contaning Path: /usr/local/src/centminmod_backup <br/>
backup_path.conf - Where local backup path are stored. <br/>
domain.com-ftp_path.conf - Where FTP details are saved. <br/> 
domain.com-backup.conf - Where mysql details are saved.<br/>

To make Full Database Backup <br/>
./CMM_backup.sh -f <br/><br/>
To make Single Database Backup <br/>
./CMM_backup.sh -u Database_Name <br/><br/>
To make Full files and Database Backup <br/>
./CMM_backup.sh -b <br/>
