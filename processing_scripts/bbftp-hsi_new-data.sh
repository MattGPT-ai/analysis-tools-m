#!/bin/bash 

# script for pulling new data into hsi. NERSC-specific!

scriptDir=${0%/*} 
source $scriptDir/../environments/env_NERSC.sh 
#source scriptDir/common_functions.sh

# don't need to parse args, just specify the run type 
[ $1 ] && runMode=$1 || runMode=cat

# set name for files containing file lists 
arc_ls_logfile=$projectDir/temp/ls_all_data.txt
hsi_ls_out=$projectDir/validation/sums/data_hsi_ls_out.txt
checksumFile=$projectDir/validation/sums/data_md5sums.txt



ssh `whoami`@gamma2.astro.ucla.edu 'find -L /veritas/data/ -name "*.cvbf" | xargs ls -l' > $arc_ls_logfile  #-mtime -90
#ssh `whoami`@gamma2.astro.ucla.edu 'ls -l /veritas/data/d*/*.cvbf' > $arc_ls_logfile 
hsi "ls -lR $hsiDir" &> $hsi_ls_out  


while read -r line; do 
    set -- $line

    file=${9##*/}
    date=${9%/$file}
    date=${date#/veritas/data/d}

    # don't create job if file exists, or is in progress. * includes temporary bbftp file 
    test -f $scratchDir/${2}.cvbf* && continue 
    scratchDate=$scratchDir/d${date}

    transferCmd="bbftp -u bbftp -m -p 12 -S -V -e \"get /veritas/data/d${date}/$file $scratchDate/\" gamma1.astro.ucla.edu"


    if [ `grep $file $hsi_ls_out | wc -l` -ne 0 ]; then
	continue ; fi 
    
    mkdirCmd="hsi 'mkdir $hsiDir/data/d${date}' "
    #[ $(grep d${date} $hsi_ls_out | wc -l ) -ne 0 ] && mkdirCmd=""

    #echo $transferCmd
    #echo $file 
    #echo "hsi put $file : $hsiDir/data/d${date}/"
    
    $runMode <<EOF

    test -d $scratchDate || mkdir -v $scratchDate
    $transferCmd 

    cd $scratchDate/
    $mkdirCmd

    md5sum $file >> $checksumFile

    chmod 660 $file
    chown $(whoami):${group_own} $file


    hsi "put $file : $hsiDir/data/d${date}/$file"

    rm -v $scratchDate/$file 

    sleep 1 
 
EOF

echo
   
done < $arc_ls_logfile # loop over loggen file 



exit 0 
