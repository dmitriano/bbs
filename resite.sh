#!/bin/bash

### Options ###
# export MROOTPASS=****
# export CREATE_REMOTE_USER=1
# export MYSQL8_COMPAT=1


ARCHIVE_FILE=$(pwd)/$1

if [ -z "$MHOST" ]; then
  MHOST="localhost"
  echo "MHOST has been set to $MHOST"
fi

if [ ! -z "$MYSQL8_COMPAT" ]; then
  WITH_CLAUSE="WITH mysql_native_password"
  echo "Creating users $WITH_CLAUSE..."
fi

read -p "enter the site name>" -e SITENAME
if [ -z "$SITENAME" ]; then
SITENAME=$(tar -Oxzf $ARCHIVE_FILE sitename)
echo Using original sitename: $SITENAME
fi

MDB=$SITENAME
MUSER=$SITENAME

if [ -z "$MROOTPASS" ]; then
read -s -p "enter the Root database password>" -e MROOTPASS
echo
fi

if [ -z "$MPASS" ]; then
read -s -p "enter the New database password>" -e MPASS
echo

  if [ -z "$MPASS" ]; then
  MPASS=$(tar -Oxzf $ARCHIVE_FILE mpass)
  echo Using original database password: $MPASS
  fi

fi

MYSQL="$(which mysql)"

LISTING_FILE=$(pwd)/$SITENAME-list.txt

DBDUMP=dbdump.sql
#DBDUMP=$MDB.sql

echo
echo Creating database $MDB and user $MUSER@localhost...

#% does not cover Unix socket communications, that the localhost is for.
$MYSQL -u root -h $MHOST -p$MROOTPASS << EOFMYSQL
CREATE DATABASE $MDB DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;
CREATE USER $MUSER@localhost IDENTIFIED $WITH_CLAUSE BY '$MPASS';
GRANT ALL PRIVILEGES ON $MDB.* TO $MUSER@localhost;
FLUSH PRIVILEGES;
EOFMYSQL

if [ ! -z "$CREATE_REMOTE_USER" ]; then

  echo Creating remote user $MUSER@%...

#% does not cover Unix socket communications, that the localhost is for.
$MYSQL -u root -h $MHOST -p$MROOTPASS << EOFMYSQL
CREATE USER $MUSER@'%' IDENTIFIED $WITH_CLAUSE BY '$MPASS';
GRANT ALL PRIVILEGES ON $MDB.* TO $MUSER@'%';
FLUSH PRIVILEGES;
EOFMYSQL

fi

if [ $? -ne 0 ]; then
	echo "exiting the script."
	exit 1
else
	echo "Done."
fi

echo Restoring database tables...

tar -Oxzf $ARCHIVE_FILE $DBDUMP | $MYSQL -u $MUSER -h $MHOST -p$MPASS $MDB

if [ $? -ne 0 ]; then
	echo "exiting the script."
	exit 1
else
	echo "Done."
fi

echo extracting files: /home/$SITENAME/www ...

cd /home

if [ ! -d "$SITENAME" ]; then
    # Control will enter here if $DIRECTORY doesn't exist.
    echo "Creating home directory $SITENAME"
    mkdir $SITENAME
    chown $SITENAME $SITENAME
    chgrp $SITENAME $SITENAME
else
    echo "User's home directory already exists"
fi

cd $SITENAME

tar -xvzf $ARCHIVE_FILE www --no-same-owner > $LISTING_FILE

if [ $? -ne 0 ]; then
	echo "exiting the script."
	exit 1
else
	echo Site $SITENAME restored successfully.
fi
