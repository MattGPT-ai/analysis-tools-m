# this is the basic template for an environment. to make your own, you can either copy and edit this
# OR
# you can create a smaller file that sources this and overwrites the relevant variables, see the other env files for an example 
# this script is designed for bash shells 
# it might be more clear to append variable names set here with _env 

######################################
### NERSC environment variables on ###
######################################
export scratchDir=$CSCRATCH # NERSC global scratch directory (cori) 
#scratchDir=$SCRATCH # NERSC scratch directory that is only available on Edison 
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
### Crab specifics ###
export sourceName=Crab # change this if you're not working on the Crab 
default_cuts=medium # default 
positionFlags="-S6A_TestPositionRA=187.70593 -S6A_TestPositionDEC=12.54112" # optional for stage 6 
sourceExclusionRadius=0.4 
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
sbatchHeader="#!/bin/bash
#SBATCH --nodes=1
#SBATCH --partition=shared"
if [[ "`hostname`" =~ "cori" ]]; then
    docker_load=''
    sbatchHeader="$sbatchHeader
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
zeniths="00,20 30,35" # 40,45" # 50,55 60,65"
#zeniths="00,20 30,35 40,45 50,55 60,65"
offsets="0.50" 
#offsets="0.00,0.50,0.75 0.25,1.00 1.25,1.50 1.75,2.00" 
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
    export SHIFTER=docker:registry.services.nersc.gov/${imageID}
    docker_load=shifter_load # defined in common functions 
    docker_cmd=shifter 
    volumeDirective="--volume=\"$projectDir/:$projectContainer\""
    #volumeDirective="--volume=\"$projectDir/:$projectContainer\" --volume=\"$scratchDir/:$scratchContainer\""
    sbatchHeader="$sbatchHeader
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
