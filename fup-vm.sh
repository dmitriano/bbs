#it is FTP Upload Script

ERROR_LOG=$1.ftp.error

export FTP_UPLOAD_SITE=desc
export FTP_UPLOAD_USER=murat
export FTP_UPLOAD_PASSWORD=Ohgh1ienohvu
export FTP_UPLOAD_PATH=tmp

ftp -inv 2> $ERROR_LOG <<EOF
open $FTP_UPLOAD_SITE
user $FTP_UPLOAD_USER $FTP_UPLOAD_PASSWORD
cd $FTP_UPLOAD_PATH
put $1
close
bye
EOF

#error log does not work at the moment
#if [ -f $ERROR_LOG ]
#then
    #echo FTP Failed.
    #error log always is empty - why?
    cat $ERROR_LOG
#else
    #echo $1 uploaded to $FTP_UPLOAD_SITE $FTP_UPLOAD_PATH
#fi

rm $ERROR_LOG
