#!/bin/bash
### MySQL Server Login Info ###
read -p "enter the site name>" -e SITENAME
MDB=$SITENAME
MUSER=$SITENAME
if [ -z "$MROOTPASS" ]; then
    read -s -p "enter the Root database password>" -e MROOTPASS
fi
MHOST="localhost"
MYSQL="$(which mysql)"

echo
echo Deleting $MUSER@localhost...

$MYSQL -u root -h $MHOST -p$MROOTPASS << EOFMYSQL
DROP USER $MUSER@$MHOST;
DROP DATABASE IF EXISTS $MDB;
EOFMYSQL

if [ $? -ne 0 ]; then
	echo "exiting the script."
	exit 1
else
	echo "Done."
fi

echo removing files: /home/$SITENAME/www /home/$SITENAME/apache.conf ...

sudo rm -r /home/$SITENAME/www

if [ $? -ne 0 ]; then
	echo "exiting the script."
	exit 1
else
	echo Site $SITENAME dropped successfully.
fi

