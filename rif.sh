#does not work for some reason, but command 
#sed -i 's/\/var\/run\/php-fpm\//www-/' *
#works fine
#replace in files (\/ = /)
sed -i 's/$1/$2/' $3
