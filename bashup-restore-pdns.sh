#!/bin/bash
#
# Bashup - A set of bash scripts for managing backups.
# https://git.stack-source.com/msb/bashup
# MIT License Copyright (c) 2021 Matthew Saunders Brown

# backup directory
backup_storage_dir='/mnt/backups';

# check for local config, which can be used to override any of the above
if [[ -f /usr/local/etc/bashup.cnf ]]; then
  source /usr/local/etc/bashup.cnf
fi

# require root
if [ "${EUID}" -ne 0 ]; then
  echo "This script must be run as root"
  exit 1
fi

help()
{
  thisfilename=$(basename -- "$0")
  echo "Bashup - A set of bash scripts for managing backups."
  echo "https://git.stack-source.com/msb/bashup"
  echo "MIT License Copyright (c) 2021 Matthew Saunders Brown"
  echo ""
  echo "Restore database from backup."
  echo ""
  echo "Usage: $thisfilename [-b BACKUPDATE] [-z ZONE]"
  echo ""
  echo "  -b BACKUPDATE Backup date/archive to restore from."
  echo "  -z ZONE       DNS Zone to restore."
  echo "  -h            Print this help."
  echo "                You will be prompted to select backup date and/or"
  echo "                zone name from a list of available options"
  echo "                if they are not specified on the command line."
  exit
}

# set any options that were passed
while getopts "b:z:h" opt; do
  case "${opt}" in
    h )
      help
      exit;;
    b )
      backup=${OPTARG}
      ;;
    z )
      zone=${OPTARG}
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

# get list of backups (dates)
existing_backups=($(ls $backup_storage_dir|grep -v lost+found))

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

# set zone_file
if [ ! -z "$zone" ] ; then
  zone_file="$zone.zone"
else
  if [ -d $backup_storage_dir/$backup/pdns ]; then
    # get list of zones in backup
    existing_zones=($(ls $backup_storage_dir/$backup/pdns))
    # set array with names of zones (without .zone suffix)
    declare -a existing_zone_names
    for existing_zone in "${existing_zones[@]}"; do
      existing_zone_name="$(basename $existing_zone .zone)"
      existing_zone_names+=("$existing_zone_name")
    done
    # select zone dump to restore
    PS3="Select number of zone to restore: "
    existing_zone_names_len=${#existing_zone_names[@]}
    select zone in ${existing_zone_names[@]}
    do
      if [[ $REPLY -gt 0 ]] && [[ $REPLY -le $existing_zone_names_len ]]; then
        zone_file=$zone.zone
        break
      else
        echo "ERROR: Invalid entry, try again."
      fi
    done
  else
    echo "ERROR: Backup dir for $backup/pdns/ does not exist."
    exit 1
  fi
fi

# check that dump exists and restore it now
if [ -d $backup_storage_dir/$backup ]; then
  if [ -f $backup_storage_dir/$backup/pdns/$zone_file ]; then
    # Still in testing mode, display command instead of running it
    echo "To restore zone $zone from backup $backup run this command:"
    echo "/usr/bin/pdnsutil load-zone $zone $backup_storage_dir/$backup/pdns/$zone_file"
#     echo "SUCCESS: Zone $zone from backup $backup has been restored."
  else
    echo "ERROR: Zone file for zone $zone does not exist in the $backup backup dir."
    exit 1
  fi
else
  echo "ERROR: Backup dir for $backup does not exist."
  exit 1
fi

# check if backup_storage_dir is mounted and unmount if so
grep -qs " $backup_storage_dir " /proc/mounts
if [ $? -eq 0 ]; then
  umount $backup_storage_dir
fi

exit
