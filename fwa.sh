#finds writable files

USERNAME=$(id | sed -e "s/^uid=[0-9]*(\([a-zA-Z0-9]*\)).*$/\1/")

if [ ! -z $1 ]; then
        POSTFIX=' -iname "$1"'
fi

find . \( -user $USERNAME -perm -g=w \)$POSTFIX

