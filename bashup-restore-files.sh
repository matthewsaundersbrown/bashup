#!/bin/bash
#
# Bashup - A set of bash scripts for managing backups.
# https://git.stack-source.com/msb/bashup
# MIT License Copyright (c) 2021 Matthew Saunders Brown

# backup storage directory
backup_storage_dir='/mnt/backups';
# directories to be backed up
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
# Still in testing mode, display command instead of running it
"To restore $pathtorestore from $backup run this command:"
echo "/usr/bin/rsync -vn --archive --numeric-ids --one-file-system --delete $pathtobackup $pathtorestore"

# check if backup_storage_dir is mounted and unmount if so
/usr/bin/grep -qs " $backup_storage_dir " /proc/mounts
if [ $? -eq 0 ]; then
  /usr/bin/umount $backup_storage_dir
fi

exit 0
