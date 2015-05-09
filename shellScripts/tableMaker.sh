#!/bin/bash

runMode=print # doesn't do anything but print command 

mode=dt
DistanceUpper=1.38

array=ua
atm=22
simulation=CORSIKA

zeniths="50,55 60,65" # 00,20 30,35 40,45
offset="0.00,0.50,0.75 0.25,1.00 1.25,1.50 1.75,2.00"
azimuths="0,45,90,135,180,225,270,315"

noiseNum=(5) # must match noise levels 
noiseLevels=(100,150,200 250,300 350,400 490,605 730,870) # must be reflected in qsub file

dtFlags="-Log10SizePerBin=0.25 -Log10SizeUpperLimit=6 -RatioPerBin=1 -DTM_WindowSizeForNoise=7"
dtFlags="$dtFlags -DTM_Width 0.04,0.06,0.08,0.1,0.12,0.14,0.16,0.2,0.25,0.3,0.35"
dtFlags="$dtFlags -DTM_Length 0.05,0.09,0.13,0.17,0.21,0.25,0.29,0.33,0.37,0.41,0.45,0.5,0.6,0.7,0.8"
# WindowSizeForNoise is 7 by default
ltFlags="$ltFlags -LTM_WindowSizeForNoise=7 -TelID=0,1,2,3"
ltFlags="$ltFlags -GC_CorePositionAbsoluteErrorCut=20 -GC_CorePositionFractionalErrorCut=0.25"
ltFlags="$ltFlags -Log10SizePerBin=0.07 -ImpDistUpperLimit=800 -MetersPerBin=5.5"

spectrum=medium

workDir=$GC
scratchDir=/scratch/mbuchove

nJobs=(0)
nJobsMax=(1000)

#add environment option
args=`getopt -o qr:n: -l offsets:,atm:,fileList:,array:,mode:,distance:,testname:,zeniths:,spectrum: -- $*`
eval set -- $args
for i; do 
    case "$i" in 
	-q) runMode=qsub ; shift ;; 
	-r) # the command that runs the herefile
	    runMode="$2" ; shift 2 ;;
	-n)
	    nJobsMax=($2) ; shift 2 ;; 
	--mode) # lt, dt, ea
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
	--spectrum)
	    spectrum="$2" ; shift 2 ;; 
	--testname) 
	    testnameflag="_${2}" ; shift 2 ;; 
	--) 
	    shift ; break ;;
#	*)
#	    echo "argument $1 is not valid!"
#	    exit 1
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

tableList=$workDir/config/tableList_${mode}_${array}_ATM${atm}.txt
test $runMode != print && test -f $tableList && mv $tableList ${tableList}.backup
cuts="-SizeLower=0/0 -DistanceUpper=0/${DistanceUpper} -NTubesMin=0/5"

case "$array" in
    oa) #V4 
	noiseArray=(3.62,4.45,5.13 5.71,6.21 6.66,7.10 7.83,8.66 9.49,10.34)
	model=MDL8OA_V4_OldArray ;;
    na) #V5 
	noiseArray=(4.29,5.28,6.08 6.76,7.37 7.92,8.44 9.32,10.33 11.32,12.33)
	model=MDL15NA_V5_T1Move ;;
    ua) #V6 
	noiseArray=(4.24,5.21,6.00 6.68,7.27 7.82,8.33 9.20,10.19 11.17,12.17) 
	model=MDL10UA_V6_PMTUpgrade ;;
    *) 
	echo "Array $array not recognized! Choose either oa, na, or ua!!"
	exit 1
        ;;
esac
noises="${noiseArray[0]}"
while (( n < noiseNum )); do noises="${noises},${noiseArray[$n]}"; n=$((n+1)); done # 
echo "$noises"

test "$offset" == all && offsets="0.00,0.25,0.50,0.75,1.00,1.25,1.50,1.75,2.00" || offsets="$offset"
# more compact than if then else logic, read about == behavior vs single / double brackets 

for zGroup in $zeniths; do 
    for oGroup in $offsets; do 
	#for nIndex in $noiseIndices; do
	n=(0)
	while (( n < noiseNum )); do 
	    oGroupName=${oGroup//./}
	    simFileList=$workDir/config/simFileList_${array}_ATM${atm}_Z${zGroup//,/-}_${oGroupName//,/-}wobb_${nGroup//,/-}noise.txt 

	    oGroupNoDot=${oGroup//./}
	    tableFileBase=${mode}_${model}_ATM${atm}_${simulation}_vegas254_7sam_${oGroupNoDot//,/-}wobb_Z${zGroup//,/-}_std_${DistanceUpper//./p}_${nIndex//,/-}noise #modify zeniths, offsets
	    smallTableFile=$workDir/processed/tables/${tableFileBase}.root
	    echo $smallTableFile >> $tableList

	    outputLog=$workDir/log/tables/${tableFileBase}.txt

	    if [ -f $smallTableFile ] || [[ "`qstat -f`" =~ "$tableFileBase" ]]; then
		continue
	    fi


	    if [ "$mode" == "dt" ]; then # disp table
		flags="$cuts $dtFlags -DTM_Azimuth ${azimuths}"
		flags="$flags -DTM_Noise ${noiseArray[$nIndex]} -DTM_Zenith $zGroup"
		# -G_SimulationMode=1 -DTM_TelID=0,1,2,3 -DTM_AbsoluteOffset 		# don't use
		cmd=produceDispTables
		buildCmd="buildDispTree $dtFlags -DTM_Azimuth=${azimuths// /,} -DTM_Zeniths=${zeniths// /,} -DTM_Noise=${noises} dt_${model}_ATM${atm}_${simulation}_vegas254_7sam_Alloff_LZA_std_${DistanceUpper//./p}_AllNoise.root"
	    fi # disp table

	    if [[ "$mode" == "lt" ]]; then
		flags="$cuts $ltFlags -Azimuth=${azimuths}" 
		flags="$flags -Zenith=${zGroup} -AbsoluteOffset=${oGroup} -Noise=${noiseArray[$nIndex]}"
		#flags="$flags -G_SimulationMode=1"		

		cmd=produce_lookuptables
		buildCmd="buildLTTree $ltFlags -Azimuth=${azimuths// /,} -Zenith=${zeniths// /,} -AbsoluteOffset=${offsets// /,} -Noise=${noises} lt_${model}_ATM${atm}_${simulation}_vegas254_7sam_Alloff_LZA_std_${DistanceUpper//./p}_AllNoise.root"
	    fi # lookup 

	    if [ "$mode" == EA ]; then
		flags="-EA_RealSpectralIndex=-2.4" # -2.1
		flags="$flags -Azimuth=${azimuths}"
		flags="$flags -Zenith=$zeniths -Noise=${noise}" # same as lookup table
		flags="$flags -cuts=$HOME/cuts/stage5_ea_${spectrum}_cuts.txt"

		cmd="makeEA $flags "   
		buildCmd="buildEATree "
	    fi # effective area table

	    cmd="$cmd $flags $simFileList $smallTableFile"
	    echo "$cmd" 

	    if [ "$runMode" != print ]; then
		test $nJobs -lt $nJobsMax || exit 0 
		$runMode <<EOF
#PBS -S /bin/bash
#PBS -l nodes=1,mem=4gb
#PBS -j oe
#PBS -V 
#PBS -N $tableFileBase
#PBS -o $outputLog

noiseLevels=(100,150,200 250,300 350,400 490,605 730,870)

while [[ "\`ps cax\`" =~ "bbcp" ]]; do sleep \$((RANDOM%10+10)); done
test -f $simFileList && mv $simFileList $workDir/backup/
for z in ${zGroup//,/ }; do 
    for o in ${oGroup//,/ }; do 
        nGroup=${noiseLevels[$nIndex]}        
	for n in \${nGroup//,/ }; do 
	    simFileBase=Oct2012_${array}_ATM${atm}_vegasv250rc5_7samples_\${z}deg_\${o//./}wobb_\${n}noise
            simFileScratch=$scratchDir/\${simFileBase}.root
            simFileSource=/veritas/upload/OAWG/stage2/vegas2.5/Oct2012_${array}_ATM${atm}/\${z}_deg/\${simFileBase}.root
            echo \$simFileScratch >> $simFileList
            test -f \$simFileScratch || bbcp -e -E md5= \$simFileSource \$simFileScratch
	done # individual noises
    done # individual offsets
done # individual zeniths

timeStart=\`date +%s\`
$cmd
timeEnd=\`date +%s\`
echo "Table made in:"
date -d @\$((timeEnd-timeStart)) -u +%H:%M:%S

exitCode=\$?
echo "$cmd"
if [ \$exitCode -ne 0 ]; then
mv $outputLog $workDir/rejected/
#exit \$exitCode
fi

exit 0
"
EOF
		exitCode=$?
		nJobs=$((nJobs+1))
	    fi # runMode options

	    if (( exitCode != 0 )); then
		echo "FAILED!"
		if [ -f $outputLog ]; then
		    mv $outputLog $workDir/rejected/
		fi
		exit 1
	    fi # was job submitted successfully 
	    n=$((n+1))
	done # noise levels
    done # offsets 
done # zeniths 

echo "$buildCmd"

exit 0 # great job 
