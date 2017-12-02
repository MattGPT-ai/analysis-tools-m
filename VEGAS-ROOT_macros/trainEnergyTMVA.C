/* macro used for training to find shower energy given (image) parameters 
   */

#include <iostream>
#include "TString.h"
#include "TROOT.h"
//__CLING__
#include "TMVA/Factory.h"
//#include "MethodBase.h"

#include "loadChain.C"
//#include "../tmva/test/TMVAGui.C" // deprecated 

// run the training given a list of ROOT files with training events
// output to ROOT file with specified path 
int trainEnergyTMVA(TString simFileListPath, TString outputFileRoot="output.root")
{

    // load dependent macros 
    gROOT->LoadMacro("loadChain.C");
    
    // options for booking BDT 
    // 5-16-00 to 5-18-00f
    TString bookBDToptions = "!H:!V:NTrees=400:BoostType=AdaBoost:SeparationType=GiniIndex:nCuts=20:PruneMethod=CostComplexity:PruneStrength=4.5";
    // EVDisp parameters: NTrees=200:AdaBoostBeta=1.0:PruneMethod=CostComplexity:MaxDepth=50:SeparationType=GiniIndex:nTrain_Signal=200000:nTest_Signal=200000
    // options used for disp 
    bookBDToptions = "!H:!V:NTrees=2000::BoostType=Grad:Shrinkage=0.1:UseBaggedGrad:GradBaggingFraction=0.5:nCuts=20:MaxDepth=6";
    //TString trainTestOptions = "";
    // possible options 
    // ForestType Random

    TFile* outputFile = TFile::Open(outputFileRoot, "CREATE"); // same as "NEW" - recreate will overwrite existing file 
    //outputFile->SetTitle(outputFileTitle);

    // factory creates all MVA methods, and guides them through the training, testing and evaluation phases
    //TString factoryOpts = "";
    TMVA::Factory* factory = new TMVA::Factory(outputFile->GetTitle(), outputFile, "!V:!Silent:Color:DrawProgressBar:Transformations=I;D;P;G,D:AnalysisType=Classification");

    // Load data
    TMVA::DataLoader *dataloader = new TMVA::DataLoader("dataloader");

    
    // Define the input variables that shall be used for the MVA training
    // note that you may also use variable expressions, such as: "3*var1/var2*abs(var3)"
    // pfSimulatedEvent..
    dataloader->AddVariable("zenith", 'F'); // fPrimaryZenithDeg or fOriginElevationRad
    dataloader->AddVariable("azimuth", 'F'); // fPrimaryAzimuthDeg or fOriginAzimuthRad from Hillas data
    // ParameterisedEvents/ParEventsTree/P/vfTels/pfHillasData//$     /dir/Tree/branch/branch/branch//leaf
    dataloader->AddVariable("P.vfTels.at(0)->fSize", 'F'); // fLength
    dataloader->AddVariable("width", 'F'); // fWidth
    dataloader->AddVariable("size", 'F'); // fSize 
    dataloader->AddVariable("timeGrad", 'F'); // fTimeGradient 
    dataloader->AddVariable("loss", 'F'); // fLoss
    //factory->AddVariable(fDist);
    // "P.vfTels.at(telNum)->fSize"
    
    // variable to find with regression 
    dataloader->AddTarget("energy_GeV"); // fEnergyGeV
    //factory->AddTarget("energy_GeV"); // fEnergyGeV

    
    // construct the combined TTree from all files in input list 
    TString treeName = "SelectedEvents/CombinedEventsTree";
    TChain* combinedChain = new TChain(treeName.Data());
    combinedChain = loadChain(simFileListPath.Data(), treeName.Data());
    TTree* regressionTree = static_cast<TTree*>(combinedChain);
    
    
    // basically telling TMVA to randomly choose half the events for training and half for testing
    TCut mycut = "";
    dataloader->PrepareTrainingAndTestTree( mycut, "nTrain_Regression=5000000:nTest_Regression=2000000:SplitMode=Random:NormMode=NumEvents:!V" );

    // book the method(s)
    factory->BookMethod(dataloader, TMVA::Types::kBDT, "BDT_regression_energy", bookBDToptions);
    //MethodBase* mb = factory->BookMethod( TMVA::Types::kBDT, "BDT_regression_energy", bookBDToptions);
    //factory->BookMethod( TMVA::Types::kBDT, "TMVA_EnergyEstimator_allWobble2", "!H:!V:NTrees=2000::BoostType=Grad:Shrinkage=0.1:UseBaggedGrad:GradBaggingFraction=0.5:nCuts=20:MaxDepth=6" );

    // add the tree to read variables 
    dataloader->AddRegressionTree(regressionTree);


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
    
    // Launch the GUI to evaluate 
    if(!gROOT->IsBatch())
    {
	TMVA::TMVAGui(outputFileRoot);
	//TMVAGui(outFileName);
    }

    return 0;
} // trainEnergy TMVA
