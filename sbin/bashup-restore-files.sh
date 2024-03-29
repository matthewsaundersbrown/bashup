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
  echo "Restore file(s) from backup."
  echo ""
  echo "Usage: $thisfilename [-b BACKUPDATE] [-p PATH]"
  echo ""
  echo "  -b BACKUPDATE Backup date/archive to restore from."
  echo "  -p PATH       Path to file or directory to restore."
  echo "  -h            Print this help."
  echo "                You will be prompted to select backup date and file"
  echo "                or directory if not specified on the command line"
  echo "                with the above options."
  exit
}

# set any options that were passed
while getopts "b:p:h" opt; do
  case "${opt}" in
    h )
      help
      exit;;
    b )
      backup=${OPTARG}
      ;;
    p )
      pathtorestore=${OPTARG}
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

# set path to file or directory to restore
if [ -z "$pathtorestore" ] ; then
  if [ -d $backup_storage_dir/$backup/files ]; then
    # select backup file or directory to restore
    PS3="Select number of backup directory to restore from: "
    backup_dirs_len=${#backup_dirs[@]}
    select backup_dir in ${backup_dirs[@]}
    do
      if [[ $REPLY -gt 0 ]] && [[ $REPLY -le $backup_dirs_len ]]; then
        echo "Complete path to specific file or directory to restore."
        read -e -p "Just press enter to recursively restore entire dir: " -i $backup_storage_dir/$backup/files$backup_dir pathtobackup
        pathtorestore=${pathtobackup#"$backup_storage_dir/$backup/files"}
        break
      else
        echo "ERROR: Invalid entry, try again."
      fi
    done
  else
    echo "ERROR: Backup dir for $backup/files/ does not exist."
    exit 1
  fi
else
  pathtobackup="$backup_storage_dir/$backup/files$pathtorestore"
fi

if [ -d $pathtobackup ]; then
  # restore is a direcotry, make sure paths end in a slash (/) for proper rsync
  if [[ ! "$pathtobackup" == */ ]]; then
    pathtobackup="$pathtobackup/"
  fi
  if [[ ! "$pathtorestore" == */ ]]; then
    pathtorestore="$pathtorestore/"
  fi
elif [ ! -f $pathtobackup ]; then
  # restore is not a file nor a direcotry, does not exist
  echo "ERROR: Backup file/directory ($pathtobackup) does not exist."
  exit 1
fi

# make sure parent dir of destination exists
if [ ! -d $(/usr/bin/dirname $pathtorestore) ]; then
  echo "ERROR: Parent directory missing for restore location."
  exit 1
fi

# make sure pathtorestore is for a file/dir *within* one of the backup_dirs
verify_back_dir=FALSE
for dir in "${backup_dirs[@]}"; do
  if  [[ $pathtorestore == $dir ]] || [[ $pathtorestore == $dir* ]]; then
    verify_back_dir=TRUE
  fi
done
if  [[ $verify_back_dir == FALSE ]]; then
  echo "ERROR: File or directory to restore does not exist within one of the backed up directories."
  exit 1
fi

# perform restore
echo "Running:"
echo "/usr/bin/rsync -v --archive --numeric-ids --one-file-system --delete $pathtobackup $pathtorestore"
/usr/bin/rsync -v --archive --numeric-ids --one-file-system --delete $pathtobackup $pathtorestore

bashup::unmount_storage_dir

exit 0
