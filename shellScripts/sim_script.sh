#!/bin/bash

runStage4="true"
runStage5="true"

wobble=050 # wobble isn't looped over, but the following all are
zeniths="00 20 30 40"
atmospheres="21 22"
arrays="na"
noises="350"

processDir=$VEGASWORK/processed
logDir=$VEGASWORK/log
subDir=sims_medium

dataDir=/veritas/upload/OAWG/stage2/vegas2.5
tableDir=$USERSPACE/tables
queueDir=$VEGASWORK/queue

cuts4=""
cuts5=""

flags4="-G_SimulationMode=1"
flags5="-G_SimulationMode=1 -Method=VACombinedEventSelection"

extension=""
runMode="print"

subscript45=$HOME/bin/subscript_4or5.sh

declare -A ltMap
ltMap[oa21]="lt_Oct2012_oa_ATM21_7samples_vegasv250rc5_allOffsets_LZA.root"
ltMap[oa22]="lt_Oct2012_oa_ATM22_7samples_vegasv250rc5_allOffsets_LZA.root"
ltMap[na21]="lt_Oct2012_na_ATM21_7samples_vegasv250rc5_allOffsets_LZA_v1.root"
ltMap[na22]="lt_Oct2012_na_ATM22_7samples_vegasv250rc5_allOffsets_LZA.root"
ltMap[ua21]="lt_Oct2012_ua_ATM21_7samples_vegasv250rc5_allOffsets_LZA_noise150fix.root"
ltMap[ua22]="lt_Oct2012_ua_ATM22_7samples_vegasv250rc5_allOffsets_LZA_noise150fix.root"
#ltMap[naWinterHfit]="lt_Oct2012_na_ATM21_7samples_hfit_vegasv251_050wobb_LZA.root"
#ltMap[naSummerHfit]="lt_Oct2012_na_ATM22_7samples_hfit_vegasv251_050wobb_LZA.root"  

#PBS -A mgb000
#PBS -p 0
##!/bin/sh -f
qsubHeader="
#!/bin/bash -f
#PBS -l nodes=1,mem=2gb
#PBS -j oe
#PBS -V 
"

while getopts qsc:C:d:z:n:a:w: flag; do
    case $flag in
	q) 
	    runMode="qsub";
	    ;;
	s) 
	    runMode="shell";
	    ;;
	c) 
	    cuts4="-cuts=${OPTARG}"
	    ;;
	C)
	    cuts5="-cuts=${OPTARG}"
	    ;;
	d) 
	    subDir=$OPTARG
	    ;;
	z) 
	    zeniths="$OPTARG"
	    ;;
	n)
	    noises="$OPTARG"
	    ;;
	a)
	    arrays="$OPTARG"
	    ;;
	A)
	    atmospheres="$OPTARG"
	    ;;
	w)
	    wobble=$OPTARG
	    ;;
	?) 
	    echo -e "Option -${BOLD}$OPTARG not recognized!"
	    ;;
    esac # option cases
done # loop over options 
shift $((OPTIND-1))

for dir in $processDir $logDir; do 
    if [ ! -d $dir/$subDir ]; then
	echo "must create $dir/$subDir"
	if [ "$runMode" != "print" ]; then
	    mkdir $dir/$subDir
	fi 
    fi
done # check dirs exist

#for simFile in `ls $dataDir/*noise.root`
for array in $arrays; do
    for atm in $atmospheres; do
	for z in $zeniths; do 
	    for n in $noises; do
		
		simFileBase=Oct2012_${array}_ATM${atm}_vegasv250rc5_7samples_${z}deg_${wobble}wobb_${n}noise
		simFile=$dataDir/Oct2012_${array}_ATM${atm}/${z}_deg/${simFileBase}.root
		
		if [[ ! "$simFile" =~ "hfit" ]]; then
		    ltName=${ltMap[${array}${atm}]}
		else
		    ltName=${ltMap[${array}${atm}hfit]} #add hfit 
		    
		    flags4="$flags4 -HillasBranchName=HFit"
		    flags5="$flags5 -HillasBranchName=HFit"
		    extension="hfit"
#		    cuts4="$HOME/cuts/BDT_hfit4cuts.txt"
		fi

		rootName_4="$processDir/$subDir/${simFileBase}.stage4${extension}.root"
		rootName_5="$processDir/$subDir/${simFileBase}.stage5${extension}.root"

		##### STAGE 4 #####

		if [ "$runStage4" == "true" ]; then
		    runLog="$logDir/$subDir/${simFileBase}.stage4${extension}.txt"
		    if [[ ! -f $rootName_4 ]] && [[ -f $simFile ]]; then

			stage4cmd="`which vaStage4.2` $flags4 -table=$tableDir/${ltName} $cuts4 $rootName_4"
			echo "$stage4cmd"

			if [ "$runMode" == "qsub" ]; then

			    touch $queueDir/${subDir}_${simFileBase}.stage4${extension}
			    
			    qsub <<EOF                                                                                                       
$qsubHeader   
#PBS -N ${subDir}_${simFileBase}.stage4${extension}
#PBS -o $runLog
#echo "VEGAS job " $PBS_JOBID " started  at: " ` date ` >> $logDir/PBS.txt
$subscript45 "$stage4cmd" $rootName_4 $simFile $cuts4file
EOF
			elif [ "$runMode" == "shell" ]; then
			    $subscript45 "$stage4cmd" $rootName_4 $simFile $cuts4file		
			fi # end runmode check 
		    fi # if stage 4 file does not exist and sim file does
		fi # run stage 4
		
		##### STAGE 5 #####
		if [ $runStage5 == "true" ]; then
			sigDir=$processDir/$subDir/Oct2012_${array}_ATM${atm}_vegasv250rc5_7samples_${z}deg_${wobble}wobb
			if [ ! -d $sigDir ]; then
			    mkdir $sigDir;
			fi
		    if [[ ! -f $sigDir/${simFileBase}.stage5${extension}.root ]]; then #&& [[ -f $rootName_4 ]]; then
			runLog="$logDir/$subDir/${simFileBase}.stage5${extension}.txt"
			#sims organized into directories for training 

			stage5cmd="vaStage5 $flags5 $cuts5 -inputFile=$rootName_4 -outputFile=$rootName_5"
			echo "$stage5cmd"
			
			if [ "$runMode" == "qsub" ]; then

			    touch $queueDir/${subDir}_${simFileBase}.stage5${extension}
			    
			    qsub <<EOF                                                                                                       
$qsubHeader   
#PBS -N ${subDir}_${simFileBase}.stage5${extension}
#PBS -o $runLog 
echo "VEGAS job " $PBS_JOBID " started at: " ` date ` >> $logDir/PBS.txt
$subscript45 "$stage5cmd" $rootName_5 $rootName_4 
mv $rootName_5 $sigDir
EOF
			elif [ "$runMode" == "shell" ]; then
			    $subscript45 "$stage5cmd" $rootName_5 $rootName_4	
			fi # end runmode check                                                                                                                                                             
		    fi # stage 5 file does not exist and stage 4 file does
		fi # run stage 5
		
	    done # loop over noises
	done # zeniths
    done # atmospheres
done # loop over arrays

exit 0 # success
