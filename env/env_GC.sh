##############################
##### CUSTOM ENVIRONMENT ##### 
##############################
### SgrA specifics ###
export sourceName=GC # change this if you're not working on the Crab 
export workDir=$workSpace/$sourceName # the paths worked with within the processing scripts 
default_cuts=medium # default 

loggenFile=$HOME/runlists/SgrA_wobble_4tels.txt
#loggenFile=$HOME/runlists/SgrA_wobble_fixed.txt 
positionFlags="-S6A_TestPositionRA=266.4168 -S6A_TestPositionDEC=-29.0078"

s6Opts="$s6Opts -EA_RealSpectralIndex=-2.6"
#s6Opts="$s6Opts -UL_PhotonIndex=2.6 -EA_SimSpectralIndex=-2.6"
s6Opts="$s6Opts -S6A_SourceExclusionRadius=0.4"

if [[ ! "$s6Opts" =~ "RBM_CoordinateMode" ]]; then 
    s6Opts="$s6Opts -RBM_CoordinateMode=\"Galactic\"" 
fi 

telCombosToDeny=ANY2 # for process_script.sh
s6Opts="$s6Opts -TelCombosToDeny=${telCombosToDeny}"

s6Opts="$s6Opts -RBM_UseZnCorrection=1 -RBM_UseZnCorrection=1"
#s6Opts="$s6Opts -SP_EnergyBinning=1 -SP_BinningFilename=$workDir/config/SgrA_spectral-binning_Andy-comparison.txt"
#s6Opts="$s6Opts -SP_EnergyBinning=2 -SP_BinningFilename=$workDir/config/SgrA_spectralBinning.txt"

exclusionList=$HOME/config/SgrA_exclusionList_full.txt 


UL_Gamma1=-2.0
UL_Gamma2=-2.5
UL_Gamma3=-3.0

