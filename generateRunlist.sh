#!/bin/bash

# Takes in a standard logGen format runlist file and outputs a file in stage 6 format

processDir="processDir"
subDir=""
tableDir=$USERSPACE/tables
suffix=""
extension=".stage4.root"
winterEA="winterEA"
summerEA="summerEA"

while getopts s:d:e: FLAG; do
    case $FLAG in
	s)
	    spectrum=$OPTARG
	    ;;
	d) 
	    processDir=$OPTARG
	    ;;
	e)  
	    extension=$OPTARG
	    ;;
	?) #unrecognized option - show help
	    echo -e "Option -${BOLD}$OPTARG${NORM} not allowed."
	    ;;
  esac # option cases
done # getopts loop
shift $((OPTIND-1))  #This tells getopts to move on to the next argument.

if [ $1 ]; then
    inFile=$1
else
    echo "Must specify input loggen file!"
    exit 1 # failure
fi

if [ "$spectrum" == "soft" ]; then
    winterEA="$tableDir/ea_Oct2012_na_ATM21_vegasv250rc5_7sam_Alloff_s200t2_std_MSW1p1_MSL1p3_MH7_ThetaSq0p03_LZA.root"
    summerEA="$tableDir/ea_Oct2012_na_ATM22_vegasv250rc5_7sam_Alloff_s200t2_std_MSW1p1_MSL1p3_MH7_ThetaSq0p03_LZA.root"
elif [ "$spectrum" == "medium" ]; then
    winterEA="$tableDir/ea_Oct2012_na_ATM21_vegasv250rc5_7sam_Alloff_s400t2_std_MSW1p1_MSL1p3_MH7_ThetaSq0p01_LZA.root"
    summerEA="$tableDir/ea_Oct2012_na_ATM22_vegasv250rc5_7sam_Alloff_s400t2_std_MSW1p1_MSL1p3_MH7_ThetaSq0p01_LZA.root"
elif [ "$spectrum" == "hard" ]; then
    winterEA="$tableDir/ea_Oct2012_na_ATM21_vegasv250rc5_7sam_Alloff_s1000t2_std_MSW1p1_MSL1p4_ThetaSq0p01_LZA_v1.root"
    summerEA="$tableDir/ea_Oct2012_na_ATM22_vegasv250rc5_7sam_Alloff_s1000t2_std_MSW1p1_MSL1p4_ThetaSq0p01_LZA.root"
elif [ "$spectrum" == "loose" ]; then
    winterEA="$tableDir/ea_Oct2012_na_ATM21_vegasv250rc5_7sam_050off_s200t2_std_MSW1p15_MSL1p4_ThetaSq0p03_LZA.root"
    summerEA="$tableDir/ea_Oct2012_na_ATM22_vegasv250rc5_7sam_050off_s200t2_std_MSW1p15_MSL1p4_ThetaSq0p03_LZA.root"
fi

#if [ $2 ]; then
#    outFile="$2"
#    outFileRedir=" >> $2"
#    if [ -f $outFile ]; then
#	echo "overwrite $outFile ?"
#	read response
#	if [ response = "Y" ]; then
#	    mv $outFile $HOME/.trash/
#	fi
#   fi
#    echo "writing to $outFile!"
#fi # if output file is specified

groupNum=(0)
incrementGroup="false"
# first find winter runs
while read line
do
  set -- $line

  runDate=$1
  runNum=$2

  runMonth=$(( (runDate % 10000 - runDate % 100) / 100 ))
  if (( runMonth < 5 || runMonth > 10 )); then
      echo "${processDir}/${subDir}/${runNum}${suffix}${extension}" $outFileRedir
      incrementGroup="true"
  fi

done < $inFile # find winter runs

if [ "$incrementGroup" = "true" ]; then
    echo "[EA ID: ${groupNum}]" $outFileRedir
    echo "$winterEA" $outFileRedir
    echo "[/EA ID: ${groupNum}]" $outFileRedir
    echo "[CONFIG ID: ${groupNum}]" $outFileRedir
    echo "[/CONFIG ID: ${groupNum}]" $outFileRedir
    groupNum=$((groupNum+1))
fi

incrementGroup="false"
first="true"
# then find summer runs
while read line
do
  set -- $line

  runDate=$1
  runNum=$2

  runMonth=$(( (runDate % 10000 - runDate % 100) / 100 ))
  if (( runMonth >= 5 && runMonth <= 10 )); then
      if [ "$first" == "true" ]; then
	  first="false"
	  incrementGroup="true"
	  if (( groupNum > 0 )); then
	      echo "[RUN ID: ${groupNum}]" $outFileRedir
	  fi
      fi
      echo "${processDir}/${subDir}/${runNum}${suffix}${extension}" $outFileRedir
  fi

done < $inFile # find summer runs

if [ "$incrementGroup" == "true" ]; then
    if (( groupNum > 0 )); then
	echo "[/RUNLIST ID: ${groupNum}]" $outFileRedir
    fi
    echo "[EA ID: ${groupNum}]" $outFileRedir
    echo "$summerEA" $outFileRedir
    echo "[/EA ID: ${groupNum}]" $outFileRedir
    echo "[CONFIG ID: ${groupNum}]" $outFileRedir
    echo "[/CONFIG ID: ${groupNum}]" $outFileRedir
    groupNum=$((groupNum+1))
fi

if [ $outFile ]; then
    cat $outFile
fi

exit 0 # success
