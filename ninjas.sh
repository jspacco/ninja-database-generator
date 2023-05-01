#!/bin/bash

filename="a.txt"

i=1
if [ -f "$filename" ]; then
    while read line; do
        echo $line $i
        ruby ninjas2.rb 10 $i > ninjas.sql
        sqlite3 db3/$line.db < ninjas.sql
        ((i++))
    done < "$filename"
fi

exit

for i in {36..36}; do
    #ruby ninjas2.rb 300000 $i > ninjas.sql
    sqlite3 db2/ninjas$i.db < ninjas.sql
    echo $i
done

