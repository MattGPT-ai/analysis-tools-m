#!/bin/bash

#VERITASBASE=/software
#VEGAS=$VERITASBASE/vegas

rm -rfv $VEGAS
cd /software/ 
git clone https://github.com/VERITAS-Observatory/VEGAS.git vegas
cd $VEGAS 
git checkout beta/v2_5_5-rc 
ln -s -v /software/boost_1_61_0/boost /software 
git status | tee git_hash.txt 
git describe --always | tee -a git_hash.txt 

#cat $VEGAS/validation/docker_shifter/bashrc >> $HOME/.bashrc
source $VEGAS/validation/docker_shifter/bashrc 

make && make install 

# recompile macros 
for dir in macros showerReconstruction2/macros resultsExtractor/macros ; do 
    find $VEGAS/$dir -name "*_C.*" -exec rm {} \; 
    cd $VEGAS/$dir && root -l -b -q 
done 

# clean up 
rm -rf $VEGAS/.git*
find $VEGAS -name "*.cpp" -exec rm -v {} \; 

exit 0 
