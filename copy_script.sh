#!/bin/bash

mvLaser="false"
mvStage1="false"
mvStage2="false"
mvStage4="false"
mvStage5="true"
mvStage6="false"

baseDataDir="/veritas/data/"
processDir="${VEGASWORK}/processed/"
destinationDir="mbuchove@128.97.69.2:/DataDrive/BDT/Train_Z10/"

if [ $1 ]
then
    readList="$1"
else
    echo "no runlist specified"
    exit
fi

commandString="scp"

while read -r line
do

    set -- $line

    runNum=$2
    laserNum=$3

    rootName_1="${processDir}/${runNum}.stage1.root"
    rootName_2="${processDir}/${runNum}.stage2.root"
    rootName_4="${processDir}/${runNum}.stage4.root"
    rootName_5="${processDir}/${runNum}.stage5.root"

    if [ $mvStage1 = "true" ]; then
	if [ -f $rootName_1 ]; then
	    commandString="$commandString $rootName_1"
	fi
    fi

    if [ $mvStage2 = "true" ]; then
	if [ -f $rootName_2 ]; then
	    commandString="$commandString $rootName_2"
	fi		
    fi

    if [ $mvStage4 = "true" ]; then
	if [ -f $rootName_4 ]; then
	    commandString="$commandString $rootName_4"
	fi

    fi

    if [ $mvStage5 = "true" ]; then
	if [ -f $rootName_5 ]; then
	    commandString="$commandString $rootName_5"
	fi
    fi
    
done < $readList

commandString="$commandString $destinationDir"

echo $commandString

exit 0 # success
