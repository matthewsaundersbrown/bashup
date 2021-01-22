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
# mysql config file that contains 'host' 'user' 'password' vars
defaults_extra_file='/etc/mysql/debian.cnf';
# list of databases to skip
exclusions=('information_schema' 'performance_schema' 'sys' 'wsrep');

# check for local config, which can be used to override any of the above
if [[ -f /usr/local/etc/bashup.cnf ]]; then
  source /usr/local/etc/bashup.cnf
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

# get todays date (backup dir name)
today=$(date +%Y%m%d)

# get list of existing backups
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

# remove expired backups
for existing_backup in "${existing_backups[@]}"; do

  if [[ " ${retention_array[@]} " =~ " ${existing_backup} " ]]; then

    # keep $existing_backup, do nothing
    one=1;

  else

    if [[ -d $backup_storage_dir/$existing_backup/mysql ]]; then

      rm -r $backup_storage_dir/$existing_backup/mysql

    fi

    if [ -z "$(ls -A $backup_storage_dir/$existing_backup)" ]; then

      rm -r $backup_storage_dir/$existing_backup

    fi

  fi

done

# check if backup_storage_dir is mounted and unmount if so
grep -qs " $backup_storage_dir " /proc/mounts
if [ $? -eq 0 ]; then
  umount $backup_storage_dir
fi

exit 0;
