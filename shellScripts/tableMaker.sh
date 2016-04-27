#!/bin/bash 

runMode=print # doesn't do anything but print command 
mem=3gb
#DistanceUpper=1.38

arrays="ua"
atms="22"
spectra="medium"
spectrum=medium # only applies to effective areas 
simulation=GrISUDet #CORSIKA
model=Oct2012

azimuths="0,45,90,135,180,225,270,315"
#zeniths="50,55 60,65" # 00,20 30,35 40,45
zeniths="00,20 30,35 40,45 50,55 60,65"
#offsets="0.00,0.50,0.75"
offsets="0.00,0.50,0.75 0.25,1.00 1.25,1.50 1.75,2.00"

allNoise=false

dtFlags="-Log10SizePerBin=0.25 -Log10SizeUpperLimit=6 -RatioPerBin=1 -DTM_WindowSizeForNoise=7"
dtWidth="-DTM_Width=0.04,0.06,0.08,0.1,0.12,0.14,0.16,0.2,0.25,0.3,0.35"
dtLength="-DTM_Length=0.05,0.09,0.13,0.17,0.21,0.25,0.29,0.33,0.37,0.41,0.45,0.5,0.6,0.7,0.8"
# WindowSizeForNoise is 7 by default
ltFlags="$ltFlags -LTM_WindowSizeForNoise=7"
ltFlags="$ltFlags -GC_CorePositionAbsoluteErrorCut=20 -GC_CorePositionFractionalErrorCut=0.25"
ltFlags="$ltFlags -Log10SizePerBin=0.07 -ImpDistUpperLimit=800 -MetersPerBin=5.5"
ltFlags="$ltFlags -TelID=0,1,2,3"

setCutsScript=${0/${0##*/}/}/setCuts.sh # finds the setCuts script in the same directory as this script
source $setCutsScript 
stage4dir=sims_v254_medium

simFileSourceDir=/veritas/upload/OAWG/stage2/vegas2.5
scratchDir=/scratch/mbuchove
bgScriptDir=$HOME/bgScripts
signals="1 2 3 4 5 6 7 8 11 13 15 30"

priority=(0)
nJobs=(0)
nJobsMax=(1000)

#add environment option
args=`getopt -o qQr:bn:p: -l arrays:,atms:,zeniths:,offsets:,noises:,spectra:,distance:,nameExt:,stage4dir:,telID,xOpts:,allNoise,waitFor:,mem:,reprocess,deny:,validate,suppress -- "$@"`
eval set -- $args
for i; do 
    case "$i" in 
	-q) runMode=qsub 
	    queue=batch ; shift ;; 
	-Q) runMode=qsub
	    queue=express ; shift ;; 
	-r) # the command that runs the herefile
	    runMode="$2" ; shift 2 ;;	
	-b) createFile() {
		cat $1 >> $bgScriptDir/${tableFileBase}.txt
	    }
	    runMode=createFile
	    shift ;; 
	-n)
	    nJobsMax=($2) ; shift 2 ;; 	
	--reprocess)
	    source $HOME/scripts-macros/shellScripts/queueDel.sh
	    reprocess=true ;; 	
	-p) 
	    priority=($2) ; shift 2 ;; 
	--mem)
	    mem="$2" ; shift 2 ;; 
	--arrays) 
	    arrays="$2" ; shift 2 ;;	
	--atms) 
	    atms="$2" ; shift 2 ;;	
	--zeniths)
	    zeniths="$2"  
	    shift 2 ;;    	
	--offsets) 
	    offsets="$2" ; shift 2 ;;	
	--distance)
	    DistanceUpper="$2" ; shift 2 ;;	
	--spectra)
	    spectra="$2" ; shift 2 ;; 
	--stage4dir)
	    stage4dir="$2" ; shift 2 ;;
	--deny)
	    TelCombosToDeny="$2" ; shift 2 ;; 
	--telID)
	    dtFlags="$dtFlags -DTM_TelID=0,1,2,3" ; shift ;; 
	--xOpts) # must enter full argument 
	    xOpts="$xOpts ${2}" ; shift 2 ;; # be careful about
	--nameExt) 
	    nameExt="${nameExt}_${2}" ; shift 2 ;; 
	--noises) # questionable  
	    noises="$2" ; shift 2 ;; 
	--allNoise)
	    allNoise=true ; shift ;; 
	--validate)
	    validate=true ; shift ;; 
	--suppress)
	    suppress=true ; shift ;; 
	--waitFor) # do not start if pattern shows up in current processes 
	    waitString="$2" ; shift 2 ;; 
	--) 
	    shift ; break ;;
	#	*)
    esac # argument cases
done # loop over i in args
if [ $1 ]; then
    table="$1"
else
    echo "must specify table type!"
fi

workDir=$VEGASWORK
# check dirs!
# completed rejected processed

logDir=$workDir/processed/tables/tableLog
if [ ! -d $logDir ]; then
    echo "Must create directory $logDir !!!"
    #mkdir $logDir
    exit 1
fi

for array in $arrays; do 
    for atm in $atms; do 
	for spectrum in $spectra; do 


setCuts
cuts="-SizeLower=${SizeLower} -DistanceUpper=0/${DistanceUpper} -NTubesMin=${NTubesMin}"

if [ "$allNoise" = true ]; then
    noiseArray=(${noiseLevels}) # all noises in one element 
    pedVarArray=(${pedVars})
else 
    set -- ${noiseLevels//,/ }
    noiseArray=(${1},${2},${3} ${4},${5} ${6},${7} ${8},${9} ${10},${11})
    set -- ${pedVars//,/ }
    pedVarArray=(${1},${2},${3} ${4},${5} ${6},${7} ${8},${9} ${10},${11})
    # could make function for this but not necessary now 
fi # do not split tables by noise level groups 
noiseNum=${#noiseArray[@]}

#epoch=$array
simFileSubDir=Oct2012_${array}_ATM${atm}

if [ "$table" == ea ]; then
    # tweak offsets 
    tableList=$workDir/config/tableList_${table}_${stage4dir}_${array}_ATM${atm}_${spectrum}_${offsets//./}wobb${nameExt}.txt    
else
    tableList=$workDir/config/tableList_${table}_${array}_ATM${atm}.txt
fi
tempTableList=`mktemp` || ( echo "tempTableList creation failed" ; exit 1 )

for zGroup in $zeniths; do 
    for oGroup in $offsets; do 
	noiseIndex=(0) #noiseIndex
	while (( noiseIndex < noiseNum )); do 
	    oGroupNoDot=${oGroup//./}

	    #setCuts
	    if [ "$table" == ea ]; then 
		tableFileBase=${table}_${model}_${array}_ATM${atm}_${simulation}_vegas254_7sam_${oGroupNoDot//,/-}wobb_s${SizeLower//0\//}_Z${zGroup//,/-}_std_d${DistanceUpper//./p} #modify zeniths, offsets 
		#tableFileBase=${table}_${stage4dir}_${model}_${array}_ATM${atm}_${simulation}_vegas254_7sam_${oGroupNoDot//,/-}wobb_Z${zGroup//,/-}_std_d${DistanceUpper//./p} 
		tableFileBase="${tableFileBase}_MSW${MeanScaledWidthUpper//./p}_MSL${MeanScaledLengthUpper//./p}"
		test $MaxHeightLower != -100 && tableFileBase="${tableFileBase}_MH${MaxHeightLower//./p}"
		tableFileBase="${tableFileBase}_ThetaSq${ThetaSquareUpper//./p}"
	    else
		tableFileBase=${table}_${model}_${array}_ATM${atm}_${simulation}_vegas254_7sam_${oGroupNoDot//,/-}wobb_Z${zGroup//,/-}_std_d${DistanceUpper//./p} #modify zeniths, offsets 
	    fi # 	    
	    if [ "$allNoise" == true ]; then
		noiseSpec=allNoise
	    else
		noiseSpec=${noiseIndex//,/-}noise
	    fi # append noise levels 
	    tableFileBase="${tableFileBase}_${noiseSpec}${nameExt}"



	    if [ "$table" != ea ]; then 
		simFileList=$workDir/config/simFileList
	    else 
		simFileList=$workDir/config/eaFileList_${stage4dir}_${spectrum}
	    fi 
	    simFileList=${simFileList}_${array}_ATM${atm}_Z${zGroup//,/-}_${oGroupNoDot//,/-}wobb_${noiseSpec}${nameExt}.txt 

	    tempSimFileList=`mktemp` || ( echo "temp file creation failed! " 1>&2 ; exit 1 ) 
	    fail=false
	    for z in ${zGroup//,/ }; do 
		for o in ${oGroup//,/ }; do 
		    noiseGroup=${noiseArray[$noiseIndex]} 
		    for n in ${noiseGroup//,/ }; do 
			simFileBase=Oct2012_${array}_ATM${atm}_vegasv250rc5_7samples_${z}deg_${o//./}wobb_${n}noise
			if [ "$table" != ea ]; then
			    simFileScratch=$scratchDir/$tableFileBase/${simFileBase}.root
			else
			    simFileScratch=$workDir/processed/${stage4dir}/${simFileBase}.stage4.root
			fi
			if [ -f $simFileScratch ] || [ "$validate" != true ]; then 
			    echo "$simFileScratch" >> $tempSimFileList
			else   
			    test -n "$suppress" || echo "$simFileScratch does not exist!"
			    fail=true
			    break 3 
			fi 

		    done # individual noises
		done # individual offsets
	    done # individual zeniths
	    #[ "$fail" != "true" ] || continue
	    
	    if [ "$runMode" != print ]; then 
		if [ ! -f $simFileList ]; then
		    cat $tempSimFileList > $simFileList
		elif [[ `diff $tempSimFileList $simFileList` != "" ]]; then
		    echo "$simFileList has changed, backing up"
		    mv $simFileList $workDir/backup/config/
		    cat $tempSimFileList > $simFileList
		fi
	    fi # update simFileList if it's new 
	    
	    smallTableFile=$workDir/processed/tables/${tableFileBase}.root
	    echo "$smallTableFile" >> $tempTableList

	    logFile=$logDir/${tableFileBase}.txt
	    queueFile=$workDir/queue/$tableFileBase

	    if [[ "$table" =~ "lt" ]]; then # lookup table 
		flags="$cuts $ltFlags -Azimuth=${azimuths}" 
		flags="$flags -Zenith=${zGroup} -AbsoluteOffset=${oGroup} -Noise=${pedVarArray[$noiseIndex]}"
		#flags="$flags -G_SimulationMode=1" 

		cmd="produce_lookuptables $flags $simFileList $smallTableFile"
	    elif [[ "$table" =~ "ea" ]]; then # effective area table 
		flags="-EA_RealSpectralIndex=-2.4" # -2.1
		flags="$flags -Azimuth=${azimuths}"
		flags="$flags -Zenith=${zGroup} -Noise=${pedVarArray[$noiseIndex]}" # same as lookup table
		if [ -n "$TelCombosToDeny" ]; then # if [ $telCombosToDeny ]
		    flags="$flags -TelCombosToDeny=$TelCombosToDeny"
		elif [ -n "$autoTelCombosToDeny" ]; then # V4
                    flags="$flags -TelCombosToDeny=$autoTelCombosToDeny"
		fi		
		#flags="$flags -AbsoluteOffset=${oGroup}"
		#flags="$flags -cuts=$HOME/cuts/stage5_ea_${spectrum}_cuts.txt"
		
		cuts="-MeanScaledLengthLower=$MeanScaledLengthLower -MeanScaledLengthUpper=$MeanScaledLengthUpper"
		cuts="$cuts -MeanScaledWidthLower=$MeanScaledWidthLower -MeanScaledWidthUpper=$MeanScaledWidthUpper"
		cuts="$cuts -ThetaSquareUpper=$ThetaSquareUpper -MaxHeightLower=$MaxHeightLower"

		cmd="makeEA $cuts $flags $xOpts $simFileList $smallTableFile" 
	    elif [[ "$table" =~ "dt" ]]; then # disp table
		flags="$cuts $dtFlags $dtWidth $dtLength -DTM_Azimuth=${azimuths}"
		flags="$flags -DTM_Noise=${pedVarArray[$noiseIndex]} -DTM_Zenith=$zGroup"
		flags="$flags -DTM_AbsoluteOffset=$oGroup"

		#flags="$flags -G_SimulationMode=1"
		# don't use
		cmd="produceDispTables $flags $simFileList $smallTableFile"
		
	    fi # effective area table


	    # needs revision for queueDel 
	    if [ -f $smallTableFile ] || [ -f $queueFile ] || [ -f $bgScriptDir/${tableFileBase}.txt ]; then 
		#[[ "`qstat -f -1`" =~ "$tableFileBase" ]] # ( [ -f $bgScriptDir/${tableFileBase}.txt ] && [ !overwrite ] )
		
	        if [ -n "$reprocess" ]; then 
		    queueDel $tableFileBase
		else
		    noiseIndex=$((noiseIndex+1)) ; continue
		fi

	    else #[ ! -f $queueFile ] && [ ! -f $smallTableFile ] && [ ! -f $bgScriptDir/${tableFileBase}.txt ]; then
		# file does not exist and is not queued 

		echo "$cmd" 

		if [ "$runMode" != print ]; then

		    test $nJobs -lt $nJobsMax || exit 0 
		    test "$runMode" == qsub && ( touch $queueFile ; test -f $logFile && mv $logFile $workDir/backup/logTable/ )
		    $runMode <<EOF 

#PBS -S /bin/bash
#PBS -l nodes=1,mem=${mem},walltime=96:00:00
#PBS -j oe
#PBS -V 
#PBS -N $tableFileBase
#PBS -o $logFile
#PBS -p $priority
#PBS -q $queue

# clean up files upon exit, make sure this executes when other trap is triggered 
cleanUp() { 
    test -f $queueFile && rm $queueFile
    rm -rf $scratchDir/$tableFileBase
    echo -e "\n$cmd"
}
trap cleanUp EXIT # called upon any exit 
rejectTable() {
    echo "exit code: \$exitCode"
    test -f $smallTableFile && mv $smallTableFile $workDir/backup/tables/
    mv $logFile $workDir/rejected/
#    exit 15 
}

for sig in $signals; do 
    trap "echo \"TRAP! Signal: \${sig} - Exiting..\"; rejectTable; exit \$sig" \$sig
done 

hostname

# copy the root files to scratch 
if [ "$table" != ea ]; then
    while read -r line; do 

        mkdir -p $scratchDir/$tableFileBase
        while [[ "\`ps cax\`" =~ "bbcp" ]]; do sleep \$((RANDOM%10+10)); done
        set -- \$line
	file=\${1##*/}
	beforeZ=\${file%deg*} # part of filename preceding Z 
	zenith=\${beforeZ#*_7samples_}
	test -f \$1 || bbcp -e -E md5= $simFileSourceDir/$simFileSubDir/\${zenith}_deg/\$file $scratchDir/$tableFileBase/ || ( rejectTable; exit 6 ) # test -f $scratchDir/$tableFileBase 

	#test \$PIPESTATUS[1] -e 0 || ( cleanUp; exit 6 )
	
    done < $simFileList # loop over every sim file in list
else
    if [ $waitString ]; then 
#        while [ -f $workDir/queue/*${waitString}* ]; do 
        while [[ "\`qstat -f -1\`" =~ "$waitString" ]]; do 
            sleep 60 # 30  
        done 
    fi 
fi # don't need to copy for effective area production, stage 4 files already on userspace 

# execute command
timeStart=\`date +%s\`
$cmd
exitCode=\$?
timeEnd=\`date +%s\`
echo "Table made in:"
date -d @\$((timeEnd-timeStart)) -u +%H:%M:%S

if [ "\$exitCode" -ne 0 ]; then 
    rejectTable
    exit \$exitCode
fi 

# validate table 
if [ "$table" == "ea" ]; then 
    cd $VEGAS/resultsExtractor/macros/
    root -l -b -q 'validate2.C("$smallTableFile")'
    sumFile=${smallTableFile/.root/.summary.csv}
    if [ -f \$sumFile ]; then
        test \`cat $sumFile | wc -l\` -gt 1 && badDiag=true || rm \$sumFile
    else
        echo "no sumfile!"
    fi 
else
    cd $VEGAS/showerReconstruction2/macros/
    root -l -b -q 'validate.C("$smallTableFile")'
fi
# ea files have an additional summary csv file that should not have more than one line 
diagFile=${smallTableFile/.root/.diag}
if [ -s \$diagFile ] || [ ! -f \$diagFile ]; then 
    echo "SOME MIGHT FAIL!! check .diag files"
    badDiag=true
else
    rm \$diagFile
fi # diag file contains bad tables or wasn't created

if [ "\$badDiag" != "true" ]; then
    cp $logFile $workDir/completed/
    test -f $workDir/rejected/${logFile##*/} && mv $workDir/rejected/${logFile##*/} $workDir/backup/rejected/
    #rsync -uv $smallTableFile $TABLEDIR/ 
fi

echo "Exiting successfully!"
exit 0

EOF
		    exitCode=$?
		    nJobs=$((nJobs+1))
		fi # runMode options
		
		if (( exitCode != 0 )); then
		    echo "FAILED!"
		    test -f $logFile && mv $logFile $workDir/rejected/
		    exit 1
		fi # was job submitted successfully 
	    fi # not already in queue
	    noiseIndex=$((noiseIndex+1))
	done # noise levels
    done # offsets 
done # zeniths 

offsets=${offsets// /,}
offsetName=${offsets//./}
zeniths=${zeniths// /,}
azimuths=${azimuths// /,}
combinedFileBase=${table}_${model}_${array}_ATM${atm}_${simulation}_vegas254_7sam_${offsetName//,/-}wobb_Z${zeniths//,/-}_std_d${DistanceUpper//./p}

case $table in 
    dt)
	buildCmd="buildDispTree $dtWidth $dtLength -DTM_Azimuth=${azimuths} -DTM_Zenith=${zeniths} -DTM_Noise=${pedVars} $workDir/processed/tables/${combinedFileBase}.root" ;;
    lt) 
	buildCmd="buildLTTree -TelID=0,1,2,3 -Azimuth=${azimuths} -Zenith=${zeniths} -AbsoluteOffset=${offsets} -Noise=${pedVars} $workDir/processed/tables/${combinedFileBase}.root" ;; 
    ea) 
	test $MaxHeightLower != -100 && MaxHeightLabel="_MH${MaxHeightLower//./p}" || MaxHeightLabel=""
	buildCmd="buildEATree -Azimuth=${azimuths} -Zenith=${zeniths} -Noise=${pedVars} $workDir/processed/tables/${combinedFileBase}_MSW${MeanScaledWidthUpper//./p}_MSL${MeanScaledLengthUpper//./p}${MaxHeightLabel}_ThetaSq${ThetaSquareUpper//./p}${nameExt}.root" ;; # $cuts 
esac # build commands based on table type 

if [ "$runMode" != print ]; then
    if [ ! -f $tableList ]; then
	cat $tempTableList > $tableList
    elif [[ `diff $tempTableList $tableList` != "" ]]; then
	echo "$tableList has changed, backing up"
	mv $tableList $workDir/backup/config/
	cat $tempTableList > $tableList
    fi
fi # write table list file if it's changed 

#if [ "$suppress" != true ]; then 
echo "$tableList"
[ "$suppress" != "true" ] && echo "$buildCmd"
#fi 

	done # spectra 
    done # atms 
done # arrays 

exit 0 # great job 
