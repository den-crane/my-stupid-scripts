uppload2s3.sh
#!/bin/bash
set -e
set -o pipefail
set -u
export PATH=/usr/local/bin:/usr/local/sbin:$PATH

filesagedays=8
source=/Volumes/RAIDBOX/SHARE
dest=s3://dump

uploadcount=100
uploadspeed=5M

echo `date` Upload started.
for i in $(find $source -type f -mtime +$filesagedays -name '*'|head -n $uploadcount); do
    f=`basename $i`
    echo uploading $i
    pv -q --rate-limit $uploadspeed $i | aws s3 cp - $dest/$f && rm $i
done
echo `date` Upload ended.
