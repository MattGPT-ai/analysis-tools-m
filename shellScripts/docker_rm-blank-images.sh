opt=$@

n=(0)
docker images | while read -r line; do 
    set -- $line
    n=$((n+1))
    if ((n==1)); then continue; fi

    repository=$1
    tag=$2
    imageID=$3

    if [ $tag == '<none>' ]; then
	docker rmi $opt $imageID
	#echo $imageID
    fi 
        
done # loop over images 

exit 0 
