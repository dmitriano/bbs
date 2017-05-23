SOURCE="${BASH_SOURCE[0]}"
DIR="$( dirname "$SOURCE" )"

echo $DIR

$DIR/fup.sh slogpost-list.txt

echo Done.
