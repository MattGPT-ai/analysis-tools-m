#!/bin/bash

loop() {

    readMode=$1
    
    for file in `ls`; do
	#pattern to be determine move
	if [ `echo $file | grep -o "stage" | wc -l ` -eq 0 ]; then
	    newName=`echo $file | sed -e 's/.txt/_laser.txt/g'`
	    if [ $readMode = "listOnly" ]; then
		echo "$file -> $newName"
	    elif [ $readMode = "move" ]; then
		mv $file $newName
	    fi
	fi
    done

} # loop

echo "The following moves will be made: "

loop listOnly

echo "If this is okay, enter 'Y'"
read response

if [ $response = "Y" ]; then
    loop move
fi

exit 0 # success 
