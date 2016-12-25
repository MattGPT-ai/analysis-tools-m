#!/bin/bash

runMode=cat
DistanceUpper=1.38

while getopts qr: FLAG; do 
    case $FLAG in
	q)
	    runMode=qsub ;; 
	r) 
	    runMode=bash
	    teePipe=" | tee $logFile";; 
	?)
	    echo "Option -${BOLD}${OPTARG}${NORM} not allowed"
    esac # option cases
done # while loop over options 
shift $((OPTIND-1))

if [ $2 ]; then 
    array=$1
    atm=$2
else
    echo "Usage: ${0##*/} [options] array atmosphere"
fi
# test -z "$2" && atm=$2 || atm=22

spectrum=medium # just to satisfy setCuts.sh
source ${0/${0##*/}/}/setCuts.sh
setCuts

if [ $3 ]; then 
    buildOptions="$3"
else
    buildOptions="-TelID=0,1,2,3 -Azimuth=0,45,90,135,180,225,270,315 -Zenith=00,20,30,35,40,45,50,55,60,65 -AbsoluteOffset=0.00,0.50,0.75,0.25,1.00,1.25,1.50,1.75,2.00 -Noise=$pedVars"
fi

tableList=$VEGASWORK/config/tableList_lt_${array}_ATM${atm}.txt
finalTableName=lt_Oct2012_${array}_ATM${atm}_7samples_vegas254_allOffsets_LZA_d${DistanceUpper/./p}.root
finalTableFile=$VEGASWORK/tables/${finalTableName}
buildCmd="buildLTTree $buildOptions $finalTableFile"

logFile=$VEGASWORK/tables/log/combine_lt_${array}_ATM${atm}_d${DistanceUpper/./p}_allOffsets_LZA.txt
if [ $runMode != "cat" ]; then
    test -f $logFile && mv $logFile $VEGASWORK/backup/logTable/
fi
  
# commence #$teePipe
$runMode <<EOF 

#PBS -l nodes=1,mem=4gb,walltime=5:00:00
#PBS -j oe
#PBS -o $logFile 
#PBS -N combine_lt_${array}_ATM${atm}_allOffsets_LZA

read -r firstTable < $tableList

cp \$firstTable \${firstTable}.backup

trap "mv \${firstTable}.backup \$firstTable" EXIT 
# trap signals 

cd $VEGAS/showerReconstruction2/macros/
root -l -b -q 'combo.C("$tableList", "$buildCmd")'

mv \$firstTable $finalTableFile
$buildCmd

# decided to check tables after they're made, not before they're combined

root -l -b -q 'validate.C("$finalTableFile")'

if [ -s ${finalTableFile/root/diag} ] || [ ! -f ${finalTableFile/root/diag} ]; then 
    echo "SOME MIGHT FAIL!! check .diag files"
else
    rm ${finalTableFile/root/diag}
    rsync -uv $finalTableFile $TABLEDIR/${finalTableName}
fi # diag file contains bad tables or wasn't created
#( test -s diag || -f diag ) && echo error || rm ${finalTableFile/root/diag} ?&& rsync 

EOF

exit 0 # great job 
