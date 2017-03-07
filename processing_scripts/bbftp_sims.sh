#!/bin/bash 

[ $1 ] && runMode=$1 || runMode=cat
maxJobs=(5) # set to 0 for unlimited 

baseDir=/veritas/upload/OAWG/stage2/vegas2.5
stage2simDir=/global/project/projectdirs/m1304/validation/sims/processed/stage2

bbftp=bbftp
[[ `hostname` =~ dtn ]] && bbftp=/project/projectdirs/m1304/validation/dtn/bin/bbftp 


wobble=050
arrays="oa na ua"
atms="21 22"
zeniths="00 20 30 35 40 45"

job(){ # filename

    # this should match command in job script 
    copyCmd="$bbftp -u bbftp -m -p 12 -S -V -e \"get $1 $stage2simDir/\" gamma1.astro.ucla.edu"
    echo $copyCmd

    if [[ "$runMode" == $batch_cmd ]] && [ $maxJobs -ne 0 ]; then 
	n=`squeue -u $(whoami) | grep bbft | wc -l`
	while (( n > maxJobs )); do 
	    sleep 60
	    n=`squeue -u $(whoami) | grep bbft | wc -l` # bbftp gets truncated to bbft
	done # sleep and wait while there are too many jobs 
    fi # if submitting jobs, avoid submitting too many jobs at once and wasting time allocation 
    
    $runMode <<EOF
#!/bin/bash
#SBATCH --partition=shared 
#SBATCH --nodes=1
#SBATCH --mem=1gb
#SBATCH --time=01:00:00
#SBATCH -J bbftp_${arr}_${atm}_${zen}_${noise}
#SBATCH -o $HOME/temp/bbftplog/${arr}_${atm}_${zen}_${noise}_bbftp_log.txt

$copyCmd

EOF

} # job 

for arr in $arrays; do 
    for atm in $atms; do 
	for zen in $zeniths; do 
	    for noise in 100 150 200 250 300 350 400 490 605 730 870; do 

		subDir=Oct2012_${arr}_ATM${atm}/${zen}_deg
		filename=Oct2012_${arr}_ATM${atm}_vegasv250rc5_7samples_${zen}deg_${wobble}wobb_${noise}noise.root 
		test -f $stage2simDir/$filename && continue 
		job $baseDir/$subDir/$filename 

	    done 
	done 
    done 
done 

exit 0 # great job 
