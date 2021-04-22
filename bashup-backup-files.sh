#!/bin/bash
#
# Bashup - A set of bash scripts for managing backups.
# https://git.stack-source.com/msb/bashup
# MIT License Copyright (c) 2021 Matthew Saunders Brown

# load include file
source $(dirname $0)/bashup.sh

bashup::set_existing_backups
bashup::set_retention_array

# create backup for today
if [[ " ${retention_array[@]} " =~ " ${today} " ]]; then

  # create backup (date) dir if it doesn't already exist
  if [[ ! -d "$backup_storage_dir/$today" ]]; then

    mkdir $backup_storage_dir/$today

  fi

  # only proceed if files have not already been backed up
  if [[ ! -d "$backup_storage_dir/$today/files" ]]; then

    # create files backup dir
    mkdir $backup_storage_dir/$today/files

    for dir in "${backup_dirs[@]}"; do

      #only proceed if source dir exits
      if [[ -d $dir ]]; then

        # only proceed if dir has not already been backed up
        if [[ ! -d $backup_storage_dir/$today/files$dir ]]; then

          # check if existing_backups is not empty, and if so if the dir to back up exists in the previous backup
          if [[ ${existing_backups[@]} && -d $backup_storage_dir/${existing_backups[-1]}/files$dir ]]; then

            # make parent destination dir, if it doesn't exist
            if [[ ! -d $backup_storage_dir/$today/files`dirname $dir` ]]; then

              mkdir -p $backup_storage_dir/$today/files`dirname $dir`

            fi

            # create a hard-link copy of the backup before doing rsync
            cp --archive --link $backup_storage_dir/${existing_backups[-1]}/files$dir $backup_storage_dir/$today/files$dir

          fi

          # backup up files with rsync, updating existing hard link copy if it exists
          rsync --relative --archive --numeric-ids --one-file-system --delete $dir $backup_storage_dir/$today/files

        fi

      else

        echo "NOTICE: Dir $dir does not exist, can not perform backup."

      fi

    done

  fi

fi

# remove expired backups
for existing_backup in "${existing_backups[@]}"; do

  if [[ " ${retention_array[@]} " =~ " ${existing_backup} " ]]; then

    # keep $existing_backup, do nothing
    one=1;

  else

    if [[ -d $backup_storage_dir/$existing_backup/files ]]; then

      rm -r $backup_storage_dir/$existing_backup/files

    fi

    if [[ -z "$(ls -A $backup_storage_dir/$existing_backup)" ]]; then

      rm -r $backup_storage_dir/$existing_backup

    fi

  fi

done

bashup::unmount_storage_dir

exit 0

