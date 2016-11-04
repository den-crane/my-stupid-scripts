#!/bin/bash
set -e
set -o pipefail
set -u
#set -x

USERNAME=jiraadmin
PASSWORD=xxxx
INSTANCE=corporation.atlassian.net
S3BUCKET=s3://backupbucket
sdate=`date +%Y%m%d`

if [ "$1" == "wiki" ]; then
  target=wiki
  url=https://${INSTANCE}/wiki/rest/obm/1.0/runbackup
  dest=$S3BUCKET/cloud-wiki/${sdate}/wiki-backup-${sdate}.zip
  progressUrl=https://${INSTANCE}/${target}/rest/obm/1.0/getprogress
  dnlUrl=https://${INSTANCE}/${target}/download
  bkptimeout=300  # minutes (sleep 60)
else
  target=jira
  url=https://${INSTANCE}/rest/obm/1.0/runbackup
  dest=$S3BUCKET/cloud-jira/${sdate}/jira-backup-${sdate}.zip
  progressUrl=https://${INSTANCE}/rest/obm/1.0/getprogress
  dnlUrl=https://${INSTANCE}/webdav/backupmanager
  bkptimeout=300  # minutes (sleep 60)
fi

withattachments=$2
curlcmd='curl --silent --limit-rate 2M -u '$USERNAME':'$PASSWORD' --header "X-Atlassian-Token: no-check"'


echo "Cloud $target backup start `date`"
BKPMSG=`$curlcmd -H "X-Requested-With: XMLHttpRequest" -H "Content-Type: application/json" -X POST $url -d '{"cbAttachments":"'$withattachments'"}'`

if [[ ! -z $BKPMSG ]]; then
  echo ""
  echo "Backup error: $BKPMSG"
  echo ""
  exit 1
fi

divider===================================
divider=$divider$divider
header="\n%8s %-30s %-10s\n"
format="%8d %-30s %-10d\n"
width=55
printf "$header" "Percent" "Status" "Size"
printf "%$width.${width}s\n" "$divider"
prevstr=""

for (( c=1; c<=$bkptimeout; c++ ))
do
  strname=`${curlcmd} ${progressUrl}`
  filename=$(echo $strname|xmllint --xpath "string(//backupresult/@fileName)" - )
  alternativePercentage=$(echo $strname|xmllint --xpath "string(//backupresult/@alternativePercentage)" - )
  percentage=$(echo $alternativePercentage|awk '{print $3}')
  size=$(echo $strname|xmllint --xpath "string(//backupresult/@size)" - )
  currentStatus=$(echo $strname|xmllint --xpath "string(//backupresult/@currentStatus)" - )
  concurrentBackupInProgress=$(echo $strname|xmllint --xpath "string(//backupresult/@concurrentBackupInProgress)" - )
  #echo $concurrentBackupInProgress $percentage $currentStatus $size $filename
  #echo "Percent: $percentage   Status: $currentStatus   Size: $size"
  nextstr=$percentage"$currentStatus"$size
  if [[ $prevstr != $nextstr ]]; then
    printf "$format" $percentage "$currentStatus" $size
    prevstr=$nextstr
  fi

  if [[ $percentage -eq 100 ]]; then
     break
  fi
  sleep 60
done

echo ""
if [ $percentage -ne 100 ];
then
  echo "Error: Waiting for backup end too long."
  exit 1
else
  echo "Cloud $target backup file download started `date`"
  echo "Source filename: $dnlUrl/$filename"
  $curlcmd $dnlUrl/$filename | /root/bin/aws s3 cp - $dest --expected-size=100000000000
  echo "Cloud $target backup file download completed `date`"
  echo "Target filename: $dest"
  tfilesize=`/root/bin/aws s3 ls $dest|awk '{print $3}'`
  echo "Target filesize: $tfilesize"
fi

echo "Cloud $target backup end `date`"
