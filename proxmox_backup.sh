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

if [ "$pvVer" == "pve-manager/3.4" ]
then
  cntrCntZero=`(vzlist 2>&1|grep -c "Container(s) not found")||true`
  if [ $cntrCntZero -eq 1 ]  
     then
       vmlist=`qm list|awk '$3 == "running" {print $1"|"$2"|qemu"}'` 
     else
       vmlist=`vzlist |awk '$3 == "running" {print $1"|"$5"|openvz"}';qm list|awk '$3 == "running" {print $1"|"$2"|qemu"}'`
  fi
else 
  vmlist=`qm list|awk '$3 == "running" {print $1"|"$2"|qemu"}'`  
fi

vmcnt=0
for vm in $vmlist;
do
  ((vmcnt+=1))
done

echo "$vmcnt running VM(s) found. Backup start `date`"
echo ""

bkpcnt=0
for vm in $vmlist; 
do 
    id=`echo $vm|awk -F"|" '{print $1}'`
    vmname=`echo $vm|awk -F"|" '{print $2}'`
    type=`echo $vm|awk -F"|" '{print $3}'`
    echo ""
    echo "*******************************************************************************************"
    awsfile=$targetdir/vzdump-$type-$id-$vmname.vma.gz
    echo "Backup of $id - $vmname ($type) to $awsfile started."
    set +e
    /usr/bin/vzdump $id -mode snapshot --dumpdir $tmpdir --compress gzip --quiet --stdout|pv -q --rate-limit $uploadspeed|$aws s3 cp - $awsfile --expected-size=100000000000
    exitcode=$?
    set -e
    if [ "$exitcode" -ne 0 ]
        then 
          message="******* FAIL *******"
        else 
          message="######## OK ########" 
          ((bkpcnt+=1))
    fi  
    echo ""
    echo "Backup of $id - $vmname completed. $message."
    echo "*******************************************************************************************"
    echo ""
done
echo "$bkpcnt VM(s) of $vmcnt successfully backed up. Backup complete `date`"
) 2>&1) | tee $logfile

