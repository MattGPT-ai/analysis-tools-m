#!/bin/bash

bgDir=$BDT/processed/bg_medium_V5 #subdirectory for background files, under processDir
subDir=5-16_medium_V5 #subdirectory for weights, under weightsDir
simDir=$BDT/processed/sims_medium

processDir=$BDT/processed
trainMacro=$BDT/macros/VegasBDTClassification.C # to be copied if macro doesn't exist in weights folder
#trainMacro=$BDT/macros/VegasTMVAClassification.C
logDir=$BDT/log
plotLog=$logDir/plotLog.txt # on
backupDir=$BDT/backup
weightsDir=$BDT/weights
plotDir=$BDT/plots
plotMacro=$BDT/macros/MakePlots.C

#used in cmd to find appropriate sim files
array=na # change to V5?
atm=21
noise=350
wobble=050

runMode="print"

zeniths="10 20 30 40"

args=`getopt b:qrt:d:s:a:V: $*`
set -- $args

for i; do
    case "$i" in 
#	-t) trainDir=$2
#	    shift ; shift ;;
	-q) runMode="qsub"
	    shift ;;
	-r) runMode="shell"
	    shift ;;
	-b) bgDir=$2
	    shift ; shift ;;
	-d) subDir=$2
	    shift ; shift ;;
	-s) simDir=$2
	    shift ; shift ;;
	-V) array=$2
	    shift ; shift ;;
	-a) atm=$2
	    shift ; shift ;;
	--) shift ; break ;;
    esac
done # loop over command line arguments 

if [ $1 ]; then
    zeniths=""
fi
while [ $1 ]; do
    zeniths="$zeniths $1"
    shift
done

trainDir=$weightsDir/${subDir} 
echo "training directory: $trainDir"

logDirFull=$logDir/train_${subDir}
plotDirFull=$plotDir/${subDir}
for dir in $trainDir $logDirFull $plotDirFull; do
    if [ ! -d $dir ]; then
	echo "Creating directory: $dir"
	mkdir -p $dir
    fi
done

#if macro doesn't exist in this directory, ask about copying and copy it over
for macro in $trainMacro $plotMacro; do 
    if [ ! -f $trainDir/${macro##*/} ]; then
	echo "Copy of macro $macro does not exist in $trainDir, copying..."
	cp $macro $trainDir/
    fi
done

for z in $zeniths; do
    #bgDir=$processDir/$bgDir
    
    if [ ! -d $bgDir ]; then
	echo "directory: $bgDir with background files does not exist!"
	exit 1
    fi

    if [ "$z" = "10" ]; then
	simZ="00"
    else
	simZ="$z"
    fi

    for eLow in 0 320 500 1000; do
	if [ "$eLow" = "0" ]; then
	    eHigh=320
	elif [ "$eLow" = "320" ]; then
	    eHigh=560
	elif [ "$eLow" = "500" ]; then
	    eHigh=1120
	elif [ "$eLow" = "1000" ]; then
	    eHigh=30000
	fi
	    
	fileNameBase="TMVAClassification_TestBDT_ELow${eLow}_EHigh${eHigh}_Zenith${z}"
	#fileNameBase="TestBDT_ELow${eLow}_EHigh${eHigh}_Zenith${z}"
	if [ ! -f $trainDir/${fileNameBase}.weights.xml ]
	    then

	    cmd="root -l -b -q 'VegasBDTClassification.C(\"$bgDir/\",\"$simDir/Oct2012_${array}_ATM${atm}_vegasv250rc5_7samples_${simZ}deg_${wobble}wobb\",\"${eLow}\",\"${eHigh}\",\"${z}\")'"  
	    #cmd="root -l -b -q 'VegasTMVAClassification.C(\"$bgDir/\",\"$simDir/Oct2012_${array}_ATM${atm}_vegasv250rc5_7samples_${simZ}deg_${wobble}wobb_${noise}noise.stage5.root\",\"${eLow}\",\"${eHigh}\",\"${z}\")'"   

	    echo $cmd
	    
	    plotCMD="root -l -b -q 'MakePlots.C(\"$trainDir/TestBDT_ELow${eLow}_EHigh${eHigh}_Zenith${z}.root\")'"

	    logFile=$logDirFull/${fileNameBase}.txt
	    plotLog=$logDirFull/plotLog.txt
	    if [ "$runMode" == "qsub" -o "$runMode" == "shell" ]; then
		if [ -f $logFile ]; then
		    if [ ! -d $backupDir/$subDir ]; then
			mkdir -p $backupDir/$subDir
		    fi
		    mv $logFile $backupDir/$subDir
		fi
	    fi

	    if [ $runMode = "qsub" ]; then
	    
		qsub <<EOF
#PBS -S /bin/bash
#PBS -l nodes=1,mem=2gb
#PBS -j oe
#PBS -o $logFile
#PBS -N $fileNameBase

date
hostname
cd $trainDir
pwd
#cp $trainMacro .

$cmd
completion=$?

echo "$cmd"

echo "exit code: $completion"

#mv ${trainMacro##*/} $logDirFull/

#cd $plotDirFull
#cp $plotMacro .

echo "$plotCMD" >> $plotLog # command goes into log first here
$plotCMD &>> $plotLog

#mv ${plotMacro##*/} $logDirFull

mv weights/${fileNameBase}.* . #weights/TMVAClassification_${fileNameBase}.*
mv plots/* $plotDirFull
#rmdir plots

EOF
		# end if qsub 
	    elif [ $runMode = "shell" ]; then
		
		$cmd &> $logFile
		#$cmd 2>&1 | tee $logFile
		echo "$cmd" >> $logFile
	    
	    fi


	fi # if this xml file does not exist yet
    done # for loop over energy
done # for loop over zenith

exit 0 # success
