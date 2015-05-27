#!/bin/bash

runMode=print # doesn't do anything but print command 

table=dt
DistanceUpper=1.38

array=ua
atm=22
simulation=GrISUDet #CORSIKA
model=Oct2012

azimuths="0,45,90,135,180,225,270,315"
zeniths="50,55 60,65" # 00,20 30,35 40,45
offsets="0.00,0.50,0.75"
#offsets="0.00,0.50,0.75 0.25,1.00 1.25,1.50 1.75,2.00"

noiseLevels=(100,150,200 250,300 350,400 490,605 730,870) # must be reflected in qsub file
#noiseLevels=(100,150,200,250,300,350,400,490,605,730,870) # all noise in one 
noiseNum=${#noiseLevels[@]}

dtFlags="-Log10SizePerBin=0.25 -Log10SizeUpperLimit=6 -RatioPerBin=1 -DTM_WindowSizeForNoise=7"
dtWidth="-DTM_Width=0.04,0.06,0.08,0.1,0.12,0.14,0.16,0.2,0.25,0.3,0.35"
dtLength="-DTM_Length=0.05,0.09,0.13,0.17,0.21,0.25,0.29,0.33,0.37,0.41,0.45,0.5,0.6,0.7,0.8"
# WindowSizeForNoise is 7 by default
ltFlags="$ltFlags -LTM_WindowSizeForNoise=7 -TelID=0,1,2,3"
ltFlags="$ltFlags -GC_CorePositionAbsoluteErrorCut=20 -GC_CorePositionFractionalErrorCut=0.25"
ltFlags="$ltFlags -Log10SizePerBin=0.07 -ImpDistUpperLimit=800 -MetersPerBin=5.5"

source $VSCRIPTS/shellScripts/setCuts.sh
spectrum=medium # only applies to effective areas 
stage4dir=sims_v254_medium

workDir=$GC
simFileSourceDir=/veritas/upload/OAWG/stage2/vegas2.5
scratchDir=/scratch/mbuchove

nJobs=(0)
nJobsMax=(1000)

#add environment option
args=`getopt -o qr:n: -l array:,atm:,zeniths:,offsets:,noises:,spectrum:,table:,distance:,testname:,stage4dir: -- $*`
eval set -- $args
for i; do 
    case "$i" in 
	-q) runMode=qsub ; shift ;; 
	-r) # the command that runs the herefile
	    runMode="$2" ; shift 2 ;;
	-n)
	    nJobsMax=($2) ; shift 2 ;; 
	--table) # table type: lt, dt, ea
	    table="$2" ; shift 2 ;;
	--array) 
	    array="$2" ; shift 2 ;;
	--atm) 
	    atm="$2" ; shift 2 ;;
	--zeniths)
	    zeniths="$2"  
	    shift 2 ;;
    	--offsets) 
	    offsets="$2" ; shift 2 ;;
	--noises)
	    noises="$2" ; shift 2 ;; 
	--distance)
	    DistanceUpper="$2" ; shift 2 ;;
	--spectrum)
	    spectrum="$2" ; shift 2 ;; 
	--testname) 
	    testnameflag="_${2}" ; shift 2 ;; 
	--stage4dir)
	    stage4dir="$2" ; shift 2 ;; 
	--) 
	    shift ; break ;;
#	*)
#	    echo "argument $1 is not valid!"
#	    exit 1
    esac # argument cases
done # loop over i in args
#if [ $1 ]; then
#    mode="$1"
#fi

if [ ! -d $workDir/log/tables ]; then
    echo "Must create table $workDir/log/tables !!!"
    #mkdir $workDir/log/tables
    exit 1
fi

cuts="-SizeLower=0/0 -DistanceUpper=0/${DistanceUpper} -NTubesMin=0/5"

case "$array" in
    oa) #V4 
	noiseArray=(3.62,4.45,5.13 5.71,6.21 6.66,7.10 7.83,8.66 9.49,10.34) ;; 
	#model=MDL8OA ; epoch=V4_OldArray ;;
    na) #V5 
	noiseArray=(4.29,5.28,6.08 6.76,7.37 7.92,8.44 9.32,10.33 11.32,12.33) ;;
	#model=MDL15NA epoch=V5_T1Move ;;
    ua) #V6 
	noiseArray=(4.24,5.21,6.00 6.68,7.27 7.82,8.33 9.20,10.19 11.17,12.17) ;;  
	#noiseArray=(4.24,5.21,6.00,6.68,7.27,7.82,8.33,9.20,10.19,11.17,12.17) ;; 
	#model=MDL10UA epoch=V6_PMTUpgrade ;;
    *) 
	echo "Array $array not recognized! Choose either oa, na, or ua!!"
	exit 1
        ;;
esac
epoch=$array

noises="${noiseArray[0]}"
while (( n < noiseNum )); do noises="${noises},${noiseArray[$n]}"; n=$((n+1)); done # 

simFileSubDir=Oct2012_${array}_ATM${atm}

if [ "$table" == ea ]; then
    tableList=$workDir/config/tableList_${table}_${array}_ATM${atm}_${spectrum}.txt    
else
    tableList=$workDir/config/tableList_${table}_${array}_ATM${atm}.txt
fi
tempTableList=`mktemp` || ( echo "tempTableList creation failed" ; exit 1 )

for zGroup in $zeniths; do 
    for oGroup in "$offsets"; do 
	noiseIndex=(0) #noiseIndex
	while (( noiseIndex < noiseNum )); do 
	    oGroupNoDot=${oGroup//./}

	    tableFileBase=${table}_${model}_${array}_ATM${atm}_${simulation}_vegas254_7sam_${oGroupNoDot//,/-}wobb_Z${zGroup//,/-}_std_d${DistanceUpper//./p}_${noiseIndex}noise #modify zeniths, offsets
	    #tableFileBase=${table}_${model}_${array}_ATM${atm}_${simulation}_vegas254_7sam_${oGroupNoDot//,/-}wobb_Z${zGroup//,/-}_std_d${DistanceUpper//./p}_allNoises_one 

	    if [ "$table" != ea ]; then 
		simFileList=$workDir/config/simFileList_${array}_ATM${atm}_Z${zGroup//,/-}_${oGroupNoDot//,/-}wobb_${noiseIndex//,/-}noise.txt 
	    else 
		simFileList=$workDir/config/eaFileList_${stage4dir}_${array}_ATM${atm}_Z${zGroup//,/-}_${oGroupNoDot//,/-}wobb_${noiseIndex//,/-}noise_${spectrum}.txt
	    fi 
	    tempSimFileList=`mktemp` || ( echo "temp file creation failed! " 1>&2 ; exit 1 ) 
	    for z in ${zGroup//,/ }; do 
		for o in ${oGroup//,/ }; do 
		    nGroup=${noiseLevels[$noiseIndex]} 
		    for n in ${nGroup//,/ }; do 
			simFileBase=Oct2012_${array}_ATM${atm}_vegasv250rc5_7samples_${z}deg_${o//./}wobb_${n}noise
			if [ "$table" != ea ]; then
			    simFileScratch=$scratchDir/$tableFileBase/${simFileBase}.root
			else
			    simFileScratch=$workDir/processed/${stage4dir}/${simFileBase}.stage4.root
			fi
			echo "$simFileScratch" >> $tempSimFileList
		    done # individual noises
		done # individual offsets
	    done # individual zeniths
	    if [ "$runMode" != print ]; then 
		if [ ! -f $simFileList ]; then
		    cat $tempSimFileList > $simFileList
		elif [[ `diff $tempSimFileList $simFileList` != "" ]]; then
		    echo "$simFileList has changed, backing up"
		    mv $simFileList $workDir/backup/config/
		    cat $tempSimFileList > $simFileList
		fi
	    fi # update simFileList if it's new 

	    if [ "$table" == ea ]; then 
		setCuts
		tableFileBase="${tableFileBase}_${stage4dir}"
		tableFileBase="${tableFileBase}_MSW${MeanScaledWidthUpper//./p}_MSL${MeanScaledLengthUpper//./p}"
		test $MaxHeightLower != -100 && tableFileBase="${tableFileBase}_MH${MaxHeightLower//./p}"
		tableFileBase="${tableFileBase}_ThetaSq${ThetaSquareUpper//./p}"
	    fi # 

	    smallTableFile=$workDir/processed/tables/${tableFileBase}.root
	    echo "$smallTableFile" >> $tempTableList

	    logFile=$workDir/log/tables/${tableFileBase}.txt
	    queueFile=$workDir/queue/$tableFileBase

	    if [ -f $smallTableFile ] || [ -f $queueFile ]; then #[[ "`qstat -f`" =~ "$tableFileBase" ]]
		noiseIndex=$((noiseIndex+1)) ; continue
	    fi

	    if [[ "$table" =~ "dt" ]]; then # disp table
		flags="$cuts $dtFlags $dtWidth $dtLength -DTM_Azimuth=${azimuths}"
		flags="$flags -DTM_Noise=${noiseArray[$noiseIndex]} -DTM_Zenith=$zGroup"
		flags="$flags -DTM_TelID=0,1,2,3"
		#flags="$flags -DTM_AbsoluteOffset=$oGroup"
		#-G_SimulationMode=1 		# don't use
		cmd="produceDispTables $flags $simFileList $smallTableFile"
	    fi # disp table

	    if [[ "$table" =~ "lt" ]]; then
		flags="$cuts $ltFlags -Azimuth=${azimuths}" 
		flags="$flags -Zenith=${zGroup} -AbsoluteOffset=${oGroup} -Noise=${noiseArray[$noiseIndex]}"
		#flags="$flags -G_SimulationMode=1"		

		cmd="produce_lookuptables $flags $simFileList $smallTableFile"
	    fi # lookup 

	    if [[ "$table" =~ "ea" ]]; then
		flags="-EA_RealSpectralIndex=-2.4" # -2.1
		flags="$flags -Azimuth=${azimuths}"
		flags="$flags -Zenith=${zGroup} -Noise=${noiseArray[$noiseIndex]}" # same as lookup table
#		flags="$flags -cuts=$HOME/cuts/stage5_ea_${spectrum}_cuts.txt"
		cuts="-MeanScaledLengthLower=$MeanScaledLengthLower -MeanScaledLengthUpper=$MeanScaledLengthUpper"
		cuts="$cuts -MeanScaledWidthLower=$MeanScaledWidthLower -MeanScaledWidthUpper=$MeanScaledWidthUpper"
		cuts="$cuts -ThetaSquareUpper=$ThetaSquareUpper -MaxHeightLower=$MaxHeightLower"

		cmd="makeEA $cuts $flags $simFileList $smallTableFile" 
	    fi # effective area table

	    if [ ! -f $queueFile ]; then
		
		#cmd="$cmd $flags $simFileList $smallTableFile"
		echo "$cmd" 

		if [ "$runMode" != print ]; then
		    test $nJobs -lt $nJobsMax || exit 0 
		    test "$runMode" == qsub && ( touch $queueFile ; test -f $logFile && mv $logFile $workDir/backup/logTable )
		    
		    $runMode <<EOF
#PBS -S /bin/bash
#PBS -l nodes=1,mem=2gb,walltime=24:00:00
#PBS -j oe
#PBS -V 
#PBS -N $tableFileBase
#PBS -o $logFile

cleanUp() {
mv $logFile $workDir/rejected/
rm $queueFile
rm -rf $scratchDir/$tableFileBase
}

mkdir $scratchDir/$tableFileBase
hostname
noiseLevels=(100,150,200 250,300 350,400 490,605 730,870)
#noiseLevels=(100,150,200,250,300,350,400,490,605,730,870)
trap "echo \"First trap, Exiting 15\" >> $logFile; cleanUp; exit 15" SIGTERM

while [[ "\`ps cax\`" =~ "bbcp" ]]; do sleep \$((RANDOM%10+10)); done

if [ "$table" != ea ]; then
while read -r line; do 

set -- \$line
file=\${1##*/}
beforeZ=\${file%deg*}
zenith=\${beforeZ#*_7samples_}
trap "echo \"file trap, exiting SIGTERM \" >> $logFile; cleanUp; exit 15" SIGTERM 
test -f \$1 || bbcp -e -E md5= $simFileSourceDir/$simFileSubDir/\${zenith}_deg/\$file $scratchDir/$tableFileBase/ 

test -f $scratchDir/$tableFileBase/\$file || ( cleanUp; exit 6 )
#|| ( cleanUp; exit 6 )
#test \$PIPESTATUS[1] -e 0 || ( cleanUp; exit 6 )

done < $simFileList # loop over every sim file in list
fi # don't need to copy for effective area production, stage 4 files already on userspace 

trap "echo \"cmd trap, SIGTERM\" >> $logFile; rm $smallTableFile; mv $logFile $workDir/rejected/; rm $queueFile; exit 15" SIGTERM 

timeStart=\`date +%s\`
$cmd
exitCode=\$?
timeEnd=\`date +%s\`
echo "Table made in:"
date -d @\$((timeEnd-timeStart)) -u +%H:%M:%S

rm $queueFile
rm -rf $scratchDir/$tableFileBase

echo "$cmd"
if [ \$exitCode -ne 0 ]; then
echo "exit code: \$exitCode"
cp $logFile $workDir/rejected/
#mv $logFile $workDir/rejected/
exit \$exitCode
mv $smallTableFile $workDir/backup/tables/
fi

echo "Exiting successfully!"
exit 0

EOF

#test -f \$1 || bbcp -e -E md5= \$path $scratchDir/
#echo "\$file"
##path=`find $simFileSourceDir -name \$file`
#echo "\$beforeZ"
#echo "\$path"

		    exitCode=$?
		    nJobs=$((nJobs+1))
		fi # runMode options
		
		if (( exitCode != 0 )); then
		    echo "FAILED!"
		    if [ -f $logFile ]; then
			mv $logFile $workDir/rejected/
		    fi
		    exit 1
		fi # was job submitted successfully 
	    fi # not already in queue
	    noiseIndex=$((noiseIndex+1))
	done # noise levels
    done # offsets 
done # zeniths 

offsets=${offsets// /,}
offsets=${offsets//./}
zeniths=${zeniths// /,}
azimuths=${azimuths// /,}
combinedFileBase=${table}_${model}_${epoch}_ATM${atm}_${simulation}_vegas254_7sam_${offsets//,/-}off_${zeniths//,/-}zen_std_d${DistanceUpper//./p}

case $table in 
    dt)
	buildCmd="buildDispTree $dtWidth $dtLength -DTM_Azimuth=${azimuths} -DTM_Zenith=${zeniths} -DTM_Noise=${noises} $workDir/processed/tables/${combinedFileBase}.root" ;;
    lt) 
	buildCmd="buildLTTree -TelID=0,1,2,3 -Azimuth=${azimuths} -Zenith=${zeniths} -AbsoluteOffset=${offsets} -Noise=${noises} $workDir/processed/tables/${combinedFileBase}.root" ;; 
    ea) 
	test $MaxHeightLower != -100 && MaxHeightLabel="_MH${MaxHeightLower//./p}" || MaxHeightLabel=""
	buildCmd="buildEATree $flags $cuts $workDir/processed/tables/${combinedFileBase}_MSW${MeanScaledWidthUpper//./p}_MSL${MeanScaledLengthUpper//./p}${MaxHeightLabel}_ThetaSq${ThetaSquareUpper//./p}.root" ;; 
esac # build commands based on table type 

if [ "$runMode" != print ]; then
    if [ ! -f $tableList ]; then
	cat $tempTableList > $tableList
    elif [[ `diff $tempTableList $tableList` != "" ]]; then
	echo "$simFileList has changed, backing up"
	mv $tableList $workDir/backup/config/
	cat $tempTableList > $tableList
    fi
fi # write table list file if it's changed 

echo "$tableList"
echo "$buildCmd"

exit 0 # great job 
