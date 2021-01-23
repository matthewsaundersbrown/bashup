#!/bin/bash
#
# Bashup - A set of bash scripts for managing backups.
# https://git.stack-source.com/msb/bashup
# MIT License Copyright (c) 2021 Matthew Saunders Brown

# backups are stored here
backup_storage_dir='/mnt/backups';
# directories that are backed up as part of files
backup_dirs=('/etc' '/home' '/srv' '/root' '/usr/local' '/var/www');

# check for local config, which can be used to override any of the above
if [[ -f /usr/local/etc/bashup.cnf ]]; then
  source /usr/local/etc/bashup.cnf
fi

help()
{
  thisfilename=$(basename -- "$0")
  echo "Bashup - A set of bash scripts for managing backups."
  echo "https://git.stack-source.com/msb/bashup"
  echo "MIT License Copyright (c) 2021 Matthew Saunders Brown"
  echo ""
  echo "List backups that have been taken and are available for doing restores."
  echo ""
  echo "Usage: $thisfilename [-b BACKUPDATE] [-c CATEGORY]"
  echo ""
  echo "  -b BACKUPDATE Backup date/archive to list."
  echo "  -c CATEGORY   Category of backup to verify/list."
  echo "  -h            Print this help."
  echo "                If no options are specified a list of backup (dates)"
  echo "                will be displayed. If only the -b option is used then"
  echo "                a list of available categories (directories) will be"
  echo "                displayed. If both -b & -c options are specified then"
  echo "                the specific backups (files/directories, databases,"
  echo "                dns zones) available for restoring will be displayed."
  exit
}

# set any options that were passed
while getopts "b:c:h" opt; do
  case "${opt}" in
    h )
      help
      exit;;
    b )
      backup=${OPTARG}
      ;;
    c )
      category=${OPTARG}
      ;;
    \? )
      echo "Invalid option: $OPTARG" 1>&2
      exit 1;;
    : )
      echo "Invalid option: $OPTARG requires an argument" 1>&2
      exit 1;;
  esac
done


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

if [ ! -z "$backup" ]; then
  if [ -d "$backup_storage_dir/$backup" ]; then
    if [ ! -z "$category" ]; then
      if [ -d "$backup_storage_dir/$backup/$category" ]; then
        if [ "$category" == "files" ]; then
          # check for a list available backup_dirs
          for dir in "${backup_dirs[@]}"; do
            if [ -d $backup_storage_dir/$backup/files$dir ]; then
              echo "$dir"
            fi
          done
        elif [ "$category" == "mysql" ]; then
          # list databases that have dumps available for restoring
          existing_dumps=($(ls $backup_storage_dir/$backup/mysql))
          for existing_dump in "${existing_dumps[@]}"; do
            echo "$(basename $existing_dump .sql.gz)"
          done
        elif [ "$category" == "pdns" ]; then
          # list zones available for restoring
          existing_zones=($(ls $backup_storage_dir/$backup/pdns))
          for existing_zone in "${existing_zones[@]}"; do
            echo "$(basename $existing_zone .zone)"
          done
        else
          # unexpected category, just list contents of dir
          ls -1 $backup_storage_dir/$backup/$category
        fi
      else
        echo "ERROR: Backup $backup_storage_dir/$backup/$category does not exist."
        exit 1
      fi
    else
      # list backup dirs (categories) available for restore
      ls -1 $backup_storage_dir/$backup
    fi
  else
    echo "ERROR: Backup dir for $backup does not exist."
    exit 1
  fi
else
  # output list of backups (dates)
  ls -1 $backup_storage_dir | grep -v lost+found
fi

# check if backup_storage_dir is mounted and unmount if so
grep -qs " $backup_storage_dir " /proc/mounts
if [ $? -eq 0 ]; then
  umount $backup_storage_dir
fi

exit 0
