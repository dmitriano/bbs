for file in *.wav
do
  #echo ../s1/"$file"
  sox "$file" -b16 ../s1/"$file"
done

#sox Sounds/$1 -b16 s1/%1

