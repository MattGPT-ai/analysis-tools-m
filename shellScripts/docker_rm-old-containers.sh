images=$(docker images)

n=(0)
docker ps -a | while read -r line1; do 
    set -- $line1
    n=$((n+1))
    if ((n==1)); then continue; fi

    containerID=$1
    imageID=$2

    found=false
    printf '%s\n' "$images" | while IFS= read -r line2; do
	set -- $line2
	if [ "$3" == "$imageID" ]; then
	        found=true
		fi
    done
    
    if [ $found == false ]; then
	docker rm $containerID
    fi 
        
done # loop over lines 
