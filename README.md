# Bashup

A set of bash scripts for managing backups.

## Overview

Bashup includes scripts for backing up & restoring Files/Directories, MySQL databases, and PowerDNS zones.

The scripts assume a mountable backup disk (cloud based block storage, NFS mount, dedicated local partion, etc.) but work equally a local backup directory. If the backup dir is configured in /etc/fstab as a mountable disk then it will automatically be mounted and then unmounted when the scripts run.

For "files" backups a combination of rsync & hard links is used. This conserves space as files that are unchanged simply reference the same indode instead of having duplicate files.

It is intended that each of the desired "backup" scripts is run once a day via cron. The scripts can be re-run multiple times in one day without any negative repercussions. If an existing backup already exists it is simply skipped, it is not overwritten with a newer copy.

The "restore" scripts can be run interatively. If you do not specify options for the restore then you will be prompted with menus of options to help you select what to restore. If the appropriate options are specified on the command line then the restore will be completed without prompts.

Built and tested on Ubuntu 20.04 these scripts should run fine on any current Debian or Debian based distro without any modifications. It should be trivial to expand support for other distros too, please contact the author if there is interest in this.

## Quickstart

Create a backup directory or mount. For example, make a directory named /mnt/backups, create an NFS mount for that directory, and configure it in /etc/fstab. Include the "noauto" option in fstab so that it is not automatically mounted, the scripts will take care of mounting the device as needed.

```bash
cd /usr/local/src/
wget https://git.stack-source.com/msb/bashup/archive/master.tar.gz -O bashup.tar.gz
tar zxvf bashup.tar.gz
cd bashup
cp bashup-*.sh /usr/local/sbin/
chmod 750 /usr/local/sbin/bashup-*.sh
chown root:root /usr/local/sbin/bashup-*.sh
nano /usr/local/etc/bashup.cnf
crontab -e
```

The "nano /usr/local/etc/bashup.cnf" command is optional. Do this if you need to override any of the settings at the top of the bashup scripts.

For the crontab add an entry for each of the "backup" scripts that you'd like to run. For example, to back up files at 3:01 am every day add this crontab:

`1 3    * * *   /usr/local/sbin/bashup-backup-files.sh`
