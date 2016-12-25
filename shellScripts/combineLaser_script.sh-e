#!/bin/bash

vegasDir=$VEGAS
processDir=$VEGASWORK/processed/

laser1=$1
laser2=$2
laser3=$3
laser4=$4

laserDate=$5

cd $vegasDir/macros/
cp $processDir/${laser1}_laser.root $processDir/${laserDate}_laserCombined.root

root -b -l -q 'combineLaser.C("$processDir/${laserDate}_laserCombined.root","$processDir/${laser1}_laser.root","$processDir/${laser2}_laser.root","$processDir/${laser3}_laser.root","$processDir/${laser4}_laser.root")'



exit 0 # success
