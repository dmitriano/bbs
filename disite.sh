#!/bin/bash

read -p "enter the site name>" -e SITENAME

sudo rm /etc/apache2/sites-enabled/$SITENAME.conf

