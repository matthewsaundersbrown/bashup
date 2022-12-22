#!/bin/bash
#
# Bashup - A set of bash scripts for managing backups.
# https://git.stack-source.com/msb/bashup
# MIT License Copyright (c) 2021 Matthew Saunders Brown

# load include file
source $(dirname $0)/bashup.sh

help()
{
  thisfilename=$(basename -- "$0")
  echo "Bashup - A set of bash scripts for managing backups."
  echo "https://git.stack-source.com/msb/bashup"
  echo "MIT License Copyright (c) 2021 Matthew Saunders Brown"
  echo ""
  echo "Restore database from backup."
  echo ""
  echo "Usage: $thisfilename [-b BACKUPDATE] [-d DATABASE]"
  echo ""
  echo "  -b BACKUPDATE Backup date/archive to restore from."
  echo "  -d DATABASE   Database to restore."
  echo "  -h            Print this help."
  echo "                You will be prompted to select backup date and/or"
  echo "                database name from a list of available options"
  echo "                if they are not specified on the command line."
  exit
}

# set any options that were passed
while getopts "b:d:h" opt; do
  case "${opt}" in
    h )
      help
      exit;;
    b )
      backup=${OPTARG}
      ;;
    d )
      database=${OPTARG}
      ;;
    \? )
      echo "Invalid option: $OPTARG" 1>&2
      exit 1;;
    : )
      echo "Invalid option: $OPTARG requires an argument" 1>&2
      exit 1;;
  esac
done

bashup::set_existing_backups

# prompt if backup was not set on command line
if [ -z "$backup" ] ; then
  # select backup to restore from
  PS3="Select number of backup to restore from: "
  existing_backups_len=${#existing_backups[@]}
  select backup in ${existing_backups[@]}
  do
    if [[ $REPLY -gt 0 ]] && [[ $REPLY -le $existing_backups_len ]]; then
      echo $backup
      break
    else
      echo "ERROR: Invalid entry, try again."
    fi
  done
fi

# set dump if database was set via command option
if [ ! -z "$database" ] ; then
  dump="$database.sql.gz"
else
  if [ -d $backup_storage_dir/$backup/mysql ]; then
    # get list of dbs in backup
    existing_dumps=($(ls $backup_storage_dir/$backup/mysql))
    # set array with names of dbs (without .sql.gz suffix)
    declare -a existing_dumps_db_names
    for existing_dump in "${existing_dumps[@]}"; do
      existing_dumps_db_name="$(basename $existing_dump .sql.gz)"
      existing_db_names+=("$existing_dumps_db_name")
    done
    # select database dump to restore
    PS3="Select number of database to restore: "
    existing_db_names_len=${#existing_db_names[@]}
    select database in ${existing_db_names[@]}
    do
      if [[ $REPLY -gt 0 ]] && [[ $REPLY -le $existing_db_names_len ]]; then
        dump=$database.sql.gz
        break
      else
        echo "ERROR: Invalid entry, try again."
      fi
    done
  else
    echo "ERROR: Backup dir for $backup/mysql/  does not exist."
    exit 1
  fi
fi

# check that dump exists and restore it now
if [ -d $backup_storage_dir/$backup ]; then
  if [ -f $backup_storage_dir/$backup/mysql/$dump ]; then
    echo "running:"
    echo "/usr/bin/zcat $backup_storage_dir/$backup/mysql/$dump | mysql --defaults-extra-file=$mysql_defaults_extra_file $database"
    /usr/bin/zcat $backup_storage_dir/$backup/mysql/$dump | mysql --defaults-extra-file=$mysql_defaults_extra_file $database
  else
    echo "ERROR: Dump for database $database does not exist in the $backup backup dir."
    exit 1
  fi
else
  echo "ERROR: Backup dir for $backup does not exist."
  exit 1
fi

bashup::unmount_storage_dir

exit 0
