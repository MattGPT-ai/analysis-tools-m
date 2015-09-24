#!/bin/bash

runStage4=false
runStage5=false

offsets="000 050 075" # offsets isn't looped over, but the following all are
#zeniths="00 20 30 40" # BDT
zeniths="55 60 65"
atmospheres="21 22"
arrays="na ua"
noises="100 150 200 250 300 350 400 490 605 730 870"

dataDir=/veritas/upload/OAWG/stage2/vegas2.5
model=Oct2012
simulation=GrISUDet

#tableDir=/veritas/userspace2/mbuchove/SgrA/processed/tables
tableDir=$TABLEDIR
workDir=/veritas/userspace2/mbuchove/BDT

subDir=sims_medium
#stage4dir=/veritas/userspace2/mbuchove/SgrA/processed/sims_v254_disp5t 
spectrum=medium

cutMode4=auto
cutMode5=auto
scriptDir=${0/f${0##*/}/}
source $scriptDir/setCuts.sh

configFlags4="-G_SimulationMode=1"
configFlags5="-G_SimulationMode=1 -Method=VACombinedEventSelection"

environment=$HOME/environments/SgrA_source.sh 
envFlag="-e $environment"
subscript45=$scriptDir/subscript_4or5.sh

ltMode=auto
runMode=print
nJobsMax=(1000) 

qsubHeader="
#!/bin/bash -f
#PBS -l nodes=1,mem=2gb,walltime=48:00:00
#PBS -j oe
#PBS -V 
#PBS -p 0
"

args=`getopt -o 45qr:c:C:d:z:o:n:s:h:l:w:BD:e: -l BDT,disp:,cutTel:,override,array:,atm:,stage4dir:,noises: -n sim_script.sh -- "$@"`
eval set -- $args
for i; do 
    case "$i" in
	-4) runStage4=true ; shift ;; 
	-5) runStage5=true ; shift ;; 
	-q) runMode="qsub" ; shift ;;
	-r) runMode="${2}" ; shift 2 ;;
	-n) nJobsMax=$2 ; shift 2 ;; 
	-c) 
	    case "$2" in 
		auto)
		    cutMode4=auto ;; 
		none)
		    cutMode4=none 
		    cutFlags4="" ;; 
		*)
		    cutMode4=file
		    cutFlags4="-cuts=${2}" ;; 
	    esac 
	    shift 2 ;; 
	-C)
	    case ${2} in 
		auto) cutMode5=auto ;; 
		none) cutMode5=none # not necessary 
		    cutFlags5="" ;; 
		*)  cutMode5=file 
		    cutFlags5="-cuts=${2}" ;; 
	    esac 
	    shift 2 ;; 
	-d) subDir=$2 ; shift 2 ;; # directory name should not contain spaces 
	--stage4dir) 
	    stage4dir=$2 ; shift 2 ;; 
	-z) zeniths="$2" ; shift 2 ;;
	--noises) noises="$2" ; shift 2 ;;
	--array) arrays="$2" ; shift 2 ;;
	--atm) atmospheres="$2" ; shift 2 ;;
	-o) offsets="$2" ; shift 2 ;;
	-s) spectrum="$2" ; shift 2 ;; 
	-h) hillasMode=HFit
	    configFlags4="$configFlags4 -HillasBranchName=HFit"
	    configFlags5="$configFlags5 -HillasBranchName=HFit"
	    shift ;;
	-l) ltMode=single
	    ltName=$2 ; shift 2 ;; 
	-w) workDir=$2 ; shift 2 ;; 
	-e) environment=$2  
	    envFlag="-e $environment" ; shift 2 ;;
	--disp) 
	    stg4method=disp 
	    dispMethod=${2}
            configFlags4="$configFlags4 -DR_Algorithm=Method${2}" #t stands for tmva, Method6 for average disp and geom 
	    DistanceUpper=1.38 
            ltVegas=vegas254 
            echo "using disp method"
	    zenith="Z55-70" 
            shift 2 ;;
	--cutTel)
	    configFlags4="$configFlags4 -CutTelescope=${2}/1"
	    shift 2 ;; 
  	-B|--BDT) 
	    useBDT=true
	    cutMode5=none # not necessary 
	    cutFlags5="" ; shift ;; 
	-D) DistanceUpper=${2} ; shift 2 ;; 
	--override) 
	    configFlags4="$configFlags4 -OverrideLTCheck=1"
	    shift ;; 
	--) shift ;;
    esac # option cases
done # loop over options 

source $environment 
processDir=$workDir/processed
logDir=$workDir/log
queueDir=$workDir/queue

if [ -z "$stage4dir" ]; then
    stage4dir=$processDir/$subDir
    #subDir=${stage4dir##*/}
fi
for dir in $processDir $logDir; do 
    if [ ! -d $dir/$subDir ]; then
	echo "must create $dir/$subDir"
	if [ "$runMode" != "print" ]; then
	    mkdir $dir/$subDir
	fi 
    fi
done  # check dirs exist 

nJobs=(0) 

for array in $arrays; do
    for atm in $atmospheres; do
	for z in $zeniths; do 
	    for offset in $offsets; do 
		for n in $noises; do

		    if (( nJobs >= nJobsMax )); then
			exit 0 
		    fi

		    setCuts

		    if [ "$hillasMode" != HFit ]; then
			simFileBase=Oct2012_${array}_ATM${atm}_vegasv250rc5_7samples_${z}deg_${offset//./}wobb_${n}noise
			simFile=$dataDir/Oct2012_${array}_ATM${atm}/${z}_deg/${simFileBase}.root
		    else
			simFileBase=Oct2012_${array}_ATM${atm}_vegasv251_7samples_${z}deg_${offset//./}wobb_${n}noise
			simFile=$dataDir/Oct2012_${array}_ATM${atm}_HFit/${simFileBase}.root
		    fi # set name of simfile 

		    rootName_4="$stage4dir/${simFileBase}.stage4.root"

		    ##### STAGE 4 #####

		    if [ "$runStage4" == "true" ]; then
			runLog="$logDir/$subDir/${simFileBase}.stage4.txt"
			if [ ! -f $rootName_4 ]; then
			    if [ -f $simFile ]; then

				if [ "$ltMode" == auto ]; then
				    ltName=lt_Oct2012_${array}_ATM${atm}_7samples_vegasv250rc5_allOffsets_LZA
				elif [ "ltMode" == custom ]; then
				    ltName=lt_Oct2012_${array}_ATM${atm}_${simulation}_vegas254_7sam_000-050-075wobb_LZA_std_d${DistanceUpper//./p}
				fi # automatic lookup table 
				ltFile=$tableDir/${ltName}.root
				test -f $ltFile || echo -e "\e[0;31mLookup table $ltFile does not exist! \e[0m"
				tableFlags="-table=${ltFile}"

				if [ "$stg4method" == disp ]; then
				    
				    if [ "$dispMethod" == 5t ]; then
					dtName=TMVA_Disp.xml
				    else
				       	dtName=dt_Oct2012_ua_ATM22_GrISUDet_vegas254_7sam_${offset}wobb_Z50-55_std_d1p38_allNoise.root 
					# specify disp mode 
				    fi
				    
				    dtFile=$tableDir/${dtName}
				    test -f $dtFile || echo -e "\e[0;31mDisp table $dtFile does not exist! \e[0m"
				    tableFlags="$tableFlags -DR_DispTable=$dtFile" 
				fi # disp method 

				if [ "$cutMode4" == auto ]; then
				    cutFlags4="-DistanceUpper=0/${DistanceUpper} -SizeLower=$SizeLower -NTubesMin=$NTubesMin"
				fi # set cuts automatically based on array and spectrum 
				
				stage4cmd="`which vaStage4.2` $configFlags4 $tableFlags $cutFlags4 $rootName_4"
				test "$array" == "oa" && stage4cmd="$stage4cmd -TelCombosToDeny=T1T4" # config only for old array
				echo "$stage4cmd"
				
				if [ "$runMode" != print ]; then

				    test "$runMode" == "qsub" && touch $queueDir/${subDir}_${simFileBase}.stage4${extension}
				    
				    $runMode <<EOF  
$qsubHeader  
#PBS -N ${subDir}_${simFileBase}.stage4
#PBS -o $runLog

# cat cuts file 
$subscript45 "$stage4cmd" $rootName_4 $simFile $envFlag # should be able to remove cuts

exit 0 
EOF

				fi # runMode isn't print 
			    else
				echo -e "\e[0;31mSource simulation file $simFile does not exist! check directory\e[0m"
			    fi # if stage 2 sim file does exist
			fi # if stage 4 file does not exist
		    fi # run stage 4
		    
		    ##### STAGE 5 #####
		    if [ $runStage5 == "true" ]; then

			if [ "$useBDT" == true ]; then
			    stage5Dir=$processDir/$subDir/Oct2012_${array}_ATM${atm}_vegasv250rc5_7samples_${z}deg_${offset//./}wobb
			    test -d $stage5Dir || mkdir $stage5Dir;
			else
			    stage5Dir=$processDir/$subDir
			fi
			rootName_5=$stage5Dir/${simFileBase}.stage5.root
			
			if [[ ! -f $stage5Dir/${simFileBase}.stage5${extension}.root ]]; then 
			    if [ -f $rootName_4 ] || [ -f $queueDir/${subDir}_${simFileBase}.stage4${extension} ] || [ "$runMode" == print ]; then 
				runLog="$logDir/$subDir/${simFileBase}.stage5${extension}.txt"
				#sims organized into directories for training 
				
				if [ "$cutMode5" == auto ]; then
				    #setCuts
				    cutFlags5="-MeanScaledLengthLower=$MeanScaledLengthLower -MeanScaledLengthUpper=$MeanScaledLengthUpper"
				    cutFlags5="$cutFlags5 -MeanScaledWidthLower=$MeanScaledWidthLower -MeanScaledWidthUpper=$MeanScaledWidthUpper"
				    test "$MaxHeightLower" -ne -100 && cutFlags5="$cutFlags5 -MaxHeightLower=$MaxHeightLower"
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
#test -z "$useBDT" || mv $rootName_5 $stage5Dir

exit 0
EOF

				fi # runMode isn't print 
			    else
				echo -e "\e[0;31mStage 4 file $rootName_4 does not exist and is not in queue!\e[0m"
			    fi # either stage 4 file exists or is in queue 
			fi # stage 5 file does not exist 
		    fi # run stage 5
		    nJobs=$((nJobs+1))
		done # loop over noises
	    done # loop over offsets
	done # zeniths
    done # atmospheres
done # loop over arrays

exit 0 # success
