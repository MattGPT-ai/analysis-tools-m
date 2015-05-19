#!/bin/bash

runStage4=false
runStage5=false

offsets="000 050 075" # offsets isn't looped over, but the following all are
#zeniths="00 20 30 40" # BDT
zeniths="50 55 60 65"
atmospheres="21 22"
arrays="na ua"
noises="100 150 200 250 300 350 400 490 605 730 870"

dataDir=/veritas/upload/OAWG/stage2/vegas2.5
model=Oct2012
simulation=GrISUDet

tableDir=/veritas/userspace2/mbuchove/SgrA/processed/tables
workDir=/veritas/userspace2/mbuchove/BDT

subDir=sims_medium
spectrum=medium

cutMode4=auto
cutMode5=auto
source $VSCRIPTS/shellScripts/setCuts.sh

configFlags4="-G_SimulationMode=1"
configFlags5="-G_SimulationMode=1 -Method=VACombinedEventSelection"

environment=$HOME/environments/SgrA_source.sh 
envFlag="-e $environment"

ltMode=auto
runMode=print

subscript45=$VSCRIPTS/shellScripts/subscript_4or5.sh

ltMode=auto
declare -A ltMap
ltMap[oa21]="lt_Oct2012_oa_ATM21_7samples_vegasv250rc5_allOffsets_LZA.root"
ltMap[oa22]="lt_Oct2012_oa_ATM22_7samples_vegasv250rc5_allOffsets_LZA.root"
ltMap[na21]="lt_Oct2012_na_ATM21_7samples_vegasv250rc5_allOffsets_LZA_v1.root"
ltMap[na22]="lt_Oct2012_na_ATM22_7samples_vegasv250rc5_allOffsets_LZA.root"
ltMap[ua21]="lt_Oct2012_ua_ATM21_7samples_vegasv250rc5_allOffsets_LZA_noise150fix.root"
ltMap[ua22]="lt_Oct2012_ua_ATM22_7samples_vegasv250rc5_allOffsets_LZA_noise150fix.root"

qsubHeader="
#!/bin/bash -f
#PBS -l nodes=1,mem=2gb,walltime=03:00:00
#PBS -j oe
#PBS -V 
"
#PBS -p 0

while getopts 45qr:c:C:d:a:A:z:o:n:s:hl:w:BD:e: flag; do
    case $flag in
	4)
	    runStage4=true ;; 
	5)
	    runStage5=true ;; 
	q) 
	    runMode="qsub" ;;
	r) 
	    runMode="${OPTARG}" ;;
	c) 
	    case ${OPTARG} in 
		auto)
		    cutMode4=auto ;; 
		none)
		    cutMode4=none
		    cuFlags4="" ;; 
		*)
		    cutMode4=file
		    cutFlags4="-cuts=${OPTARG}" ;;
	    esac ;; 
	C)
	    case ${OPTARG} in 
		auto)
		    cutMode5=auto ;; 
		none)
		    cutMode5=none # not necessary 
		    cutFlags5="" ;; 
		*)
		    cutMode5=file 
		    cutFlags5="-cuts=${OPTARG}" ;; 
	    esac ;; 
	d) 
	    subDir=$OPTARG ;; # directory name should not contain spaces 
	z) 
	    zeniths="$OPTARG" ;;
	n)
	    noises="$OPTARG" ;;
	a)
	    arrays="$OPTARG" ;;
	A)
	    atmospheres="$OPTARG" ;;
	o)
	    offsets="$OPTARG" ;;
	s)
	    spectrum="$OPTARG" ;; 
	h)
	    hillasMode=HFit
	    configFlags4="$configFlags4 -HillasBranchName=HFit"
	    configFlags5="$configFlags5 -HillasBranchName=HFit"
	    ;;
	l)
	    ltMode=single
	    ltName=$OPTARG ;; 
	w)
	    workDir=$OPTARG ;; 
	e)
	    environment=$OPTARG  
	    envFlag="-e $environment" ;; 
	B)
	    useBDT=true
	    cutMode5=none # not necessary 
	    cutFlags5="" ;; 
	D)
	    DistanceUpper=${OPTARG} ;; 
	?) 
	    echo -e "Option -${BOLD}$OPTARG not recognized!"
	    ;;
    esac # option cases
done # loop over options 
shift $((OPTIND-1))

source $environment 

processDir=$workDir/processed
logDir=$workDir/log
queueDir=$workDir/queue

if [ "$runMode" != print ]; then 
    for dir in $processDir $logDir; do 
	if [ ! -d $dir/$subDir ]; then
	    echo "must create $dir/$subDir"
	    if [ "$runMode" != "print" ]; then
		mkdir $dir/$subDir
	    fi 
	fi
    done 
fi # check dirs exist 

#for simFile in `ls $dataDir/*noise.root`
for array in $arrays; do
    for atm in $atmospheres; do
	for z in $zeniths; do 
	    for offset in $offsets; do 
		for n in $noises; do
		    
		    if [ "$hillasMode" != HFit ]; then
			simFileBase=Oct2012_${array}_ATM${atm}_vegasv250rc5_7samples_${z}deg_${offset//./}wobb_${n}noise
			simFile=$dataDir/Oct2012_${array}_ATM${atm}/${z}_deg/${simFileBase}.root
		    else
			simFileBase=Oct2012_${array}_ATM${atm}_vegasv251_7samples_${z}deg_${offset//./}wobb_${n}noise
			simFile=$dataDir/Oct2012_${array}_ATM${atm}/${simFileBase}.root
		    fi # set name of simfile 

		    if [ "$ltMode" == auto ]; then
			ltName=lt_Oct2012_${array}_ATM${atm}_${simulation}_vegas254_7sam_${offsets// /-}wobb_Z${zeniths// /-}_std_d${DistanceUpper//./p}.root
			ltFile=${tableDir}/${ltName}
			#ltName=$tableDir/${ltMap[${array}${atm}]} # update to just use naming conventions and add hfit
		    fi

		    rootName_4="$processDir/$subDir/${simFileBase}.stage4.root"
		    rootName_5="$processDir/$subDir/${simFileBase}.stage5.root"

		    ##### STAGE 4 #####

		    if [ "$runStage4" == "true" ]; then
			runLog="$logDir/$subDir/${simFileBase}.stage4.txt"
#			if [ true ]; then
			if [ ! -f $rootName_4 ]; then
			    if [ -f $simFile ]; then

				if [ "$cutMode4" == auto ]; then
				    setCuts 
				    cutFlags4="-DistanceUpper=0/${DistanceUpper} -SizeLower=$SizeLower -NTubesMin=$NTubesMin"
				fi # set cuts automatically based on array and spectrum 
				
				stage4cmd="`which vaStage4.2` $configFlags4 -table=${ltFile} $cutFlags4 $rootName_4"
				test "$array" == "oa" && stage4cmd="$stage4cmd -TelCombosToDeny=T1T4" # config only for old array
				echo "$stage4cmd"
				

				if [ "$runMode" != print ]; then

				    test "$runMode" == "qsub" && touch $queueDir/${subDir}_${simFileBase}.stage4${extension}
				
				    $runMode <<EOF  
$qsubHeader  
#PBS -N ${subDir}_${simFileBase}.stage4
#PBS -o $runLog

# cat cuts file 
$subscript45 "$stage4cmd" $rootName_4 $simFile $cuts4file $envFlag # should be able to remove

exit 0 
EOF
				#echo "VEGAS job " $PBS_JOBID " started  at: " ` date ` >> $logDir/PBS.txt
				fi # runMode isn't print 
			    else
				echo -e "\e[0;31mSource simulation file $simFile does not exist! check directory\e[0m"
			    fi # if stage 2 sim file does exist
			fi # if stage 4 file does not exist
		    fi # run stage 4
		    
		    ##### STAGE 5 #####
		    if [ $runStage5 == "true" ]; then
			if [ -n "$useBDT" ]; then
			    stage5Dir=$processDir/$subDir/Oct2012_${array}_ATM${atm}_vegasv250rc5_7samples_${z}deg_${offset//./}wobb
			    test -d $stage5Dir || mkdir $stage5Dir;
			else
			    stage5Dir=$processDir/$subDir
			fi

			if [[ ! -f $stage5Dir/${simFileBase}.stage5${extension}.root ]]; then 
			    if [ -f $rootName_4 ] || [ -f $queueDir/${subDir}_${simFileBase}.stage4${extension} ] || [ "$runMode" == print ]; then 
				runLog="$logDir/$subDir/${simFileBase}.stage5${extension}.txt"
				#sims organized into directories for training 
				
				if [ "$cutMode5" == auto ]; then
				    setCuts
				    cutFlags5="-MeanScaledLengthLower=$MeanScaledLengthLower -MeanScaledLengthUpper=$MeanScaledLengthUpper"
				    cutFlags5="$cutFlags5 -MeanScaledWidthLower=$MeanScaledWidthLower -MeanScaledWidthUpper=$MeanScaledWidthUpper"
				    test "$MaxHeightLower" -ne -100 && cutFlags5="$cutFlags5 -MaxHeightLower=$MaxHeightLower"
				    #			    test -n $MaxHeightLower
				fi # automatic cuts for stage 5 based on array 
				
				stage5cmd="`which vaStage5` $configFlags5 $cutFlags5 -inputFile=$rootName_4 -outputFile=$rootName_5"
				echo "$stage5cmd"
				if [ "$runMode" != print ]; then 
				    test "$runMode" == "qsub" && touch $queueDir/${subDir}_${simFileBase}.stage5${extension}
				    
				    $runMode <<EOF  
  
$qsubHeader   
#PBS -N ${subDir}_${simFileBase}.stage5${extension}
#PBS -o $runLog
 
# deal with cuts file 
$subscript45 "$stage5cmd" $rootName_5 $rootName_4 $envFlag 
test -z "$useBDT" || mv $rootName_5 $stage5Dir

exit 0
EOF
				# echo "VEGAS job " $PBS_JOBID " started at: " ` date ` >> $logDir/PBS.txt
				fi # runMode isn't print 
			    else
				echo -e "\e[0;31mStage 4 file $rootName_4 does not exist and is not in queue!\e[0m"
			    fi # either stage 4 file exists or is in queue 
			fi # stage 5 file does not exist 
		    fi # run stage 5
		    
		done # loop over noises
	    done # loop over offsets
	done # zeniths
    done # atmospheres
done # loop over arrays

exit 0 # success
