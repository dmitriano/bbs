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
echo Deleting user $MUSER and database $MDB...

$MYSQL -u root -h $MHOST -p$MROOTPASS << EOFMYSQL
DROP USER IF EXISTS $MUSER@localhost;
DROP USER IF EXISTS $MUSER@'%';
DROP DATABASE IF EXISTS $MDB;
EOFMYSQL

if [ $? -ne 0 ]; then
	echo "exiting the script."
	exit 1
else
	echo "Done."
fi

echo removing files: /home/$SITENAME/www /home/$SITENAME/apache.conf ...

rm -rf /home/$SITENAME/www

if [ $? -ne 0 ]; then
	echo "exiting the script."
	exit 1
else
	echo Site $SITENAME dropped successfully.
fi
