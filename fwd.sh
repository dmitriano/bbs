#finds writable files

USERNAME=$(id | sed -e "s/^uid=[0-9]*(\([a-zA-Z0-9]*\)).*$/\1/")

find . -type d \( -user $USERNAME -perm -g=w \) 
