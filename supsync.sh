#aptitude update > update-output.txt
#(yes '' | aptitude safe-upgrade > upgrade-output.txt)
apt-get update
#apt-get --with-new-pkgs upgrade
apt-get dist-upgrade
