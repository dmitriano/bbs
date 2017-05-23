SN=$1

cd /var/log/nginx

goaccess -f $SN.access.log -s

