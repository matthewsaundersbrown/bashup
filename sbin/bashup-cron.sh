#!/bin/bash
#
# Bashup - A set of bash scripts for managing backups.
# https://git.stack-source.com/msb/bashup
# MIT License Copyright (c) 2022 Matthew Saunders Brown

# load include file
source /usr/local/sbin/bashup.sh

for job in "${bashup_jobs[@]}"; do
  if [[ -x /usr/local/sbin/bashup-backup-$job.sh ]]; then
    /usr/local/sbin/bashup-backup-$job.sh
  fi
done
