#!/bin/bash


# file containing usernames of all students in the class
students="students.txt"
#students="a.txt"

# number of total attacks each ninjas makes
num_rows=30000
#num_rows=10

# file containing names for the ninjas, hopefully drawn from students through a Google Form
ninja_names="name1.txt"

seed=5
if [ -f "$students" ]; then
    while read username; do
        echo $username $seed
        ruby ninjas2.rb $num_rows $ninja_names $seed > ninjas.sql
        sqlite3 db/$username.db < ninjas.sql
        ((seed++))
    done < "$students"
fi


