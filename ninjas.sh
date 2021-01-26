#!/bin/bash

for i in {1..34}; do
    ruby ninjas2.rb 200000 $i > ninjas.sql
    sqlite3 db/ninjas$i.db < ninjas.sql
    echo $i
done

