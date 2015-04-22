argument=$1

if [ "$argument" == "background" ]; then
    for z in 10 20 30 40; do
	BDT_script.sh $HOME/runlists/BDT_background_Z${z}.txt background_Z${z}
    done
elif [ "$argument" == "extra" ]; then
    for z in 10 20 30 40; do
	BDT_script.sh $HOME/runlists/BDT_extra_Z${z}.txt background_Z${z}
    done
elif [ "$argument" == "optimize" ]; then
    for z in 10 20 30 40; do
	BDT_script.sh -o -s optimize_Z${z} $HOME/runlists/BDT_optimize_Z${z}.txt 
    done
fi

exit 0
