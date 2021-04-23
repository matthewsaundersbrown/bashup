#!/bin/bash
#
# Bashup - A set of bash scripts for managing backups.
# https://git.stack-source.com/msb/bashup
# MIT License Copyright (c) 2021 Matthew Saunders Brown

# load include file
source $(dirname $0)/bashup.sh

bashup::set-retention_array

# create backup for today
if [[ " ${retention_array[@]} " =~ " ${today} " ]]; then

  # create backup (date) dir if it doesn't already exist
  if [ ! -d "$backup_storage_dir/$today" ]; then

    mkdir $backup_storage_dir/$today

  fi

  # only proceed if mysql has not already been backed up
  if [[ ! -d $backup_storage_dir/$today/mysql ]]; then

    mkdir $backup_storage_dir/$today/mysql
    mysqladmin --defaults-extra-file=$defaults_extra_file refresh

    # create array of all existing databases
    databases=($(mysql --defaults-extra-file=$defaults_extra_file -E -e 'show databases;'|grep : |awk '{ print $2 }' |tr '\n' ' '));

    for database in "${databases[@]}"; do

      if [[ " ${exclusions[@]} " =~ " ${database} " ]]; then
        # do nothing, db is in exclusions array
        one=1;
      else
        mysqldump --defaults-extra-file=$defaults_extra_file --opt --quote-names --events --databases $database | gzip > $backup_storage_dir/$today/mysql/$database.sql.gz
      fi

    done

  fi

fi

bashup::remove_expired_backups mysql
bashup::unmount_storage_dir

exit 0
