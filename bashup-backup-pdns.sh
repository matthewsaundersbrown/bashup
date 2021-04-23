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

  # only proceed if pdns zones have not already been backed up
  if [[ ! -d $backup_storage_dir/$today/pdns ]]; then

    mkdir $backup_storage_dir/$today/pdns

    zones=(`/usr/bin/pdnsutil list-all-zones`)

    for zone in "${zones[@]}"; do

      /usr/bin/pdnsutil list-zone $zone > "$backup_storage_dir/$today/pdns/$zone.zone"

    done

  fi

fi

# remove expired backups
for existing_backup in "${existing_backups[@]}"; do

  if [[ " ${retention_array[@]} " =~ " ${existing_backup} " ]]; then

    # keep $existing_backup, do nothing
    one=1;

  else

    if [[ -d $backup_storage_dir/$existing_backup/pdns ]]; then

      rm -r $backup_storage_dir/$existing_backup/pdns

    fi

    if [ -z "$(ls -A $backup_storage_dir/$existing_backup)" ]; then

      rm -r $backup_storage_dir/$existing_backup

    fi

  fi

done

bashup::unmount_storage_dir

exit 0
