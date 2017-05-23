SN=$1

cd /var/log/nginx

(cat $SN.access.log $SN.access.log.1 && zcat $SN.access.log.*.gz)
