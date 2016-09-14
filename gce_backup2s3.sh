#!/bin/bash
set -e
set -o pipefail
set -u
export PATH=/usr/local/bin:/usr/local/sbin:$PATH
backupdisksrcname=$1
bckpname=image`date +%Y%m%d%H%M%S`
vmname=`hostname`
dest=s3://bucket/${bckpname}.gz

echo "GCE backup start `date`"

gcloud config set compute/zone "us-central1-a"
gcloud compute disks snapshot "${backupdisksrcname}" --snapshot-names "${bckpname}" -q
gcloud compute disks create "${bckpname}" --source-snapshot "${bckpname}" --type "pd-standard" -q
gcloud compute instances attach-disk "${vmname}" --disk "${bckpname}" --mode ro
echo "Backup filename: ${dest}"
cat /dev/sdb|gzip -4 | aws s3 cp - $dest --expected-size=100000000000

gcloud compute instances detach-disk "${vmname}" --disk "${bckpname}"
gcloud compute disks delete "${bckpname}" -q


echo "GCE backup end `date`"



