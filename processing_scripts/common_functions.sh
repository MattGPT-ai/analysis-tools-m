# common functions used to simplify other scripts, mostly related to logging 

# commands 

bigCopy() { # sourcepath destinationpath
    rsync -v $@
} # for copying large files too big for cp 

logInit() { # logFile
    # print out common information useful for logging 

    date
    echo -n "hostname: " 
    hostname  
    echo -n "ROOT: $ROOTSYS " 
    root-config --version 

    if [ "$use_docker" == true ]; then 
	echo "image ID: $imageID"
	echo -n "VEGAS git hash: "
	test -f $VEGAS/git_hash.txt && cat $VEGAS/git_hash.txt || echo "$VEGAS/git_hash.txt does not exist!" 
    else
	git --git-dir $VEGAS/.git describe --always
    fi

    if [ "$batch_cmd" == sbatch ]; then 
	echo "job ID: $SLURM_JOBID" 
	echo "cores assigned to job: $SLURM_JOB_CPUS_PER_NODE" 
    elif [ "$batch_cmd" == qsub ]; then 
	echo "job ID: $PBS_JOBID"
	echo "number of nodes: $(cat $PBS_NODEFILE | egrep -v '^#'\|'^$' | wc -l | awk '{print $1}')"
	cat $PBS_NODEFILE
    fi

    bash --version 

} # logInit 

# process the log files properfly when job succeeds 
logStatus() { # logfile status 
    
    local logfile=$1
    test -f "$logfile" || ( echo "must supply a logfile! $1" ; return 1 ) 

    local status=$2
    test -z "$status" && status=0 

    #if [ $status -eq 0 ]; then 
    local workdir=${logfile%%/log/*}
    local logcomplete=$workdir/completed_jobs/${logfile##*/}
    local logfail=$workdir/failed_jobs/${logfile##*/} 
    test -f $logcomplete && unlink $logcomplete 
    ln -s -v $logfile $workdir/completed_jobs/ 
    test -f $logfail && mv $logfail $workdir/backup/
    #else
    #mv $logfile $logfail
    #fi

} # logStatus


BOLD=`tput bold`
NORM=`tput sgr0`
# echo in red to stderr 
echoErr() { # message 
    >&2 echo -e "\e[0;31m ${1} \e[0m" 
} # echoErr 

makeSharedDir(){ # dir options
    test -n "$1" && local dir=$1 || ( echo "must supply a directory name!" ; return 1 ) 
    shift    
    mkdir -v $@ $dir #-m 1755
    chown `whoami`:$group_own $dir # give ownerhip to group defined in environment 
    [ $def_mode ] && chmod -m $def_mode $dir || chmod g+s $dir # set the gid sticky bit 
} # make directory with shared read-access 

checkForDirs(){ # mode dirs
    local msg=false
    local mode=$1
    shift 
    local dirs="$@"
    for dir in $dirs; do 
	if [ ! -d "$dir" ]; then 
	    msg=true 
	    [ $mode == print ] && echo "Directory $dir does not exist! " 
	    [ $mode != print ] && makeSharedDir $dir
	fi
    done
    [ $msg == true ] && echo "These directories will be automatically created if script is submitted"
} # check for directories 

# retrieve the data file from hsi 
getDataFile() { # filename [destination] 
    # filename should be partial path like data/d${date}/${runNum}.cvbf 
    # this is where it would be in hsi or $scratchDir 
    # if this fails, could attempt bbftp from UCLA or other archive 
    test -n "$1" && local filename=$1 || ( echoErr "Must supply a filename to retrieve!" ; return 1 ) 
    #test -n "$2" && local destination=$2
    
    local directory=${filename%/*}

    if [ -f $scratchDir/$filename ] && [ -s $scratchDir/$filename ]; then 
	return 0 
    else 
	local dir=$scratchDir/$directory # scratch path  
	test -d $dir || makeSharedDir $dir -p
	# would be good to make permissions correct here 

	hsi "get $scratchDir/$filename : $hsiDir/$filename" 
	exitCode=$?
	echo "hsi exit code: $exitCode"
	
	# remove leftover file of 0 size 
	[ -f $scratchDir/$filename ] && [ ! -s $scratchDir/$filename ] && rm -v $scratchDir/$filename

	if [ "$exitCode" -ne 0 ] || [ ! -f $scratchDir/$filename ]; then  
            bbCmd="$bbftp -u bbftp -m -p 12 -S -V -e \"get $archiveDataDir/$dataFile $scratchDir/\" gamma1.astro.ucla.edu"
	    echo "hsi retrieval seems to have failed. attempting bbftp tranfser.."
	    echo "$bbCmd"
	    $bbCmd 
	fi # attempt bbftp if hsi fails 

	# permissions 
    fi # scratch file existence 

    test -f $scratchDir/$filename
    exitCode=$? 
    test "$exitCode" -eq 0 || echoErr "failed to retrieve file $filename. make sure it is available on the NERSC cluster or the UCLA archive! check $scratchDir and $hsiDir"
    
    return $exitCode 

} # getDataFile 
#getSimFile 

shifter_load(){ 
    [[ ! "`hostname`" =~ "cori" ]] && module load shifter
    echo "image to be loaded: $imageID"
} # load shifter module 

elementIn(){ #array=() element 
  local e
  for e in "${@:2}"; do [[ "$e" == "$1" ]] && return 0; done
  return 1 
} # search array for element. return 0 if found, 1 if not 

getRunDate(){ # runID 

    local runID=$1
    local date=`mysql -h romulus.ucsc.edu -u readonly -s -N -e "use VERITAS; SELECT data_end_time FROM tblRun_Info WHERE run_id=${runID}"` 

} # get run date 

# creat the batch header for a particular batch system 
createBatchHeader() { # batch_system

    local OPTIND arg_M arg_T batch_sys  # need to keep these in local scope or unexpected behavior occurs

    while getopts t:T:m:M:q:N:o:n:p: FLAG; do 
	case $FLAG in 
	    t) local arg_t=($OPTARG) ;; # time as an int (hours) 
	    T) arg_T=$OPTARG ;; # time as a string 
	    m) local arg_m=($OPTARG) ;; # mem as an int (gb) 
	    M) arg_M=$OPTARG ;; # mem as a string 
	    q) local arg_q=$OPTARG ;; # queue / partition 
	    N) local arg_N=$OPTARG ;; # job name 
	    o) local arg_o=$OPTARG ;; # output file 
	    n) local arg_n=$OPTARG ;; # number of nodes (int)
	    C) local arg_C=$OPTARG ;; # cluster (can be comma separated list) 
	    p) local arg_p=$OPTARG ;; # job priority 
	    ?) echoErr "flag $FLAG not acceptable!"
	esac 
    done # loop over options 
    shift $((OPTIND-1))

    test -n "$1" && batch_sys="$1" || batch_sys=$batch_cmd 
    if [ -z "$batch_sys" ]; then
	echo 'batch system must be specified by either supplying it here or defining $batch_cmd !!! '
	return 1
    fi

    # convert int args to string
    [ $arg_m ] && [ -z "$arg_M" ] && arg_M=${arg_m}gb
    if [ $arg_t ] && [ -z "$arg_T" ]; then 
	if ((arg_t < 10)); then
	    arg_T=0${arg_t}:00:00
	else
	    arg_T=${arg_t}:00:00
	fi
    fi # make string out of time 

    case $batch_sys in 
	sbatch | slurm)
	    batch_directive='#SBATCH'
	    echo '#!/bin/bash'	    
	    
	    [ -z "$qp" ] && qp=shared # set the default partition 
	    [ $arg_q ] && qp=$arg_q
	    echo "#SBATCH --partition=${qp}"
	    [ "$docker_cmd" == shifter ] && echo "#SBATCH --image=docker:registry.services.nersc.gov/${imageID} "
	    
	    [ $arg_N ] && echo "#SBATCH -J $arg_N"
	    [ $arg_T ] && echo "#SBATCH --time=${arg_T}"
	    [ $arg_n ] && echo "#SBATCH --nodes=${arg_n}"
	    [ $arg_M ] && echo "#SBATCH --mem=${arg_M}"
	    #[ $arg_p ] && echo "#SBATCH --niceness=${arg_p}"

	    
	    if [[ "$(hostname)" =~ "cori" ]]; then
		echo '#SBATCH --qos=normal '
		echo '#SBATCH -C haswell '
	    fi
	    ;;

	qsub | PBS)
	    batch_directive='#PBS'
	    [ -z "$qp" ] && qp=batch # set the default queue
	    [ $arg_q ] && qp=$arg_q # or override it

	    local res_array=()
	    [ $arg_n ] && res_array+=("nodes=${arg_n}") 
	    [ $arg_M ] && res_array+=("mem=${arg_M}") 
	    [ $arg_T ] && res_array+=("walltime=${arg_T}")
	    local res_list=""
	    for res in ${res_array[@]} ; do 
		[ $res_list ] && res_list="${res_list},"
		res_list="${res_list}${res}"
	    done 

	    echo '#PBS -S /bin/bash'
	    echo '#PBS -j oe' # slurm joins stdout and stderr by default so emulate this 
	    echo "#PBS -q $qp"
	    echo "#PBS -W umask=$(umask)"

	    [ $res_list ] && echo "#PBS -l $res_list"

	    [ $arg_N ] && echo "#PBS -N $arg_N"
	    [ $arg_p ] && echo "#PBS -p ${arg_p}"

	    ;;

	?)
	    echoErr "batch submission system $batch_sys is not supported! "
	    echo "you can create a case for this system in createBatchMode in common_functions.sh"
	
    esac # process args for specified batch system 

    [ "$arg_o" ] && echo "${batch_directive} -o $arg_o" # this is the same for both sbatch and qsub 


    return 0 
} # createBatchHeader


parseCommonOpts() { # $@
    local skipnext 

    # first find the environment and determine whether or not to use docker 
    for i; do 
	if [ "$skipnext" == true ]; then
	    skipnext=false
	    continue
	fi
	case "$i" in 
	    --no-docker)
		export use_docker=false 
		shift ;; 
	    --use-docker)
		export use_docker=true
		shift ;; 
	    -e|--env)
		environment=${2}
		skipnext=true ; shift 2 ;;
	    *)
		args="$args '$i'"
		shift
		;; 
	esac
    done # find environment 
    for env in $environment; do source $env || exit 1 ; done 

    eval set -- $args
    args=""

    for i; do 
	if [ "$skipnext" == true ]; then
	    skipnext=false
	    continue
	fi
	case "$i" in 
	    --submit|-q) 
		[ $batch_cmd ] || '$batch_cmd is not set, so nothing can be submitted. check your environment variable!'
		runMode=$batch_cmd 
		s6Opts="$s6Opts -S6A_Batch=1"
		shift ;; 
	    --queue)
		runMode=$batch_cmd
		s6Opts="$s6Opts -S6A_Batch=1"
		qp=${2} 
		skipnext=true ; shift 2 ;;
	    -Q) runMode=$batch_cmd
		s6Opts="$s6Opts -S6A_Batch=1"
		qp=express # UCLA-specific 
		shift ;; 
	    -r|--run) # the command that runs the herefile
		runMode="$2" 
		skipnext=true ; shift 2 ;;	
	    -n)
		nJobsMax=($2) 
		skipnext=true ; shift 2 ;; 	
	    -p|--priority) 
		priority=($2) 
		skipnext=true ; shift 2 ;; 	    
	    *)
		args="$args '$i'"
		shift ;; 
	esac 
    done # loop over common args 

    debugMsg " 2nd $runMode"
        
    return 0 
} # parseCommonOpts

#sendMail()

debugMsg() {
    [ "$debug" == true ] && echo "$@"
}

# functions used for creating associative arrays when they are not available, such as in bash3.x on NERSC 
hput () {
  eval hash_"$1"='$2'
} # create association
hget () {
  eval echo '${hash_'"$1"'#hash}' #hash probably not necessary 
} # retrieve 

strip(){ # varname (without $)
    eval "$1"='$( echo $'"$1"')'
} # removes leading and trailing whitespace 

#verify_md5sum()

#submitJob(){}

#alias mv='mv -v'
#alias rm='rm -v'
