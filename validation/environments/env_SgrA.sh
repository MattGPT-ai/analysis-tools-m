# this is the basic template for an environment. to make your own, you can either copy and edit this
# OR
# you can create a smaller file that sources this and overwrites the relevant variables, see the other env files for an example 
# this script is designed for bash shells 
# it might be more clear to append variable names set here with _env 

###################################
### gamma environment variables ###
###################################

batch_cmd=qsub
export scratchDir=/scratch/mbuchove # NERSC global scratch directory (cori) 
export projectDir=$GC # the external directory volume mounts to 
export archiveDataDir=/veritas/data # directory with data on the UCLA archive  
export archiveSimDir=/veritas/upload/OAWG/stage2/vegas2.5 # directory with stage 2 sims on UCLA archive 
#export bbftp=`which bbftp` # the bbftp binary file for use with retrieving data from the archive 

# mounted directories within shifter / doocker containers. shifter will still allow you to use the original path after mounting
export scratchContainer=/external_data # scratch directory mounted in container volume 
export projectContainer=/external_output # volume directory within container 

##############################
##### CUSTOM ENVIRONMENT ##### 
##############################
### SgrA specifics ###
export sourceName=SgrA # change this if you're not working on the Crab 
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

#s6Opts="$s6Opts -RBM_UseZnCorrection=1"
#s6Opts="$s6Opts -SP_EnergyBinning=1 -SP_BinningFilename=$HOME/config/SgrA_spectral-binning_Andy.txt"
#s6Opts="$s6Opts -SP_EnergyBinning=1 -SP_BinningFilename=$HOME/config/SgrA_spectralBinning.txt"

exclusionList=$HOME/config/SgrA_exclusionList_full.txt 


UL_Gamma1=-2.0
UL_Gamma2=-2.5
UL_Gamma3=-3.0


U2=/veritas/userspace2/mbuchove
# set this variable to the top level of your analysis 
export workDir=$GC # the paths worked with within the processing scripts 
export dataDir=$scratchDir/data # where to store vbf files, best to let scripts copy from hsi to scratch 
export laserDir=$LASERDIR # where processed laser files are stored and logged 
export tableWork=$U2/tables # path to store intermediate table files 
export ltDir=$TABLEDIR # directory with completed LTs for use with stage 4 processing of data and sims 
export eaDir=$TABLEDIR # directory with completed EAs that will be written into stage 6 runlists 
export simWork=$U2/sims # where you store processed sims you create - these will be used to create EAs
export stage2simDir=$archiveSimDir # where stage 2 sims are stored (or will be copied to if they are not present ) - they will be used to create stage 4 sims and LTs 
#export stage2simDir=$projectDir/validation/sims/stage2 # where the preprocessed sims are stored, project default is in project dir 


######################
### slurm / sbatch ### 
######################
use_docker=false
submitHeader="#!/bin/bash
#SBATCH --nodes=1
#SBATCH --partition=shared"
if [[ "`hostname`" =~ "cori" ]]; then
    docker_load=''
    submitHeader="$submitHeader
#SBATCH --qos=normal 
#SBATCH -C haswell"
fi

# job processing - signals for traps 
#signals="1 2 3 4 5 6 7 8 11 13 15 30"

#######################################
### simulation and table variables  ###
#######################################
ltMode=custom 
ltVegas=vegas255 # these parameters determine the filename of the lookup tables when auto is selected 
simulation=GrISUDet # detector simulation, other option CORSIKA 
model=Oct2012 # simulation model 
atmospheres="21 22"
arrays="oa na ua"
# parameter space specification for sims and tables 
zeniths="40,45 50,55 60,65"
offsets="0.50,0.75" 
#to compact zeniths:
zenrange="${zeniths%%-*}-${zeniths##*-}"
#azimuths="0,45 90,135 180,225 270,315"
cuts_set="soft medium hard" # only relevant for EAs
# loose cuts not performed by default 


############################
##### DOCKER / SHIFTER ##### 
############################
test -z "$use_docker" && use_docker=true # by default, use docker 
# this can be turned off either here or in the options when running script files
# when this file is sourced it will adjust the environment accordingly 
if [ "$use_docker" != false ]; then 
# docker shifter:
    export imageID=764f612bbc90:VV-rc 
    #export SHIFTER=docker:registry.services.nersc.gov/${imageID}
    docker_load="" # defined in common functions 
    docker_cmd=docker 
    volumeDirective="--volume=\"$projectDir/:$projectContainer\""
    #volumeDirective="--volume=\"$projectDir/:$projectContainer\" --volume=\"$scratchDir/:$scratchContainer\""
    submitHeader="$submitHeader
#SBATCH --image=docker:registry.services.nersc.gov/${imageID} "

    # VEGAS should be set to /software/vegas inside docker image 
    # you can also adjust the 

else ### otherwise set VEGAS environment explicitly ###

    docker_load=''
    docker_cmd=''
    
    # if VEGAS environment not set, your bashrc.ext should be loaded by default 
    # note the paths are appended differently for cmake builds 

    ###################
    ##### VERITAS #####
    ###################

    #export VERITASBASE=/project/projectdirs/m1304/veritasEdison
    #export VEGAS=$VERITASBASE/src/vegas-v2_5_5
    #source $VERITASBASE/src/root-v5-34/bin/thisroot.sh

    #export LD_LIBRARY_PATH=$VERITASBASE/lib/:${LD_LIBRARY_PATH}
    #export PKG_CONFIG_PATH=$VERITASBASE/lib/pkgconfig/:${PKG_CONFIG_PATH}

    #export LD_LIBRARY_PATH=$VEGAS/common/lib/:$LD_LIBRARY_PATH
    #export LD_LIBRARY_PATH=$VEGAS/diagnostics/lib/:$LD_LIBRARY_PATH
    #export LD_LIBRARY_PATH=$VEGAS/diagnostics/displays/lib/:$LD_LIBRARY_PATH
    #export LD_LIBRARY_PATH=$VEGAS/resultsExtractor/lib/:$LD_LIBRARY_PATH
    #export LD_LIBRARY_PATH=$VEGAS/showerReconstruction2/lib/:$LD_LIBRARY_PATH

    #export PATH=$VEGAS/bin/:$VERITASBASE/bin/:$VERITASBASE/include/:$PATH

fi # 

############################
### OVERRIDING FUNCTIONS ### 
############################
# for example if you want to change the sim file naming convention, redefine setSimName 

setSimNames() { # zen offset noise stage 
    # $array and $atm must be set 

    simFileBase2=Oct2012_${array}_ATM${atm}_vegasv250rc5_7samples_${1}deg_${2//./}wobb_${3}noise
    simFile2=$stage2simDir/Oct2012_${array}_ATM${atm}/${simFileBase2}.root
    simSubDir=Oct2012_${array}_ATM${atm} # for its place in archive 
#simBaseDir=

    simFileBase=Oct2012_${array}_ATM${atm}_${ltVegas}_7samples_${1}deg_${2//./}wobb_${3}noise
    
} # print out the simulation name 


### for differentiating path in container vs on node ### 
# working dir within shell, local NERSC directory 
export localWork=$projectDir/validation/$sourceName # working dir on NERSC filesystem
# the equivalent path above, but in the directory mounted within the container 
export containerWork=$projectContainer/validation/$sourceName  
# not currently necessary 
