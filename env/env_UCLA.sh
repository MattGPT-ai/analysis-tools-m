# this is the basic template for an environment. to make your own, you can either copy and edit this
# OR
# you can create a smaller file that sources this and overwrites the relevant variables, see the other env files for an example 
# this script is designed for bash shells 
# it might be more clear to append variable names set here with _env 

# get the directory containing this environment file 
ENVDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
#DIR="$( dirname "${BASH_SOURCE[0]}" )"

vegasV=vegas255 # need to implement 

###################################
### gamma environment variables ###
###################################

batch_cmd=qsub
copy_local=true # copy data files from archive to scratch, currently for UCLA cluster 
bigCopy(){ 
    while [[ "$(ps cax)" =~ 'bbcp' ]]; do sleep $((RANDOM%10)); done
    bbcp -e -E md5= $@ 
    # exits with return code of last command 
} # override function in common_functions.sh 

export workSpace=/veritas/userspace2/mbuchove
export scratchDir=/scratch/mbuchove # NERSC global scratch directory (cori) 
export projectDir=$GC # the external directory volume mounts to 
export archiveDataDir=/veritas #/data is appended in other scripts # directory with data on the UCLA archive  
export archiveSimDir=/veritas/upload/OAWG/stage2/vegas2.5 # directory with stage 2 sims on UCLA archive 
#export bbftp=`which bbftp` # the bbftp binary file for use with retrieving data from the archive 

# mounted directories within shifter / doocker containers. shifter will still allow you to use the original path after mounting
export scratchContainer=/external_data # scratch directory mounted in container volume 
export projectContainer=/external_output # volume directory within container 


######################
### slurm / sbatch ### 
######################
use_docker=false

umask 0002 # restricts permissions upon file creation 
# - it sets permissions as though you changed (chmod) mode = mode & ~ mask evaluated bitwise
def_mod=(1755) 
group_own=veritas # for shared directories and files 

# job processing - signals for traps 
#signals="1 2 3 4 5 6 7 8 11 13 15 30"


U2=/veritas/userspace2/mbuchove
# set this variable to the top level of your analysis 
export dataDir=$scratchDir/data # where to store vbf files, best to let scripts copy from hsi to scratch 
export laserDir=$LASERDIR # where processed laser files are stored and logged 
export tableWork=$U2/tables # path to store intermediate table files 
export ltDir=$TABLEDIR # directory with completed LTs for use with stage 4 processing of data and sims 
export eaDir=$TABLEDIR # directory with completed EAs that will be written into stage 6 runlists 
export simWork=$U2/sims # where you store processed sims you create - these will be used to create EAs
export stage2simDir=$archiveSimDir # where stage 2 sims are stored (or will be copied to if they are not present ) - they will be used to create stage 4 sims and LTs 
#export stage2simDir=$projectDir/validation/sims/stage2 # where the preprocessed sims are stored, project default is in project dir 

############################
### OVERRIDING FUNCTIONS ### 
############################
# for example if you want to change the sim file naming convention, redefine setSimName 

setSimNames() { # zen offset noise stage 
    # $array and $atm must be set 

    simFileBase2=Oct2012_${array}_ATM${atm}_vegasv250rc5_7samples_${1}deg_${2//./}wobb_${3}noise
    simFile2=$stage2simDir/Oct2012_${array}_ATM${atm}/${1}_deg/${simFileBase2}.root
    simSubDir=Oct2012_${array}_ATM${atm} # for its place in archive 
#simBaseDir=

    simFileBase=Oct2012_${array}_ATM${atm}_${ltVegas}_7samples_${1}deg_${2//./}wobb_${3}noise
    
} # print out the simulation name 


#######################################
### simulation and table variables  ###
#######################################
ltMode=custom 
ltVegas=vegas255 # these parameters determine the filename of the lookup tables when auto is selected 
simulation=GrISUDet # detector simulation, other option CORSIKA 
model=Oct2012 # simulation model 
# parameter space specification for sims and tables 
# if you add arrays or atms then they could override your options. 
#[ -z "$arrays" ] && arrays="oa na ua" 
zeniths="40,45 50,55 60,65" # avoid leaving extra spaces at the end
offsets="0.50,0.75" 
#to compact zeniths:
zenrange="${zeniths%%-*}-${zeniths##*-}"
#azimuths="0,45 90,135 180,225 270,315" # splitting up azimuths doesn't work well in VEGAS v255
[ -z "$cuts_set" ] && cuts_set="soft medium hard" # only relevant for EAs
# loose cuts not performed by default 


############################
##### DOCKER / SHIFTER ##### 
############################
test -z "$use_docker" && use_docker=false # by default, use docker 
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

    # file that sets up VEGAS environment 
    #source $HOME/environments/vegas255rc.sh

fi # 

### for differentiating path in container vs on node ### 
# working dir within shell, local NERSC directory 
