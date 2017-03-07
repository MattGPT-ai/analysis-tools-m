# common functions used to simplify other scripts, mostly related to logging 

# commands 
copyBinary="rsync -uv" # preferred utility for copying files - rsync does checksum 

logInit() { # logFile
    # print out common information useful for logging 
    date
    echo -n "hostname: " 
    hostname  
    # docker image 
    echo -n "ROOT: $ROOTSYS " 
    root-config --version 
    echo -n "VEGAS git hash: "
    test -f $VEGAS/git_hash.txt && cat $VEGAS/git_hash.txt || echo "$VEGAS/git_hash.txt does not exist!" 
    #git --git-dir $VEGAS/.git describe --always
    echo "image ID: $imageID"

    echo "job ID: $SLURM_JOBID" 
    echo "cores assigned to job: $SLURM_JOB_CPUS_PER_NODE" 

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
    mkdir -v $options $dir 
    chown `whoami`:$group_own $dir # give ownerhip to group defined in environment 
    chmod g+s $dir # set the gid sticky bit 
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

#submitJob(){}

#alias mv='mv -v'
#alias rm='rm -v'
