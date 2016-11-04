# my-stupid-scripts

upload2s3.sh -- upload to S3 N files from dir D older than T with speed limited X

proxmox_backup.sh -- backup all running proxmox VMs to aws s3 (directly without local files)

gce_backup2s3.sh -- Google cloud engine VMs backup to s3

jira_backup.sh -- backup cloud jira/wiki to s3 (1st arg = jira/wiki; 2nd arg = w/ attachments )
  * ./jira_backup.sh wiki true   # backup wiki w/ attachments
  * ./jira_backup.sh jira false  # backup wiki w/o attachments
