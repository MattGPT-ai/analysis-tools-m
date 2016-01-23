#!/bin/bash
#sh
set -e # to exit when error is received 

copyBoost=false
VEGASdir=VEGAS-work
tarDir=/veritas/userspace3/mbuchove/tarballs
ROOTver=v5-34
#VERITASBASE=


if test ! -d $VERITASBASE/src/; then
    mkdir $VERITASBASE/src/
fi

if $copyBoost; then
    cd $VERITASBASE/src/
    tar -xzvf $tarDir/boost_1_55_0.tar.gz
    cp -R boost_155_0/boost /usr/local/include
fi

cd $VERITASBASE/src/
git clone git@github.com:VERITAS-Observatory/VEGAS.git $VEGASdir
cd $VEGASdir
git pull
#git checkout mbuchove_workEdit_2_5_4

cd $VERITASBASE/ #src/
git clone http://root.cern.ch/git/root.git ROOT_$ROOTver
cd ROOT_$ROOTver
git checkout -b $ROOTver $ROOTver
./configure --enable-minuit2 --enable-mysql --enable-fitsio # --enable-roofit
#./configure --enable-minuit2 linuxx8664gcc --prefix=$VERITASBASE
#cd build
#cmake ..
#cmake --build . 
#cmake -DCMAKE_INSTALL_PREFIX=$VERITASBASE/ROOT_$ROOTver
##cmake --build . --target install 
make || exit 1 #-j 4
source ./bin/thisroot.sh
#make install

cd $VERITASBASE/src/
tar -zxf $tarDir/VBF-0.3.3.tar.gz 
cd VBF-0.3.3
./configure --prefix=$VERITASBASE
make
make install

export LD_LIBRARY_PATH=$VERITASBASE/lib:${LD_LIBRARY_PATH}
export PKG_CONFIG_PATH=$VERITASBASE/lib/pkgconfig:${PKG_CONFIG_PATH}

cd $VERITASBASE/src/
tar -zxf $tarDir/VDB-4.3.2.tar.gz 
cd VDB-4.3.2
./configure --prefix=$VERITASBASE
make
make install

export VEGAS=$VERITASBASE/src/vegas-head/

cd $VEGAS
make
make install
