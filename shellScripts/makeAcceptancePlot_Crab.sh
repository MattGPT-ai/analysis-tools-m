arrays="V4 V5 V6"
test -n "$1" && arrays="$1" 

for array in $arrays; do 

fileList=$CRAB/runlists/Crab_acceptanceTest_${array}_z60-70_soft_stg5list.txt
rootBase=Crab_z60-70_${array}_soft #_rad2zen
logFile=$GC/log/acceptanceMaps/${rootBase}.txt

cmd="makeAcceptancePlot  -BackgroundFileList=${fileList} -AcceptancePlotFile=$CRAB/processed/acceptance/${rootBase}.root " #-BackgroundCameraAcceptanceModel=Radial2Zenith -AcceptanceFitMethod=SMOOTH " # -UserDefinedExclusionList=/home/mbuchove/config/SgrA_exclusionList.txt

$cmd #| tee $logFile 
echo $cmd #| tee $logFile 

plotdir=$CRAB/plots/acceptance 
mv -v ${rootBase}Plot.gif $plotdir/${rootBase}_MAP_rad2acchist.gif
mv -v ${rootBase}ResidualBackground.gif $plotdir/${rootBase}_MAP_ResidualBackground.gif 

done # loop over arrays 

#makeAcceptancePlot -StarExclusionBMagLimit=5.5 -BackgroundFileList=/veritas/userspace3/mbuchove/Crab/runlists/Crab_V5_acceptanceTest_z0-15_soft_stg5list.txt -BackgroundModelMaker=MLMModelMakerBasic -BackgroundModelNumberRadialBins=50 -BackgroundCameraAcceptanceModel=RadialZenith -AcceptancePlotFile=/veritas/userspace3/mbuchove/Crab/processed/acceptance/Crab_acceptance_z0-15_soft.root

#buildAcceptanceCurveLibrary(const string& curveFileList, const string& outfile, Int_t fitIndex = 0)

#plotAcceptanceCurveLibrary(string library)
