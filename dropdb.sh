#!/bin/bash
### MySQL Server Login Info ###

read -p "enter the site name>" -e SITENAME

read -s -p "enter the New database password>" -e MPASS
echo
read -s -p "enter the Root database password>" -e MROOTPASS
echo

MDB=$SITENAME
MUSER=$SITENAME

if [ -z "$MHOST" ]; then
  MHOST="localhost"
  echo "MHOST has been set to $MHOST"
fi

MDB=$SITENAME
MUSER=$SITENAME

echo
echo Removing database $MDB and user $MUSER@$MHOST...

mysql -u root -h $MHOST -p$MROOTPASS << EOFMYSQL
DROP USER $MUSER@$MHOST;
DROP DATABASE IF EXISTS $MDB;
EOFMYSQL

if [ $? -ne 0 ]; then
	echo "MySQL has reported some errors. Exiting the script."
	exit 1
else
	echo "Database $MDB removed successfully."
fi
