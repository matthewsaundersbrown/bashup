# Bashup

A set of bash scripts for managing backups.

## Quickstart

Create a backup directory or mount. For example, make a directory named /mnt/backups and create an NFS mount for that directory.

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
For the crontab add an entry for each of the "bashup-backup-*.sh" scripts that you'd like to run. For example, to back up files at 3:01 am every day add this crontab:
`1 3    * * *   /usr/local/sbin/bashup-backup-files.sh`
