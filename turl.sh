#touch URL (prints 200 with curl, and nothing with wget)
#curl -o /dev/null --silent --head --write-out '%{http_code}' "$1"
wget -q -O /dev/null -o /dev/null $1
