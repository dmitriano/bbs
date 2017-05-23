#!/bin/bash
### MySQL Server Login Info ###

read -p "enter the site name>" -e SITENAME

if [ -z "$MROOTPASS" ]; then
read -s -p "enter the Root database password>" -e MROOTPASS
echo
fi
if [ -z "$MPASS" ]; then
read -s -p "enter the New database password>" -e MPASS
echo
fi

MDB=$SITENAME
MUSER=$SITENAME
MHOST=localhost
MDB=$SITENAME
MUSER=$SITENAME


echo
echo Creating database $MDB and user $MUSER@$MHOST...

mysql -u root -h $MHOST -p$MROOTPASS << EOFMYSQL
CREATE DATABASE $MDB DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;
CREATE USER $MUSER@$MHOST IDENTIFIED BY '$MPASS';
GRANT USAGE ON *.* TO  $MUSER@$MHOST IDENTIFIED BY '$MPASS' WITH MAX_QUERIES_PER_HOUR 0 MAX_CONNECTIONS_PER_HOUR 0 MAX_UPDATES_PER_HOUR 0 MAX_USER_CONNECTIONS 0;
GRANT ALL PRIVILEGES ON $MDB.* TO $MUSER@$MHOST;
EOFMYSQL

if [ $? -ne 0 ]; then
	echo "MySQL has reported some errors. Exiting the script."
	exit 1
else
	echo "Database $MDB created successfully."
fi
