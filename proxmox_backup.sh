#!/bin/bash
set -e
set -o pipefail
set -u
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH

aws=/usr/local/bin/aws
uploadspeed=5M
d=`date +%Y%m%d`
tmpdir=/space/tmp
targetdir=s3://proxmox/$d
logfile=/root/proxmox_backup_log/backup_$d.log

((

pvVer=`pveversion|cut -c 1-15`

if [ "$pvVer"=="pve-manager/3.4" ]
then
  cntrCntZero=`(vzlist 2>&1|grep -c "Container(s) not found")||true`
  if [ $cntrCntZero -eq 1 ]  
     then
       vmlist=`qm list|awk '$3 == "running" {print $1"|"$2}'` 
     else
       vmlist=`vzlist |awk '$3 == "running" {print $1"|"$5}';qm list|awk '$3 == "running" {print $1"|"$2}'`
  fi
else 
  vmlist=`qm list|awk '$3 == "running" {print $1"|"$2}'`  
fi

echo "Backup start `date`"
for vm in $vmlist; 
do 
    id=`echo $vm|awk -F"|" '{print $1}'`
    vmname=`echo $vm|awk -F"|" '{print $2}'`
    awsfile=$targetdir/vzdump-$id-$vmname.vma.gz
    echo "Backup of $id - $vmname to $awsfile started."
    /usr/bin/vzdump $id -mode snapshot --dumpdir $tmpdir --compress gzip --quiet --stdout|pv -q --rate-limit $uploadspeed|$aws s3 cp - $awsfile
    echo ""
    echo "**************************************************"
    echo "Backup of $id - $vmname completed. ########### OK."
    echo "**************************************************"
    echo ""
done
echo "Backup complete `date`"
) 2>&1) | tee $logfile

