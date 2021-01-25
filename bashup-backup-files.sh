#!/bin/bash
#
# Bashup - A set of bash scripts for managing backups.
# https://git.stack-source.com/msb/bashup
# MIT License Copyright (c) 2021 Matthew Saunders Brown

# retention vars
retention_years=0;
retention_months=3;
retention_weeks=5;
retention_days=7;
# backup storage directory
backup_storage_dir='/mnt/backups';
# directories to be backed up
backup_dirs=('/etc' '/home' '/srv' '/root' '/usr/local' '/var/www');

# check for local config, which can be used to override any of the above
if [[ -f /usr/local/etc/bashup.cnf ]]; then
  source /usr/local/etc/bashup.cnf
fi

# require root
if [ "${EUID}" -ne 0 ]; then
  echo "This script must be run as root"
  exit 1
fi

if [ ! -d $backup_storage_dir ]; then
  echo "ERROR: Backup storage dir ($backup_storage_dir) does not exist."
  exit 1
fi

# check if backup_storage_dir is a mount in fstab
grep -qs " $backup_storage_dir " /etc/fstab
if [ $? -eq 0 ]; then
  # check if backup_storage_dir is already mounted
  grep -qs " $backup_storage_dir " /proc/mounts
  if [ $? -ne 0 ]; then
    # attempt to mount backups
    mount $backup_storage_dir
    # re-check for backups mount
    grep -qs " $backup_storage_dir " /proc/mounts
    if [ $? -ne 0 ]; then
      echo "ERROR: failed to mount $backup_storage_dir"
      exit 1
    fi
  fi
fi

# set more vars based on above settings
today=$(date +%Y%m%d)
existing_backups=($(ls $backup_storage_dir|grep -v lost+found))
# remove today from existing backups, if it exists. we do other checks later to avoid re-doing backups
if [[ " ${existing_backups[@]} " =~ " ${today} " ]]; then
  unset 'existing_backups[-1]';
fi

# create retention array
declare -a retention_array

# set retention days
if [ $retention_days -gt 0 ]; then
  i="0"
  while [ $i -lt $retention_days ]; do
    DATE=`date --date="$i day ago" +%Y%m%d`
    retention_array[$DATE]="$DATE"
    i=$[$i+1]
  done
fi

# set retention weeks
if [ $retention_weeks -gt 0 ]; then
  i="0"
  while [ $i -lt $retention_weeks ]; do
    i=$[$i+1]
    DATE=`date --date="sunday - $i week" +%Y%m%d`
    retention_array[$DATE]="$DATE"
  done
fi

# set retention months
if [ $retention_months -gt 0 ]; then
  i="0"
  while [ $i -lt $retention_months ]; do
    DATE=`date --date="$i month ago" +%Y%m01`
    retention_array[$DATE]="$DATE"
    i=$[$i+1]
  done
fi

# set retention years
if [ $retention_years -gt 0 ]; then
  i="0"
  while [ $i -lt $retention_years ]; do
    DATE=`date --date="$i year ago" +%Y0101`
    retention_array[$DATE]="$DATE"
    i=$[$i+1]
  done
fi

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

# check if backup_storage_dir is mounted and unmount if so
grep -qs " $backup_storage_dir " /proc/mounts
if [ $? -eq 0 ]; then
  umount $backup_storage_dir
fi

exit 0

