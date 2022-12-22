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

  # only proceed if postgresql has not already been backed up
  if [[ ! -d $backup_storage_dir/$today/postgres ]]; then

    install --owner=postgres --group=postgres --mode=750 --directory $backup_storage_dir/$today/postgres

    if [[ " ${pg_method[@]} " =~ " basebackup " ]]; then

      su -c "pg_basebackup --pgdata=- --format=tar --gzip --wal-method=fetch > $backup_storage_dir/$today/postgres/pg_basebackup.sql.tar.gz" postgres

    fi

    if [[ " ${pg_method[@]} " =~ " dump " ]]; then

      pg_databases=(`su -c "psql --command='SELECT datname FROM pg_database;' --csv|grep -v datname" postgres|tr '\n' ' '`)

      for database in "${pg_databases[@]}"; do

        if [[ " ${pg_dump_exclusions[@]} " =~ " ${database} " ]]; then
          # do nothing, db is in pg_dump_exclusions array
          one=1;
        else
          su -c "pg_dump --clean --create $database | gzip > $backup_storage_dir/$today/postgres/$database.sql.gz" postgres
        fi

      done


    fi

    if [[ " ${pg_method[@]} " =~ " dumpall " ]]; then

      su -c "pg_dumpall --clean | gzip > $backup_storage_dir/$today/postgres/pg_dumpall.sql.gz" postgres

    fi

  fi

fi

bashup::remove_expired_backups pg
bashup::unmount_storage_dir

exit 0
