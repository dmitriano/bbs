#!/bin/bash

SCRIPT_SOURCE="${BASH_SOURCE[0]}"
SCRIPT_DIR="$( dirname "$SCRIPT_SOURCE" )"

read -p "enter the site name>" -e SITENAME

#SITENAME=$(id | sed -e "s/^uid=[0-9]*(\([a-zA-Z0-9]*\)).*$/\1/")

MDB=$SITENAME
MUSER=$SITENAME
MHOST="localhost"

DBDUMP=dbdump.sql

#extract database password from Joomla config file

JOOMLA_CONFIGFILE=/home/$SITENAME/www/configuration.php
WORDPRESS_CONFIGFILE=/home/$SITENAME/www/wp-config.php

#echo $WORDPRESS_CONFIGFILE
#exit 0

if [ -f $JOOMLA_CONFIGFILE ]; then

	echo "Backing up Joomla site '$SITENAME'. ('$JOOMLA_CONFIGFILE')"

	MPASS=$(grep 'var $password =' $JOOMLA_CONFIGFILE | sed -e "s/^\s*var \$password\s*=\s*'\(.*\)';$/\1/")

	JOOMLA_VERSION="1.5"

	if [ "$MPASS" == "" ]; then

		JOOMLA_VERSION="1.6/1.7"

		MPASS=$(grep 'public $password =' $JOOMLA_CONFIGFILE | sed -e "s/^\s*public \$password\s*=\s*'\(.*\)';$/\1/")

        	if [ $MPASS == "" ]; then
			echo "Unable to retrieve database password, probably something is wrong with the config file"
			exit 1
		fi
	fi

	echo "Joomla version: $JOOMLA_VERSION";
else
if [ -f $WORDPRESS_CONFIGFILE ]; then

        echo "Backing up WordPress site '$SITENAME'. ('$WORDPRESS_CONFIGFILE')"

	MPASS=$(sed -n "/define('DB_PASSWORD', '/s/.*, '\([^']*\).*/\1/p" $WORDPRESS_CONFIGFILE)

	MDB=$(sed -n "/define('DB_NAME', '/s/.*, '\([^']*\).*/\1/p" $WORDPRESS_CONFIGFILE)

	MUSER=$(sed -n "/define('DB_USER', '/s/.*, '\([^']*\).*/\1/p" $WORDPRESS_CONFIGFILE)

	MHOST=$(sed -n "/define('DB_HOST', '/s/.*, '\([^']*\).*/\1/p" $WORDPRESS_CONFIGFILE)

	TABLE_PREFIX=$(sed -n "/\$table_prefix  = '/s/.*= '\([^']*\).*/\1/p" $WORDPRESS_CONFIGFILE)

        if [ $MPASS == "" ]; then
		echo "Unable to retrieve database password, probably something is wrong with the config file"
                exit 1
	fi

	echo "Database name: '$MDB',  User name: $MUSER, Host: $MHOST"

else
	echo "Unable to determine what CMS is used."

	read -s -p "Please enter the database password manually>" -e MPASS
fi
fi

#echo $MPASS

#exit 0

#now we have all required information

MYSQLDUMP="$(which mysqldump)"
NOW=$(date +"%Y-%m-%d-%H%M")
ARCHIVE_FTP_FILE=$SITENAME.$NOW.tar
ARCHIVE_FILE=$(pwd)/$ARCHIVE_FTP_FILE
LISTING_FILE=$(pwd)/$SITENAME-list.txt

read -p "enter the archive comment>" -e ACOMMENT

echo Dumping the database...

$MYSQLDUMP -u $MUSER -h $MHOST -p$MPASS $MDB --no-tablespaces | sed -e 's/DEFINER=[^*]*\*/\*/' > $DBDUMP

if [ $? -ne 0 ]; then
	echo "exiting the script."
	exit 1
else
	echo "Done."
fi

echo Creating tar archive...

cd /home/$SITENAME

#/etc/apache2/sites-available/$SITENAME $SHARED_WWW - is not accessible anymore
tar cvf $ARCHIVE_FILE www > $LISTING_FILE

if [ $? -ne 0 ]; then
	rm $DBDUMP
	echo "exiting the script."
	exit 1
else
	echo "Done."
fi

cd -

tar rvf $ARCHIVE_FILE $DBDUMP

if [ $? -ne 0 ]; then
	rm $DBDUMP
	echo "exiting the script."
	exit 1
else
	echo "Done."
fi

rm $DBDUMP

if [ "$ACOMMENT" != "" ]; then
	echo $ACOMMENT > comment.txt

	tar rvf $ARCHIVE_FILE comment.txt

	if [ $? -ne 0 ]; then
		rm $DBDUMP
		echo "exiting the script."
		exit 1
	else
		echo "comment.txt file added to the archive"
	fi

	rm comment.txt
fi

#add mpass file
        echo $MPASS > mpass

        tar rvf $ARCHIVE_FILE mpass

        if [ $? -ne 0 ]; then
                rm $DBDUMP
                echo "exiting the script."
                exit 1
        else
                echo "mpass file added to the archive"
        fi

        rm mpass

#add sitename file
        echo $SITENAME > sitename

        tar rvf $ARCHIVE_FILE sitename

        if [ $? -ne 0 ]; then
                rm $DBDUMP
                echo "exiting the script."
                exit 1
        else
                echo "sitename file added to the archive"
        fi

        rm sitename

echo "gzipping..."

gzip $ARCHIVE_FILE

if [ $? -ne 0 ]; then
	echo "exiting the script."
	exit 1
else
	echo Archive $ARCHIVE_FILE.gz created successfully.
fi

chmod o-r $ARCHIVE_FILE.gz

#echo Uploading the archive to the FTP server...

#$SCRIPT_DIR/fup.sh $ARCHIVE_FTP_FILE.gz $SITENAME

echo Done.
