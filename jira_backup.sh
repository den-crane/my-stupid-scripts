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
sdatetime=`date +%Y%m%d%H%M%S`

if [ "$1" == "wiki" ]; then
  target=wiki
  url=https://${INSTANCE}/wiki/rest/obm/1.0/runbackup
  dest=$S3BUCKET/cloud-wiki/${sdate}/wiki-backup-${sdatetime}.zip
  progressUrl=https://${INSTANCE}/${target}/rest/obm/1.0/getprogress.json
  dnlUrl=https://${INSTANCE}/${target}/download/
  cookiefln=wikicookie
  bkptimeout=600  # minutes (sleep 60)
else
  target=jira
  url=https://${INSTANCE}/rest/obm/1.0/runbackup
  dest=$S3BUCKET/cloud-jira/${sdate}/jira-backup-${sdatetime}.zip
  progressUrl=https://${INSTANCE}/rest/obm/1.0/getprogress.json
  dnlUrl=https://${INSTANCE}
  cookiefln=jiracookie
  bkptimeout=600  # minutes (sleep 60)
fi

rm -f $cookiefln
withattachments=$2

curl --silent --cookie-jar $cookiefln -X POST "https://${INSTANCE}/rest/auth/1/session" -d "{\"username\": \"$USERNAME\", \"password\": \"$PASSWORD\"}" -H 'Content-Type: application/json' --output /dev/null


curlcmd='curl -L --silent --cookie '$cookiefln' --limit-rate 2M --header "X-Atlassian-Token: no-check"'


echo "Cloud $target backup start `date`" 
BKPMSG=`$curlcmd -H "X-Requested-With: XMLHttpRequest" -H "Content-Type: application/json" -X POST $url -d '{"cbAttachments":"'$withattachments'"}'` 

if [[ ! -z $BKPMSG ]]; then
  echo ""
  echo "Backup error: $BKPMSG"
  echo ""
  exit 1
fi

divider==========================================
divider=$divider$divider
header="\n%-30s %-30s %-10s\n"
format="%-30s %-30s %-10s\n"
width=70
printf "$header" "%" "Status" "Size"
printf "%$width.${width}s\n" "$divider"
prevstr=""
success=false
 
for (( c=1; c<=$bkptimeout; c++ ))
do
  strname=`${curlcmd} ${progressUrl}`
#  echo ""
#  echo $strname
#  echo ""
  filename=$(echo $strname|jq -r '.fileName')
  failedMessage=$(echo $strname|jq -r '.failedMessage')
  alternativePercentage=$(echo $strname|jq -r '.alternativePercentage')
  size=$(echo $strname|jq -r '.size' )
  currentStatus=$(echo $strname|jq -r '.currentStatus')
  concurrentBackupInProgress=$(echo $strname|jq -r '.concurrentBackupInProgress')
  nextstr=$"$alternativePercentage""$currentStatus"
  if [[ $prevstr != $nextstr ]]; then
    printf "$format" "$alternativePercentage" "$currentStatus" $size
    prevstr=$nextstr
  fi

  if [[ $failedMessage != null ]]; then
     echo "Error: "$failedMessage". Status: "$currentStatus
     exit 1
  fi

  if [[ $filename != null ]]; then
     success=true
     break
  fi

  sleep 60
done

echo "" 
if [ $success != true ];
then
  echo "Error: Waiting for backup end too long."
  exit 1
else
  echo "Cloud $target backup file download started `date`"
  echo "Source filename: $dnlUrl$filename"
  $curlcmd $dnlUrl$filename | /root/bin/aws --region us-east-1 s3 cp - $dest --expected-size=100000000000
  echo "Cloud $target backup file download completed `date`"
  echo "Target filename: $dest"
  tfilesize=`/root/bin/aws --region us-east-1 s3 ls $dest|awk '{print $3}'`
  echo "Target filesize: $tfilesize"
fi

rm -f $cookiefln
echo "Cloud $target backup end `date`"
