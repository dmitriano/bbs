#!/bin/bash

SITENAME=$1

sudo ln -s /etc/nginx/sites-available/$SITENAME /etc/nginx/sites-enabled/$SITENAME

