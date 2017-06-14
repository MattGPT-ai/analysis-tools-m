#!/bin/bash

# this script runs a lightcurve analysis. 
# the stage 5 lc files are only different because they use the VAStereoMethod 

arrays="na ua"

test -n "$1" && runMode="$1" || runMode=cat
test -n "$2" && energy=$2 

ext=_daily 
#ext=_E${energy}
#filext=_E${energy}_lc
#opts=-LC_MinEnergy=${energy} # TeV 
#525960 is 365.25 days, 86400 is 1 day 



for array in $arrays; do 

    logFile=$GC/log/lightCurves/lightCurve_${array}${ext}.txt
    outputFileName=$GC/results/SgrA_lightCurve_${array}_4tels${ext}.root

    test -f $outputFileName && continue 
    test $runMode != cat && test -f $logFile && mv -v $logFile $GC/backup/log/
    
    cmd="`which vaMoonShine` -LC_S6FileName=\"$GC/results/SgrA_disp5t_lc_${array}_4tels_noPoor_both_s6.root\" -LC_OutputFileName=\"$outputFileName\" -LC_EAFile=\"$TABLEDIR/ea_disp5t_Oct2012_${array}_ATM22_GrISUDet_vegas254_7sam_allOff_LZA_std_d1p38_MSW1p1_MSL1p3_MH7_ThetaSq0p01_Deny2.root\" -LC_S5FileList=\"$GC/runlists/lightCurve_${array}_4tels${filext}_stage5list_lcIssues.txt\" -LC_TimeBin=1440 $opts"
    
    $runMode <<EOF

#PBS -q express
#PBS -j oe
#PBS -o $logFile
#PBS -l nodes=1,mem=2gb
#PBS -N lc_${array}${ext}

#source $HOME/environments/bashMoonShine.sh


echo "$cmd"
$cmd #| tee 2>&1 $logFile 

exitCode=\$PIPESTATUS[0]

test \$exitCode -ne 0 && rm -v $outputFileName

exit \$exitCode

EOF

done # loop over arrays 

exit 0 # great job 

#$VERITASBASE/VEGAS-MoonShine/bin/vaMoonShine -LC_S6FileName="/veritas/userspace2/mbuchove/SgrA/results/SgrA_disp5t_lc_${arr}_4tels_noPoor_both_s6.root" -LC_OutputFileName="/veritas/userspace2/mbuchove/SgrA/results/SgrA_lightCurve_${arr}_4tels_all_E${e}.root" -LC_EAFile="/veritas/userspace3/mbuchove/tables/ea_disp5t_Oct2012_${arr}_ATM22_GrISUDet_vegas254_7sam_allOff_LZA_std_d1p38_MSW1p1_MSL1p3_MH7_ThetaSq0p01_Deny2.root" -LC_S5FileList="/veritas/userspace2/mbuchove/SgrA/runlists/lightCurve_${arr}_4tels_stage5list_lcIssues.txt" -LC_MinEnergy=${e} -LC_MaxEnergy=100 2>&1 | tee /veritas/userspace2/mbuchove/SgrA/log/lightCurves/lightCurve_${arr}_all_E${e}.txt ; mv $GC/results/SgrA_lightCurve_${arr}_4tels_all_E${e}_lightcurve.png /veritas/userspace2/mbuchove/SgrA/plots/lightCurve/

#55197
#56293
