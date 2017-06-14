arrays="na ua"

for array in $arrays; do 

fileList=$GC/runlists/SgrA_off_acceptance_${array}_4tel_disp5t_soft_stg5list.txt
rootBase=SgrA_acceptance_off_${array}_4tel_disp5t_soft
logFile=$GC/log/acceptance/${rootBase}.txt

cmd="makeAcceptancePlot -UserDefinedExclusionList=/home/mbuchove/config/SgrA_exclusionList.txt -BackgroundFileList=${fileList} -AcceptancePlotFile=/veritas/userspace2/mbuchove/SgrA/processed/acceptanceMaps/${rootBase}.root  -AcceptanceFitMethod=SMOOTH " # -BackgroundCameraAcceptanceModel=Radial2Zenith 

$cmd | tee $logFile 
echo $cmd | tee $logFile 

plotdir=$GC/plots/acceptance 
mv -v ${rootBase}Plot.gif $plotdir/${rootBase}_MAP_rad2acchist.gif
mv -v ${rootBase}ResidualBackground.gif $plotdir/${rootBase}_MAP_ResidualBackground.gif 

done 

#makeAcceptancePlot -StarExclusionBMagLimit=5.5 -BackgroundFileList=/veritas/userspace3/mbuchove/Crab/runlists/Crab_V5_acceptanceTest_z0-15_soft_stg5list.txt -BackgroundModelMaker=MLMModelMakerBasic -BackgroundModelNumberRadialBins=50 -BackgroundCameraAcceptanceModel=RadialZenith -AcceptancePlotFile=/veritas/userspace3/mbuchove/Crab/processed/acceptance/Crab_acceptance_z0-15_soft.root

#buildAcceptanceCurveLibrary(const string& curveFileList, const string& outfile, Int_t fitIndex = 0)

#plotAcceptanceCurveLibrary(string library)
