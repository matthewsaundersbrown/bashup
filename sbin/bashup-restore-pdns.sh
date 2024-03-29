#!/bin/bash
#
# Bashup - A set of bash scripts for managing backups.
# https://git.stack-source.com/msb/bashup
# MIT License Copyright (c) 2021 Matthew Saunders Brown

# load include file
source $(dirname $0)/bashup.sh

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

bashup::set_existing_backups

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
    echo "running:"
    echo "/usr/bin/pdnsutil load-zone $zone $backup_storage_dir/$backup/pdns/$zone_file"
    /usr/bin/pdnsutil load-zone $zone $backup_storage_dir/$backup/pdns/$zone_file
  else
    echo "ERROR: Zone file for zone $zone does not exist in the $backup backup dir."
    exit 1
  fi
else
  echo "ERROR: Backup dir for $backup does not exist."
  exit 1
fi

bashup::unmount_storage_dir

exit 0
