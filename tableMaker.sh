#!/bin/bash

mode=disp
runMode=print

array=V6
atm=22
simulation=CORSIKA

DistanceUpper=1.38

azimuths="0,45,90,135,180,225,270,315"
noiseLevels="100,150,200,250,300,350,400,490,605,730,870"
zeniths="55,60,65"
offset=all
offset=0.75

fileList=$HOME/work/SgrA_dt_simlist.txt

workDir=$GC

#add environment option
args=`getopt -o qr -l offsets:,atm:,fileList:,array:,mode:,distance:,testname:,zeniths: -- $*`
eval set -- $args
for i; do 
    case "$i" in 
	-r) 
	    runMode=run ; shift ;;
	-q) 
	    runMode=qsub ; shift ;;
	--mode)
	    mode="$2" ; shift 2 ;;
	--offsets) 
	    offset="$2" ; shift 2 ;;
	--atm) 
	    atm="$2" ; shift 2 ;;
	--fileList) 
	    fileList="$2" ; shift 2 ;;
	--array) 
	    array="$2" ; shift 2 ;;
	--distance)
	    DistanceUpper="$2" ; shift 2 ;;
	--zeniths)
	    zeniths="$2" ; shift 2 ;; 
	--testname) 
	    testnameflag="_${2}" ; shift 2 ;; 
	--) 
	    shift ; break ;;
    esac # argument cases
done # loop over i in args
if [ $1 ]; then
    mode="$1"
fi

if [ ! -d $workDir/log/tables ]; then
    echo "Must create table $workDir/log/tables !!!"
    #mkdir $workDir/log/tables
    exit 1
fi

cuts="-SizeLower=0/0 -DistanceUpper=0/${DistanceUpper} -NTubesMin=0/5"

case "$array" in
    V4) 
	noise="3.62,4.45,5.13,5.71,6.21,6.66,7.10,7.83,8.66,9.49,10.34"
	model=MDL8OA_V4_OldArray ;;
    V5) 
	noise="4.29,5.28,6.08,6.76,7.37,7.92,8.44,9.32,10.33,11.32,12.33"
	model=MDL15NA_V5_T1Move ;;
    V6) 
	noise="4.24,5.21,6.00,6.68,7.27,7.82,8.33,9.20,10.19,11.17,12.17" 
	model=MDL10UA_V6_PMTUpgrade ;;
    *) 
	echo "Array $array not recognized! Choose either V4, V5, or V6!!"
	exit 1
        ;;
esac

test "$offset" == all && offsets="0.25 0.50 0.75 1.00 1.25 1.50 1.75 2.00" || offsets="$offset"
# more compact than if then else logic, read about == behavior vs single / double brackets 

#for z in $zeniths; do 
#    for o $offsets; do 
#	for n in $noiseLevels; do 

	    if [ "$mode" == disp ]; then
		flags="$cuts -DTM_Azimuth ${azimuths}"
		flags="$flags -DTM_Noise $noise -DTM_Zenith ${zeniths}"
		flags="$flags -Log10SizePerBin=0.25 -Log10SizeUpperLimit=6 -RatioPerBin=1 -DTM_WindowSizeForNoise=7"
		flags="$flags -DTM_Width 0.04,0.06,0.08,0.1,0.12,0.14,0.16,0.2,0.25,0.3,0.35"
		flags="$flags -DTM_Length 0.05,0.09,0.13,0.17,0.21,0.25,0.29,0.33,0.37,0.41,0.45,0.5,0.6,0.7,0.8"

		fileBase=dt_${model}_ATM${atm}_${simulation}_vegas254_7sam_${offset/./}wobb_std_${DistanceUpper/./p}${testnameflag} # modify
		outputFile=$TABLEDIR/${fileBase}.root
		outputLog=$workDir/log/tables/${fileBase}.txt
		
		cmd="$VEGAS/showerReconstruction2/bin/produceDispTables $flags $fileList $outputFile"
	    fi # disp table

	    if [[ "$mode" =~ "lookup" ]]; then
		flags="$cuts -Azimuth=${azimuths}" # -Zenith=${zeniths} 
		#flags="$flags -AbsoluteOffset=${offset}"
		flags="$flags -Noise=${noise} -LTM_WindowSizeForNoise=7"
		flags="$flags -GC_CorePositionAbsoluteErrorCut=20 -GC_CorePositionFractionalErrorCut=0.25"
		flags="$flags -Log10SizePerBin=0.07 -ImpDistUpperLimit=800 -MetersPerBin=5.5"
		flags="$flags -TelID=0,1,2,3"
		
		fileBase=lt_${model}_ATM${atm}_${simulation}_vegas254_7sam_${offset/./}off_LZA_disp_${DistanceUpper/./p}${testnameflag} #modify zeniths, offsets
		outputFile=$TABLEDIR/${fileBase}.root
		outputLog=$workDir/log/tables/${fileBase}.txt

		cmd="$VEGAS/showerReconstruction2/bin/produce_lookuptables $flags $fileList $outputFile"

	    fi # lookup 

	    if [ "$mode" == EA ]; then
		cmd="$VEGAS/resultsExtractor/bin/makeEA"
	    fi

	    #qsub

	    echo "$cmd" 
	    if [ "$runMode" == run ]; then
		$cmd | tee $outputLog
		exitCode=${PIPESTATUS[0]}
		echo "$cmd" >> $outputLog
	    elif [ "$runMode" == qsub ]; then 
		qsub <<EOF
#PBS -S /bin/bash
#PBS -l nodes=1,mem=4gb
#PBS -j oe
#PBS -V 
#PBS -N $fileBase
#PBS -o $outputLog

timeStart=`date +%s`
$cmd
timeEnd=`date +%s`
echo "Table made in:"
date -d @\$((timeEnd-timeStart)) -u +%H:%M:%S

exitCode=\$?
echo "$cmd"
if [ "\$exitCode" -ne 0 ]; then
mv $outputLog $workDir/rejected/
fi

EOF
		exitCode=$?
	    fi # runMode options

	    if (( exitCode != 0 )); then
		echo "FAILED!"
		if [ -f $outputLog ]; then
		    mv $outputLog $workDir/rejected/
		fi
		exit 1
	    fi

#	done # noise levels
#    done # offsets 
#done # zeniths 

exit 0 # great job 
