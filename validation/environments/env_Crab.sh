# this is the basic template for an environment. to make your own, you can either copy and edit this
# OR
# you can create a smaller file that sources this and overwrites the relevant variables, see the other env files for an example 
# this script is designed for bash shells 
# it might be more clear to append variable names set here with _env 

# get the directory containing this environment file 
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
#DIR="$( dirname "${BASH_SOURCE[0]}" )"

####################################
### NERSC environment variables  ###
####################################
export scratchDir=$CSCRATCH # NERSC global scratch directory (cori) 
#scratchDir=$SCRATCH # NERSC scratch directory that is only available on Edison 
export projectDir=/global/project/projectdirs/m1304 # the external directory volume mounts to 
export hsiDir=/home/projects/m1304 # HPSS directory with our data and stage 2 sims 
export archiveDataDir=/veritas/data # directory with data on the UCLA archive  
export archiveSimDir=/veritas/upload/OAWG/stage2/vegas2.5 # directory with stage 2 sims on UCLA archive 
export bbftp=$projectDir/validation/veritas/bin/bbftp # the bbftp binary file for use with retrieving data from the archive 
[[ `hostname` =~ dtn ]] && bbftp=$projectDir/validation/dtn/bin/bbftp # use a different one if on the data transfer nodes 

# mounted directories within shifter / doocker containers. shifter will still allow you to use the original path after mounting
export scratchContainer=/external_data # scratch directory mounted in container volume 
export projectContainer=/external_output # volume directory within container 

# ownership and permission settings for sharing data 
group_own=m1304 # the project group with which all NERSC users should be associated 
umask 0027 # sets default file permissions 

##############################
##### CUSTOM ENVIRONMENT ##### 
##############################

### Crab specifics ###
export sourceName=Crab # change this if you're not working on the Crab 
default_cuts=medium # default 
# stage 6 variables 
s6Opts="-S6A_ExcludeSource=1 -S6A_DrawExclusionRegions=2" #-S6A_Spectrum=1
suppressRBM=1
s6Opts="$s6Opts -S6A_SourceExclusionRadius=0.4 "
binfile_relpath="../config_files/EnergyBins_coarse.txt" # adds energy binning filename with path relative to directory containing execute-stage6.sh 
s6Opts="$s6Opts -SP_EnergyBinning=1 "
positionFlags="-S6A_TestPositionRA=187.70593 -S6A_TestPositionDEC=12.54112" # optional for stage 6 
# set this variable to the top level of your analysis 
export workDir=$scratchDir/$sourceName # the paths worked with within the processing scripts 
export dataDir=$scratchDir/data # where to store vbf files, best to let scripts copy from hsi to scratch 
export laserDir=$projectDir/validation/lasers # where processed laser files are stored and logged 
export tableWork=$scratchDir/tables # path to store intermediate table files 
export ltDir=$tableWork/combined # directory with completed LTs for use with stage 4 processing of data and sims 
export eaDir=$tableWork/combined # directory with completed EAs that will be written into stage 6 runlists 
export simWork=$scratchDir/sims # where you store processed sims you create - these will be used to create EAs
export stage2simDir=$scratchDir/sims/stage2 # where stage 2 sims are stored (or will be copied to if they are not present ) - they will be used to create stage 4 sims and LTs 
#export stage2simDir=$projectDir/validation/sims/stage2 # where the preprocessed sims are stored, project default is in project dir 


######################
### slurm / sbatch ### 
######################
submitHeader="#!/bin/bash
#SBATCH --nodes=1
#SBATCH --partition=shared"
if [[ "`hostname`" =~ "cori" ]]; then
    docker_load=''
    submitHeader="$submitHeader
#SBATCH --qos=normal 
#SBATCH -C haswell"
fi


############################
##### DOCKER / SHIFTER ##### 
############################
# when this file is sourced it will adjust the environment accordingly 
if [ "$use_docker" != false ]; then 
# docker shifter:
    export imageID=764f612bbc90:VV-rc 
    export SHIFTER=docker:registry.services.nersc.gov/${imageID}
    docker_load=shifter_load # defined in common functions 
    docker_cmd=shifter 
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

#setSimName() {
#simFileBase=$newfilenameconvention
#}


### for differentiating path in container vs on node ### 
# working dir within shell, local NERSC directory 
export localWork=$projectDir/validation/$sourceName # working dir on NERSC filesystem
# the equivalent path above, but in the directory mounted within the container 
export containerWork=$projectContainer/validation/$sourceName  
# not currently necessary 
