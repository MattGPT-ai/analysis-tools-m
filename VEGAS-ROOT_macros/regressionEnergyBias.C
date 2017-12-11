// reads a root file created by createTrainingTree.C and tests the energy reconstruction using the regression from the supplied MVA weights file 

#include "triggeredSimEvent.h"
#include "loadChain.C"

// can pass a single file with a .root extension or a list of paths to .root files
int regressionEnergyBias(TString rootFile = "outfile.root", TString weightsFile = "dataloader.weights.xml")
{
    // first book the TMVA reader to evaluate energy 
    
    // variables to store values for reader 
    Float_t fEnergyGeV, fSize, fLength, fWidth, fLoss, fTimeGradient, fDist, fPrimaryAzimuthDeg;
    Float_t regressionEnergyGeV;
    
    TMVA::Reader *energyReader = new TMVA::Reader( "!Color:!Silent" );
    energyReader->AddVariable("fPrimaryAzimuthDeg", &fDist);
    energyReader->AddVariable("fLength", &fLength);
    energyReader->AddVariable("fWidth", &fWidth);
    energyReader->AddVariable("fSize", &fSize);
    energyReader->AddVariable("fTimeGradient", &fTimeGradient);
    energyReader->AddVariable("fLoss", &fLoss);
    energyReader->AddVariable("fDist", &fDist);

    TString methodTag = "BDT_regression_energy";
    energyReader->BookMVA(methodTag, weightsFile); 
    TString tagBDTG = "BDT_grad";
    //energyReader->BookMVA(tagBDTG, weightsFile);
    // methodTag should match that used to book. method type TMVA::Types::EMVA found in weights file 


    // open ROOT file to read events
    // construct the combined TTree from all files in input list
    TString treeName = "Training"; // dir/trainingTree
    TChain* combinedChain = new TChain(treeName.Data());
    combinedChain = loadChain(rootFile.Data(), treeName.Data());
    TTree* regressionTree = static_cast<TTree*>(combinedChain);

    regressionTree->SetBranchAddress("fEnergyGeV", &fEnergyGeV); // true energy 
    regressionTree->SetBranchAddress("fLength", &fLength);
    regressionTree->SetBranchAddress("fWidth", &fWidth);
    regressionTree->SetBranchAddress("fSize", &fSize);
    regressionTree->SetBranchAddress("fLoss", &fLoss);
    regressionTree->SetBranchAddress("fTimeGradient", &fTimeGradient);
    regressionTree->SetBranchAddress("fDist", &fDist);
    regressionTree->SetBranchAddress("fPrimaryAzimuthDeg", &fPrimaryAzimuthDeg);
    
    /*
    // use TTreeReader to read individual values (without using struct)
    auto f = TFile::Open(rootFile);
    TTreeReader myReader(treeName, f);

    // add leafs as (branch|struct)/leaf
    //TTreeReaderValue<triggeredSimEvent> eventRV(myReader, "triggeredSimEvent");
    TTreeReaderValue<Float_t> energyRV(myReader, "fEnergyGev");
    TTreeReaderValue<Float_t> sizeRV(myReader, "fSize");
    TTreeReaderValue<Float_t> lengthRV(myReader, "fLength");
    TTreeReaderValue<Float_t> widthRV(myReader, "fWidth");
    */
    
    // set up histograms
    float simEnergy_min = 100.0; // GeV
    float simEnergy_max = 100000.0; // GeV 
    int numBins = 30;

    // create bias profile with error bars as standard deviation (no division by sqrt(n))
    unique_ptr<TProfile> bias ( new TProfile("bias", "Energy Bias curve", numBins, log10(simEnergy_min), log10(simEnergy_max), "s") );
    bias->GetXaxis()->SetTitle("log(E[GeV]) sims");
    bias->GetYaxis()->SetTitle("energy bias");

    
    // loop over entries in tree 
    for(int i=0; i<regressionTree->GetEntries(); i++)
    //while(myReader.Next())
    {
	regressionTree->GetEntry(i);

	/*
	// retrieve leaf values using reader 
	myReader.Next();
	//auto trigSimEvent = (*eventRV);
	auto trueEnergyGeV = (*energyRV); // from sim 
	auto size = (*sizeRV);
	auto length = (*lengthRV);
	auto width = (*widthRV);

	// set variables at branch addresses for reader to read during regression 
	fSize = size;
	fLength = length;
	fWidth = width;
	*/

	// predict energy using MVA training weights file 
	const std::vector<Float_t>& vec_predictions = energyReader->EvaluateRegression(methodTag);
	regressionEnergyGeV = vec_predictions[0]; // only value is the predicted (regressed?) energy 
	//Float_t gradEnergyGeV = energyReader->EvaluateRegression(tagBDTG).at(0);
	
	// fill bias histograms with delta E / E 
	Float_t energyBias = regressionEnergyGeV - fEnergyGeV;
	Float_t weight = 1.0; // can weight by error if found 
	bias->Fill(log10(fEnergyGeV), energyBias/fEnergyGeV, weight);

	if(i%100000==0)
	    cout << fSize <<"\t"<< regressionEnergyGeV <<"\t"<< fEnergyGeV <<endl;
	
    } // while reader finds values 

    // for each point in bias curve, the energy resolution is the standard deviation
    for(unsigned int i=0; i<numBins; i++)
    {
	// find standard deviation by multiplying error on bin by sqrt(numEvents) in the bin
	Float_t resolution = bias->GetBinError(i+1) * sqrt(bias->GetBinEffectiveEntries(i+1));
	cout << i <<"\t"<< bias->GetBinCenter(i+1) <<"\t"<< bias->GetBinError(i+1) <<endl;
    } // loop over points in bias profile 

    
    // display / save results 
    TString outfile = "biasPlots.root";
    TFile* fOut = new TFile(outfile, "RECREATE"); // will create the file or overwrite it 
    bias->Write();
    fOut->Close();
    cout << "Diagnostic plots written to " << outfile <<endl;
    
    delete energyReader;
    
    return 0; // great job 
} // int regressionEnergyBias
