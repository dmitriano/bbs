#Clean config. Removes all the lines that starts with #
grep '^[[:blank:]]*[^[:blank:]#;]' $1
