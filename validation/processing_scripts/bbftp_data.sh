#!/bin/bash 

loggenfile=$1
[ $2 ] && runMode=$2 || runMode=cat
maxJobs=(3) # set to 0 for unlimited 

scriptDir=${0%/*}
common_functions=$scriptDir/common_functions.sh 
source $common_functions 


baseDataDir=$CSCRATCH/data 

bbftp=bbftp
[[ `hostname` =~ dtn ]] && bbftp=/project/projectdirs/m1304/validation/dtn/bin/bbftp 


laserArray=()

elementIn(){
  local e
  for e in "${@:2}"; do [[ "$e" == "$1" ]] && return 0; done
  return 1 
} # search array for element 

job(){ # date number #bbftpcmd 

    dataDir=$baseDataDir/d${1}

    # this should match command in job script 
    copyCmd="$bbftp -u bbftp -m -p 12 -S -V -e \"get /veritas/data/d${1}/${2}.cvbf $dataDir/\" gamma1.astro.ucla.edu"
    echo $copyCmd

    if [[ "$runMode" == sbatch ]] && [ $maxJobs -ne 0 ]; then 
	n=`squeue -u $(whoami) | grep bbft | wc -l`
	while (( n > maxJobs )); do 
	    sleep 60
	    n=`squeue -u $(whoami) | grep bbft | wc -l` # bbftp gets truncated to bbft
	done # sleep and wait while there are too many jobs 
    fi # if running in sbatch, avoid submitting too many jobs at once and wasting time allocation 
    
    $runMode <<EOF
#!/bin/bash
#SBATCH --partition=shared 
#SBATCH --nodes=1
#SBATCH --mem=1gb
#SBATCH --time=01:00:00
#SBATCH -J ${2}_bbftp
#SBATCH -o $HOME/temp/bbftplog/${2}_bbftp_log.txt

source $common_functions 

test -d $dataDir || makeSharedDir $dataDir
$copyCmd 

EOF

} # create job script for bbftp transfer 


# begin the main loop over the lines in the loggen file 
while read -r line; do 
    set -- $line

    runNum=$2
    date=$1
    dataDir=$baseDataDir/d${date}

    for laser in $3 $4 $5 $6; do 
	elementIn "$laser" "${laserArray[@]}"
	inArray=$?
	if [[ "$laser" != "--" ]] && [ "$inArray" -ne 0 ]; then 
	    laserArray+=("$laser")
	fi # add to array if not present 
    done # loop over lasers in loggen file  

    # don't create job if file exists, or is in progress. * includes temporary bbftp file 
    echo $dataDir/${2}.cvbf 
    test -f $dataDir/${2}.cvbf* && continue 

    # run the job 
    job "$1" "$2"
	
done < $loggenfile # loop over loggen file 

#printf '%s\n' "${laserArray[@]}"

for laser in ${laserArray[@]}; do 

    laserDate=`mysql -h romulus.ucsc.edu -u readonly -s -N -e "use VERITAS; SELECT data_end_time FROM tblRun_Info WHERE run_id=${laser}"` 
    laserDate=${laserDate// */} 
    laserDate=${laserDate//-/} 

    dataDir=$baseDataDir/d${laserDate}
    echo "laser $dataDir/${laser}.cvbf"
    test -f $dataDir/${laser}.cvbf && continue 

    job $laserDate $laser 
done # loop over lasers in array 

exit 0 # great job 
