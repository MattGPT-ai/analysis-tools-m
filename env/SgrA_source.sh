##############################
##### CUSTOM ENVIRONMENT ##### 
##############################
### SgrA specifics ###
export sourceName=SgrA # change this if you're not working on the Crab 
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

minTels=(4) # to be included in stage 6 (spectrum) runlist 
telCombosToDeny=ANY2 # for process_script.sh
ea_ext=_Deny2
s6Opts="$s6Opts -TelCombosToDeny=${telCombosToDeny}"
DistanceUpper=1.38
ImpactDistanceUpper=1200
zeniths="40,45 50,55 60,65"
offsets="0.50,0.75"

binningFile=$workDir/config/SgrA_spectral-binning_Andy-fine4.txt
s6Opts="$s6Opts -SP_FitNormEnergy=3.5" 
s6Opts="$s6Opts -SP_EnergyBinning=4 -SP_BinningFilename=$binningFile"
#s6Opts="$s6Opts -SP_EnergyBinning=1 -SP_BinningFilename=$workDir/config/SgrA_spectral-binning_Andy-comparison.txt"
#s6Opts="$s6Opts -RBM_UseZnCorrection=1 -RBM_UseZnCorrection=1"

# acceptance needs to be made functional 
acceptanceFile=$GC/processed/acceptanceMaps/SgrA_acceptance_off_4tel.root

exclusionList=$GC/config/SgrA_exclusionList_planecircles.txt 


UL_Gamma1=-2.0
UL_Gamma2=-2.5
UL_Gamma3=-3.0

