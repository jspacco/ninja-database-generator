#!/bin/bash

for i in {1..2}; do
    ruby ninjas2.rb 200000 $i > ninjas.sql
    sqlite3 ninjas$i.db < ninjas.sql
done

