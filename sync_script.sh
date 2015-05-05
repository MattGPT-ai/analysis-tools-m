#!/bin/bash

VEGASdir=/home/mbuchove/Dropbox/VEGAS/
options="-urv --rsh=ssh"

while getopts d FLAG; do 
    case $FLAG in
	d)
	    options="$options --delete"
	    ;;
    esac
done # getopts

rsync -uv $VEGAS/BDT/optimize_BDT_cuts $VEGAS/BDT/viewStage6BDTCut.C mbuchove@128.97.69.2:$VEGASdir/BDT/scripts_macros/
rsync -uv /home/mbuchove/.bashrc /home/mbuchove/.emacs /home/mbuchove/.bash_profile mbuchove@128.97.69.2:$VEGASdir/

for dir in bin cuts config environments log runlists textDocs work; do
    rsync $options $HOME/${dir}/ mbuchove@128.97.69.2:$VEGASdir/${dir}/
done

for dir in macros plots; do
    rsync $options $BDT/${dir}/  mbuchove@128.97.69.2:$VEGASdir/BDT/${dir}/
done

if [ -f $HOME/todayresult ]; then
    mv $HOME/todayresult $HOME/log/
fi

exit 0 # success
