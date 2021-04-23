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

bashup::remove_expired_backups pdns
bashup::unmount_storage_dir

exit 0
