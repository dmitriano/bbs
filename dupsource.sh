src_name=$1
dst_name=$2
unset $1
cp $src_name.* ~/temp/
cd ~/temp/
rename "s/$src_name\.([a-z]+)/$dst_name\.\$1/" *
cd -
mv ~/temp/$dst_name.* .

