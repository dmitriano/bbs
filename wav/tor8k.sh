for file in *.wav
do
  echo "$file"
  sox -r 8000 "$file" out/"$file" speed 5.5
done
