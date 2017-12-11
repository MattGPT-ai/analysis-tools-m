/* macro used for training to find shower energy given (image) parameters 
1;95;0c   */

#include <iostream>
#include "TString.h"
#include "TROOT.h"
//__CLING__
#include "TMVA/Factory.h"
//#include "MethodBase.h"
#include "triggeredSimEvent.h"

#include "loadChain.C"
//#include "../tmva/test/TMVAGui.C" // deprecated 

// run the training given a list of ROOT files with training events
// output to ROOT file with specified path 
int trainEnergyTMVA(TString simFileListPath, TString outputFileRoot="output.root") // option to run diagnostic plots 
{

    // load dependent macros 
    gROOT->LoadMacro("loadChain.C");

    // Default MVA methods to be trained + tested
    std::map <std::string, bool> Use;
    
    // Boosted Decision Trees
    Use["BDT"]             = false;
    Use["BDTG"]            = false;
    
    // options for booking BDT 
    TString bookBDToptions;
    // options used to train disp 
    bookBDToptions = "!H:V:NTrees=100:nEventsMin=5:BoostType=AdaBoostR2:SeparationType=RegressionVariance:nCuts=20:PruneMethod=CostComplexity:PruneStrength=30";
    // -> :minNodeSize=0.2%
    // default options 
    //bookBDToptions = "!H:!V:NTrees=2000::BoostType=Grad:Shrinkage=0.1:UseBaggedBoost:GradBaggingFraction=0.5:nCuts=20:MaxDepth=6";

    // classification options for 5-16-00 to 5-18-00f
    //TString bookBDToptions = "!H:!V:NTrees=400:BoostType=AdaBoost:SeparationType=GiniIndex:nCuts=20:PruneMethod=CostComplexity:PruneStrength=4.5";
    // EVDisp parameters: NTrees=200:AdaBoostBeta=1.0:PruneMethod=CostComplexity:MaxDepth=50:SeparationType=GiniIndex:nTrain_Signal=200000:nTest_Signal=200000
    // options used for disp 

    
    //TString trainTestOptions = "SplitMode=Random:NormMode=NumEvents:!V"; // by default splits events in half for training / testing 
    TString trainTestOptions = "nTrain_Regression=500000:nTest_Regression=500000:SplitMode=Random:NormMode=NumEvents:!V";
    //ForestType=Random

    TFile* outputFile = TFile::Open(outputFileRoot, "RECREATE"); // same as "NEW" - recreate will overwrite existing file 
    //outputFile->SetTitle("trainingOutput");

    // factory creates all MVA methods, and guides them through the training, testing and evaluation phases
    //TString factoryOpts = "";
    TMVA::Factory* factory = new TMVA::Factory(outputFile->GetTitle(), outputFile, "!V:!Silent:Color:DrawProgressBar:Transformations=I;D;P;G,D:AnalysisType=Regression");

    // construct the combined TTree from all files in input list 
    TString treeName = "Training"; // dir/trainingTree 
    TChain* combinedChain = new TChain(treeName.Data());
    combinedChain = loadChain(simFileListPath.Data(), treeName.Data());
    TTree* regressionTree = static_cast<TTree*>(combinedChain);

    // check for branch 
    //TBranch* branch = regressionTree->GetBranch("trigSimEvents");
    
    // Load data
    TMVA::DataLoader *dataloader = new TMVA::DataLoader("dataloader");    
    // add the tree to read variables 
    Double_t regWeight  = 1.0;
    dataloader->AddRegressionTree(regressionTree, regWeight);

    // set individual event weights (the variables defined in the expression need to exist in the original TTree)
    //dataloader->SetWeightExpression( "var1", "Regression" );
    
     // Define the input variables that shall be used for the MVA training
    // note that you may also use variable expressions, such as: "3*var1/var2*abs(var3)"
    //dataloader->AddVariable("triggeredSimEvent.fPrimaryZenithDeg", 'F'); // fPrimaryZenithDeg or fOriginElevationRad
    dataloader->AddVariable("fPrimaryAzimuthDeg", 'F'); // fPrimaryAzimuthDeg or fOriginAzimuthRad from Hillas data
    dataloader->AddVariable("fLength", 'F');
    dataloader->AddVariable("fWidth", 'F'); 
    dataloader->AddVariable("fSize", 'F'); 
    dataloader->AddVariable("fTimeGradient", 'F'); 
    dataloader->AddVariable("fLoss", 'F'); 
    dataloader->AddVariable("fDist");
    //triggeredSimEvent.noise
    
    // ParameterisedEvents/ParEventsTree/P/vfTels/pfHillasData//$     /dir/Tree/branch/branch/branch//leaf
    // "P.vfTels.at(telNum)->fSize"


    cout << "adding target!" <<endl;
    // variable to find with regression 
    dataloader->AddTarget("fEnergyGeV"); 

    // not used in training but appear in final testtree 
    //dataloader->AddSpectator( "spec1 := var1*2",  "Spectator 1", "units", 'F' );
   
    // basically telling TMVA to randomly choose half the events for training and half for testing
    TCut mycut = "";
    //dataloader->PrepareTrainingAndTestTree( mycut, "nTrain_Regression=5000000:nTest_Regression=2000000:SplitMode=Random:NormMode=NumEvents:!V" );
    dataloader->PrepareTrainingAndTestTree( mycut, trainTestOptions );

    // book the method(s)
    factory->BookMethod(dataloader, TMVA::Types::kBDT, "BDT_regression_energy", bookBDToptions);

    
    // Boosted Decision Trees
    if (Use["BDT"])
	factory->BookMethod( dataloader,  TMVA::Types::kBDT, "BDT",
			     "!H:!V:NTrees=100:MinNodeSize=1.0%:BoostType=AdaBoostR2:SeparationType=RegressionVariance:nCuts=20:PruneMethod=CostComplexity:PruneStrength=30" );
    if (Use["BDTG"])
	factory->BookMethod( dataloader,  TMVA::Types::kBDT, "BDTG",
			     "!H:!V:NTrees=2000::BoostType=Grad:Shrinkage=0.1:UseBaggedBoost:BaggedSampleFraction=0.5:nCuts=20:MaxDepth=3:MaxDepth=4" );
    // --------------------------------------------------------------------------------------------------
    

    
    // other methods to book 
    //factory->BookMethod( TMVA::Types::kBDT, "TMVA_EnergyEstimator_allWobble2", "!H:!V:NTrees=2000::BoostType=Grad:Shrinkage=0.1:UseBaggedGrad:GradBaggingFraction=0.5:nCuts=20:MaxDepth=6" );
    //factory->BookMethod( TMVA::Types::kBDT, "BDTG", "!H:!V:NTrees=2000::BoostType=Grad:Shrinkage=0.1:UseBaggedGrad:GradBaggingFraction=0.5:nCuts=20:MaxDepth=3:NNodesMax=15" );

    //factory->BookMethod( TMVA::Types::kKNN, "KNN", "nkNN=20:ScaleFrac=0.8:SigmaFact=1.0:Kernel=Gaus:UseKernel=F:UseWeight=T:!Trim" );
    //factory->BookMethod( TMVA::Types::kPDEFoam, "PDEFoam", "!H:!V:MultiTargetRegression=F:TargetSelection=Mpv:TailCut=0.001:VolFrac=0.0666:nActiveCells=500:nSampl=2000:nBin=5:Compress=T:Kernel=None:Nmin=10:VarTransform=None" );
    //factory->BookMethod( TMVA::Types::kLD, "LD", "!H:!V:VarTransform=None" );
    //factory->BookMethod( TMVA::Types::kSVM, "SVM", "Gamma=0.25:Tol=0.001:VarTransform=Norm" );
    //factory->BookMethod( TMVA::Types::kMLP, "MLP", "!H:!V:VarTransform=Norm:NeuronType=tanh:NCycles=20000:HiddenLayers=N+20:TestRate=6:TrainingMethod=BFGS:Sampling=0.3:SamplingEpoch=0.8:ConvergenceImprove=1e-6:ConvergenceTests=15:!UseRegulator" );
    //MethodBase* mb = factory->BookMethod( TMVA::Types::kBDT, "BDT_regression_energy", bookBDToptions);

    
    ///// RUN THE TRAINING ///// 

    // Train MVAs using the set of training events
    factory->TrainAllMethods();
	
    // ---- Evaluate all MVAs using the set of test events
    factory->TestAllMethods();
	
    // ----- Evaluate and compare performance of all configured MVAs
    factory->EvaluateAllMethods();
	
    std::cout << "==> TMVAClassification is done!" << std::endl;
	
    // Save the output
    outputFile->Close();
    
    std::cout << "==> Wrote root file: " << outputFile->GetName() << std::endl;
    
    delete factory;
    delete dataloader;

    //if(runDiagnostics)
    //macroLoader(regressionEnergyBias.C);
    //regressionEnergyBias(simFileListPath, weightsName)
    
    // Launch the GUI to evaluate 
    if(!gROOT->IsBatch())
    {
	TMVA::TMVAGui(outputFileRoot);
	//TMVAGui(outFileName);
    }
    
    return 0;
} // trainEnergy TMVA
