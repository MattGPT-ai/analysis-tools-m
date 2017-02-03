#!/bin/bash

STG6LIST=$1

DATE=$(date +%F)_$(date +%T)
LogFile=logs/LogFile_$DATE.txt
ResultFile=config/results_$DATE.root
ValidatePath=~/veritas/ModLiMaRBM
VegasPath=~/vegas/VEGAS_20160130
ConfigPath=~/vegas/configfiles/vegas2_5/Soft

if ! test -d config
then 
    mkdir config
fi

if ! test -d logs
then 
    mkdir logs
fi

rm LogFile.txt 

echo "Starting Stage 6 on $DATE."

echo "$VegasPath/bin/vaStage6 -config=$ConfigPath/Stg6CBG.config -cuts=$ConfigPath/Stg6cuts.config -RBM_UseModifiedLiMa=1 -RBM_UseZnCorrection=1 -S6A_Batch=1 $STG6LIST > $LogFile 2>&1"

$VegasPath/bin/vaStage6 -config=$ConfigPath/Stg6CBG.config -cuts=$ConfigPath/Stg6cuts.config -RBM_UseModifiedLiMa=1 -RBM_UseZnCorrection=1 -S6A_Batch=1 $STG6LIST >> LogFile.txt 2>&1

mv config/results_s6.root $ResultFile

echo "Stage 6 Complete. Results stored in config/$ResultFile"

echo "Starting validation"

$ValidatePath/validateSigDist_v1.exe $ResultFile >> LogFile.txt 2>&1

cp LogFile.txt $LogFile
echo "Validation Complete. "
