#!/bin/bash
#
# Bashup - A set of bash scripts for managing backups.
# https://git.stack-source.com/msb/bashup
# MIT License Copyright (c) 2021 Matthew Saunders Brown

# begin configurable vars

# retention vars
retention_years=0;
retention_months=3;
retention_weeks=5;
retention_days=7;

# backup storage directory
backup_storage_dir='/mnt/backups';

# which backup scripts to run via bashup-cron.sh - options are 'files', 'mysql', 'pdns', 'postgres'
bashup_jobs=('files' 'mysql');

# directories to be backed up by files
backup_dirs=('/etc' '/home/' '/root' '/srv/' '/usr/local' '/var/www/');
# to back up an entire directory do *not* add a trailing slash
# if you add a trailing slash then instead of backing up that directory itself
# a list of all subdirectories is generated and added to the array
# note that with a trailing slash files in the top level directory itself will *not* be backed up,
# only the subdirectories within it

# mysql config file that contains 'host' 'user' 'password' vars
mysql_defaults_extra_file='/etc/mysql/debian.cnf';

# list of mysql databases to skip
mysql_exclusions=('information_schema' 'performance_schema' 'sys' 'wsrep');

# postgres backup method - options are 'basebackup', 'dump', 'dumpall'
# basebackup makes an exact copy of the entire database cluster's files
# dump creates individual sql dumps of each database
# dumpall creates a single sql dump of all databases in one file
# multiple methods can be specified
pg_method=('basebackup' 'dump');

# list of postgres databases to skip when using method 'dump'
pg_dump_exclusions=('template0');

# end configurable vars

# check for local config, which can be used to override any of the above
if [[ -f /usr/local/etc/bashup.conf ]]; then
  source /usr/local/etc/bashup.conf
fi

# must be root, attempt sudo if need be
if [ "${EUID}" -ne 0 ]; then
  exec sudo -u root --shell /bin/bash $0 $@
fi

# check backup_dirs for tailing slash (subdir option)
i=0
for dir in "${backup_dirs[@]}"; do
  if grep -qs '/$' <<< "$dir"; then
    # found match, first remove dir from array
    unset "backup_dirs[$i]"
    # check for subdirs
    if [[ -d $dir ]]; then
      subdirs=(`ls -1 $dir`)
      if [[ ${#subdirs[@]} -gt 0 ]]; then
        for subdir in "${subdirs[@]}"; do
          if [[ -d "$dir$subdir" ]]; then
            backup_dirs+=("$dir$subdir")
          fi
        done
      fi
    fi
  fi
  ((i++))
done

# check for backup storage directory and mount if need be
if [ -d $backup_storage_dir ]; then
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
else
  echo "ERROR: Backup storage dir ($backup_storage_dir) does not exist."
  exit 1
fi

# get todays date (backup dir name)
today=$(date +%Y%m%d)

# set existing_backups array
existing_backups=($(ls $backup_storage_dir|grep -v lost+found))
# if script is a *-backup-* script remove today from existing backups, if it exists. we do other checks avoid re-doing backups
if [[ "$0" == *"-backup-"* ]];then
  if [[ " ${existing_backups[@]} " =~ " ${today} " ]]; then
    unset 'existing_backups[-1]';
  fi
fi

function bashup::set-retention_array () {

  declare -a -g retention_array

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

}

function bashup::remove_expired_backups () {

  # check for and set directory var
  if [ -n "$1" ]; then
    directory=$1
  else
    echo "ERROR: directory var not set"
    return 1
  fi

  # safety check, make sure retention_array is not empty
  retention_array_len=${#retention_array[@]}

  if [[ $retention_array_len -gt 0 ]]; then

    for existing_backup in "${existing_backups[@]}"; do

      if [[ " ${retention_array[@]} " =~ " ${existing_backup} " ]]; then

        # keep $existing_backup, do nothing
        one=1;

      else

        if [[ -d $backup_storage_dir/$existing_backup/$directory ]]; then

          rm -r $backup_storage_dir/$existing_backup/$directory

        fi

        if [[ -z "$(ls -A $backup_storage_dir/$existing_backup)" ]]; then

          rm -r $backup_storage_dir/$existing_backup

        fi

      fi

    done

  else

    echo "WARNING: retention array empty or not set."
    return 1

  fi

}

function bashup::unmount_storage_dir () {
  # check if backup_storage_dir is mounted and unmount if so
  grep -qs " $backup_storage_dir " /proc/mounts
  if [ $? -eq 0 ]; then
    umount $backup_storage_dir
  fi
}
