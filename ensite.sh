#!/bin/bash

read -p "enter the site name>" -e SITENAME

sudo ln -s /home/$SITENAME/apache.conf /etc/apache2/sites-enabled/$SITENAME.conf


