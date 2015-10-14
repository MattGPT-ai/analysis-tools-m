queueDel() { # 

    key=$1
    while read -r line; do 
	if [[ "$line" =~ "Job_Name" ]] && [[ "$line" =~ "$key" ]]; then 
	    if [[ "$previousLine" =~ "Job Id:" ]]; then
		set -- $previousLine
		echo ${3%%.gamma2.astro.ucla.ed
	    fi	    
	fi
	previousLine="$line"
    done < <(qstat -f -1)

    echo "Delete these runs from queue? Y or n"
    read -r response
    if [ "$response" != "Y" ]; then
	exit

    while read -r line; do 
    if [[ "$line" =~ "Job_Name" ]] && [[ "$line" =~ "$key" ]]; then 
	if [[ "$previousLine" =~ "Job Id:" ]]; then
	    set -- $previousLine
	    qdel ${3%%.gamma2.astro.ucla.edu}
	    sleep 3
	fi	    
    fi
    previousLine="$line"
    done < <(qstat -f -1)

} # queueDel
