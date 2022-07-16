# Bashup

A set of bash scripts for managing backups.

## Overview

Bashup includes scripts for backing up and restoring Files & Directories, MySQL/MariaDB databases, and PowerDNS zones.

The scripts assume a mountable backup disk (cloud based block storage, NFS mount, dedicated local partion, etc.) but work equally well with a local backup directory. If the backup dir is configured in /etc/fstab as a mountable disk then it will automatically be mounted and then unmounted when the scripts run.

For "files" backups a combination of rsync & hard links is used. This conserves space as files that are unchanged simply reference the same inode instead of having duplicate files.

The systemd timer runs the desired "backup" scripts once per day. The scripts can also be run manually. They can be re-run multiple times in one day without any negative repercussions. If an existing backup already exists it is simply skipped, it is not overwritten with a newer copy.

The "restore" scripts can be run interactively. If you do not specify options for the restore then you will be prompted with menus of options to help you select what to restore. If the appropriate options are specified on the command line then the restore will be completed without prompts.

Built and tested on Ubuntu 20.04 these scripts should run fine on any current Debian or Debian based distro without any modifications. It should be trivial to expand support for other distros too, please contact the author if there is interest in this.

## Quickstart

Create a backup directory or mount. For example, make a directory named /mnt/backups, create an NFS mount for that directory, and configure it in /etc/fstab. Include the "noauto" option in fstab so that it is not automatically mounted, the scripts will take care of mounting the device as needed.

```bash
# download and install the bashup scripts
cd /usr/local/src/
wget https://git.stack-source.com/msb/bashup/archive/master.tar.gz -O bashup.tar.gz
tar zxvf bashup.tar.gz
cd bashup
cp sbin/bashup*.sh /usr/local/sbin/
chmod 755 /usr/local/sbin/bashup*.sh
chown root:root /usr/local/sbin/bashup*.sh
# install & enable bashup systemd cron
cp systemd/bashup-cron.* /usr/lib/systemd/system/
chmod 644 /usr/lib/systemd/system/bashup-cron.*
systemctl enable bashup-cron.timer
systemctl start bashup-cron.timer
# customize configuration
nano /usr/local/etc/bashup.conf
```

The "nano /usr/local/etc/bashup.conf" command is optional. Do this if you need to override any of the default configurable settings found at the top of the /usr/local/sbin/bashup.sh script.
