#!/bin/sh

copyBoost=false
runCVS=true
if [ `whoami` = "root" ]; then
    runCVS=false
fi

#VERITASBASE=
#installDir=/veritas/userspace3/mbuchove/veritas/
#tarDir=/veritas/userspace3/mbuchove/tarballs/


if test ! -d $VERITASBASE/src/; then
    mkdir $VERITASBASE/src/
fi

if $copyBoost; then
    cd $VERITASBASE/src/
    tar -xzvf /veritas/userspace3/mbuchove/tarballs/boost_1_55_0.tar.gz
    cp -R boost_155_0/boost /usr/local/include
fi

if $runCVS; then
#    cvs login
    cd $VERITASBASE/src/
    cvs checkout -d vegas-head -A vegas
    cd vegas-head
    cvs update -A -d
    #cvs checkout -r v2_5_3 -d vegas-v2_5_3 vegas
    #cd vegas-v2_5_3
    #cvs update -d
fi

cd $VERITASBASE/src/
#git clone http://root.cern.ch/git/root.git root-v5-32
#cd root-v5-32
#git checkout -b v5-32-01 v5-32-01
gzip -dc /veritas/userspace3/mbuchove/tarballs/root_v5.34.21.source.tar.gz | tar -xf -
mv root root-v5.34.21
cd root-v5.34.21
./configure --enable-minuit2 --enable-mysql 
#./configure --enable-minuit2 linuxx8664gcc --prefix=$VERITASBASE
make #-j 4
source ./bin/thisroot.sh
#make install
#source bin/thisroot.sh

cd $VERITASBASE/src/
tar -zxf /veritas/userspace3/mbuchove/tarballs/VBF-0.3.3.tar.gz 
cd VBF-0.3.3
./configure --prefix=$VERITASBASE/
make
make install

export LD_LIBRARY_PATH=$VERITASBASE/lib:${LD_LIBRARY_PATH}
export PKG_CONFIG_PATH=$VERITASBASE/lib/pkgconfig:${PKG_CONFIG_PATH}

cd $VERITASBASE/src/
tar -zxf /veritas/userspace3/mbuchove/tarballs/VDB-4.3.2.tar.gz 
cd VDB-4.3.2
./configure --prefix=$VERITASBASE/
make
make install


export VEGAS=$VERITASBASE/src/vegas-head/
#export VEGAS=$VERITASBASE/src/vegas-v2_5_3/

cd $VEGAS
make
make install
