#!/bin/bash

### Uncomment the DEBUG line to get debug logs ###
#DEBUG="TRUE"

ECHO=/bin/echo
DATE=/bin/date
HOST=/bin/hostname

AWK=/usr/bin/awk
BKP=/opt/MXB/bin/ClientTool
GREP=/usr/bin/grep
HEAD=/usr/bin/head
MYSQL=/usr/bin/mysqldump
OCC=/var/www/nextcloud/occ
PHP=/usr/bin/php
SUDO=/usr/bin/sudo
TR=/usr/bin/tr

APP_DIR=/var/www/nextcloud
DATA_DIR=/nextcloud

USER="www-data"

BINARIES=($AWK $BKP $GREP $HEAD $MYSQL $OCC $PHP $SUDO $TR)
FOLDERS=($APP_DIR $DATA_DIR)

log() {
    time=`${DATE}` || exit 1
    name=`${HOST}` || exit 1
    if [ ! -z "$DEBUG" ]; then
        if [ "$1" = "DEBUG" ]; then
            log_debug "$2"
            return 0
        fi
    else
        if [ "$1" = "DEBUG" ]; then
            return 1
        fi
    fi
    ${ECHO} "$time $name [$1] $2"
}

log_debug() {
    ${ECHO} "$time $name [DEBUG] $1"
}

root_check() {
    if [[ "$EUID" -ne 0 ]]; then
        log "ERROR" "Are you running as root?"
        exit 1001
    fi
}

check_file() {
    [ -f "$1" ] || { log "ERROR" "Cannot find $1! Cannot continue!"; exit 1001; }
}

check_folder() {
    [ -d "$1" ] || { log "ERROR" "Cannot find $1! Cannot continue!"; exit 1002; }
}

set_maintenance() {
    if [[ "$1" = "on" ]]; then
        STATUS="enabled"
    else
        STATUS="disabled"
    fi
    RESULT=$(${SUDO} -u ${USER} ${PHP} ${OCC} maintenance:mode --"$1")
    log "DEBUG" "Result of setting maintenance mode: $RESULT"
    if [[ ! "$RESULT" =~ .*"Maintenance mode $STATUS" ]]; then
        log "ERROR" "Unable to set maintenance mode correctly! Cannot continue!"
        exit 1003
    fi
}

get_config() {
    ${GREP} "$1" "$APP_DIR/config/config.php" | ${AWK} '{ print $3 }' | ${TR} -d "',"
}

mysql_dump() {
    DBHOST="localhost"
    DBUSER=$(get_config "dbuser")
    DBPASS=$(get_config "dbpass")
    DBNAME=$(get_config "dbname")
    RESULT=$(${MYSQL} --single-transaction -h "$DBHOST" -u "$DBUSER" -p"$DBPASS" "$DBNAME" > "$DATA_DIR/nextcloud_dump.sql")
    log "DEBUG" "Result of running MySQL dump: $RESULT"
    [ ! -z "$RESULT" ] && { log "ERROR" "Unable to create MySQL dump file! Cannot continue!"; exit 1004; }
}

run_backup() {
    RESULT=$(${BKP} control.backup.start)
    ${ECHO} "$RESULT"
}

backup_status() {
    RESULT=$(${BKP} control.session.list | ${GREP} "Backup" | ${HEAD} -n1 | ${AWK} '{ print $3 }')
    ${ECHO} "$RESULT"
}

backup_report() {
    RESULT=$(${BKP} control.session.list | ${GREP} "Backup" | ${HEAD} -n1)
    STATE=$(${ECHO} "$RESULT" | ${AWK} '{ print $3 }')
    PROCS=$(${ECHO} "$RESULT" | ${AWK} '{ print $11 }')
    PROCC=$(${ECHO} "$RESULT" | ${AWK} '{ print $12 }')
    ERRC=$(${ECHO} "$RESULT" | ${AWK} '{ print $14 }')
    log "INFO" "Backup complete with status: $STATE after processing $PROCS in size and $PROCC files with $ERRC error(s)!"
}

begin() {
    log "INFO" "Starting script..."

    log "INFO" "Starting root check..."
    log "DEBUG" "Comparing EUID: $EUID against 0..."
    root_check
    log "INFO" "Root check complete!"

    log "INFO" "Starting dependencies check..."
    for i in ${!BINARIES[@]}; do
        log "DEBUG" "Checking if ${BINARIES[i]} exists..."
        check_file ${BINARIES[i]}
    done
    log "INFO" "Dependency check complete!"

    log "INFO" "Starting NextCloud directory check..."
    for i in ${!FOLDERS[@]}; do
        log "DEBUG" "Checking if ${FOLDERS[i]} exists..."
        check_folder ${FOLDERS[i]}
    done
    log "INFO" "NextCloud directory check complete!"
}

main() {
    log "INFO" "Starting backup..."

    log "INFO" "Placing NextCloud instance into maintenance mode..."
    set_maintenance "on"
    log "INFO" "Maintenance mode enabled!"

    log "INFO" "Creating MySQL dump file..."
    mysql_dump
    log "INFO" "MySQL dump file created successfully!"

    log "INFO" "Running backup with the N-Able Backup Manager Client Tool..."
    RESULT=$(run_backup)
    log "DEBUG" "Result of run_backup function: $RESULT"
    if [[ ! "$RESULT" =~ .*"Starting backup for" ]]; then
        log "ERROR" "Unable to start backup with N-Able Backup Manager Client Tool! Consider enabling DEBUG logging..."
        exit 1009
    fi
    log "DEBUG" "Sleeping for 5 seconds starting now..."
    sleep 5 # give the ClientTool time to change it's status away from Idle, there's a weird delay here
    STATUS="InProgress"
    while [ "$STATUS" != "Completed" ]; do
        log "INFO" "Backup is currently running..."
        STATUS=$(backup_status)
        log "DEBUG" "Status is: $STATUS"
        sleep 1 # just check every second, no need to spam this check
    done
    log "INFO" "Backup complete!"

    log "INFO" "Removing NextCloud instance from maintenance mode..."
    set_maintenance "off"
    log "INFO" "Maintenance mode disabled!"
}

end() {
    log "INFO" "Compiling Backup statistics..."
    backup_report
    log "INFO" "End script..."
}

begin
main
end
