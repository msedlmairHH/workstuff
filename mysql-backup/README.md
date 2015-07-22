# Mysql Backup
this repository represents the usual mysql backup process.

## usage
just run the script

## configuration
if you put a bash script at `/etc/ggs/mysqlbackupconfig.sh` you can overwrite following variables
```bash
LOGFILE="/var/log/mysqlbackup.sh.log"
IDENTIFIER=$(hostname -f 2>/dev/null || hostname)
BACKUPDATE=$(date '+%Y%m%d')
BACKUPBASE="/data/backup"
KEEP_DAYS="7"
XTRABACKUPTARGET="${BACKUPBASE}/${IDENTIFIER}/${BACKUPDATE}/"
XTRABACKUPBIN="/usr/bin/xtrabackup"
XTRABACKUPOPTIONS=(--target-dir=${XTRABACKUPTARGET})
TMPLOGFILE="/var/log/mysqlbackup${BACKUPDATE}.sh.log"
BACKUPLOGFILE="${XTRABACKUPTARGET}/mysqlbackup.sh.log"
BACKUPMOUNTPOINT=""
NFSOPTIONS=()
```

* `LOGFILE` the global logfile will contain every backup
* `IDENTIFIER` is the host or database identifier. It can also be something like project name
* `BACKUPDATE` does the date format
* `BACKUPBASE` the base folder for backups
* `KEEP_DAYS` how long to keep backups (TODO: maybe change to KEEP_COUNT.)
* `XTRABACKUPTARGET` the folder structure where to store the backup
* `XTRABACKUPBIN` the xtrabackup binary
* `XTRABACKUPOPTIONS` array of options
* `TMPLOGFILE` this is a copy of the current log to store it besides the backup
* `BACKUPLOGFILE` name of the logfile besides the backup
* `BACKUPMOUNTPOINT` nfs folder to mount
* `NFSOPTIONS` mount options for NFS

## initial state
currently this backup script is just at a initial state.

## TODOs
* lock file add a lock file if more than one slave should do the backup
* performance.log log the start and end time to check for it
