#!/usr/bin/env bash

# The MIT License (MIT)
#
# Copyright (c) 2015 Michael Sedlmair - Goodgame Studios <msedlmair@goodgamestudios.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

#get script path. Thx to http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

#GLOBALS
LOGFILE="/var/log/mysqlbackup.sh.log"

IDENTIFIER=$(hostname -f 2>/dev/null || hostname)
BACKUPDATE=$(date '+%Y%m%d')
BACKUPBASE="/data/ephemeral0/backup"
KEEP_DAYS_COUNT="4"
#####Innobackupex
BACKUPEXTARGET="${BACKUPBASE}/${IDENTIFIER}/"
BACKUPEXBIN="/usr/bin/innobackupex"
BACKUPEXOPTIONS=(--slave-info --no-timestamp ${BACKUPEXTARGET}${BACKUPDATE})
POSTBACKUPEXOPTIONS=(--apply-log ${BACKUPEXTARGET}${BACKUPDATE})
#####
TMPLOGFILE="/var/log/mysqlbackup${BACKUPDATE}.sh.log"
BACKUPLOGFILE="${BACKUPEXTARGET}${BACKUPDATE}/mysqlbackup.sh.log"
BACKUPMOUNTPOINT=""
DATADOMAIN=""
NFSOPTIONS=()

# use log4bash
source "${DIR}/lib/log4bash.sh"

# load config if exists. Overwrite defaults
test -f "${DIR}/config.sh" && source "${DIR}/config.sh"
test -f "/etc/ggs/mysqlbackupconfig.sh" && source "/etc/ggs/mysqlbackupconfig.sh"

# redirect to logfile
exec > >(tee -a "${LOGFILE}" "${TMPLOGFILE}")
exec 2>&1

die () {
  MSG=$1
  log_error "${MSG}"
  exit 127
}

do_innobackupexbackup () {
  ${BACKUPEXBIN} "${BACKUPEXOPTIONS[@]}" || die "${BACKUPEXBIN} ${BACKUPEXOPTIONS} wasn't successful"
}

do_applylog () {
  ${BACKUPEXBIN} "${POSTBACKUPEXOPTIONS[@]}" || die "${BACKUPEXBIN} ${POSTBACKUPEXOPTIONS} wasn't successful"
}

nfs_mount () {
  if [[ "${BACKUPMOUNTPOINT}" != "" ]]; then
    if [[ "${DATADOMAIN}" != "" ]]; then
      log "mounting ${DATADOMAIN}:${BACKUPMOUNTPOINT}/${IDENTIFIER} to ${BACKUPBASE}/${IDENTIFIER}"
      test -d "${BACKUPBASE}/${IDENTIFIER}" || mkdir -p "${BACKUPBASE}/${IDENTIFIER}" || die "can't create backup mount"
      mount -t nfs "${NFSOPTIONS[@]}" "${DATADOMAIN}:${BACKUPMOUNTPOINT}/${IDENTIFIER}" "${BACKUPBASE}/${IDENTIFIER}" || true
    else
      log "mounting ${BACKUPMOUNTPOINT}/${IDENTIFIER} to ${BACKUPBASE}/${IDENTIFIER}"
      test -d "${BACKUPBASE}/${IDENTIFIER}" || mkdir -p "${BACKUPBASE}/${IDENTIFIER}" || die "can't create backup mount"
      mount -t nfs "${NFSOPTIONS[@]}" "${BACKUPMOUNTPOINT}/${IDENTIFIER}" "${BACKUPBASE}/${IDENTIFIER}" || true
    fi
  fi
}

pre_backup () {
  nfs_mount
  log "checking target dir..."
  test -d "$BACKUPEXTARGET${BACKUPDATE}" && die "target dir already exists"
  if mkdir -p "$BACKUPEXTARGET"; then
    log "created target dir ${BACKUPEXTARGET}${BACKUPDATE}"
  else
    die "can't create dir ${BACKUPEXTARGET}${BACKUPDATE}"
  fi
}

backup () {
  log "starting backup to ${BACKUPEXTARGET}${BACKUPDATE}"
  do_innobackupexbackup "backup"
}

applylog () {
  log "apply transaction log to prepare backup"
  do_applylog "preparing"
}

post_backup () {
  log "clean up phase - only keep last ${KEEP_DAYS_COUNT} files"
  ls -t "${BACKUPBASE}/${IDENTIFIER}/" | sed -e "1,${KEEP_DAYS_COUNT}d" | xargs -d '\n' rm -rf
  log "copying logfile into backup"
  cp "${TMPLOGFILE}" "${BACKUPLOGFILE}"
  tar czf "${BACKUPEXTARGET}${BACKUPDATE}.tar.gz" -C "${BACKUPEXTARGET}${BACKUPDATE}" "../${BACKUPDATE}" --remove-files
}

main () {
  pre_backup
  backup
  applylog
  post_backup
}


main
