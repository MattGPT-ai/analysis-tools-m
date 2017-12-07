// reads a root file created by createTrainingTree.C and tests the energy reconstruction using the regression from the supplied MVA weights file 

#include "triggeredSimEvent.h"

// can pass a single file with a .root extension or a list of paths to .root files
int regressionEnergyBias(TString rootFile = "outfile.root", TString weightsFile = "dataloader.weights.xml")
{
    // first book the TMVA reader to evaluate energy 
    
    // variables to store values for reader 
    Float_t fEnergyGeV, fSize, fLength, fWidth;
    
    TMVA::Reader *energyReader = new TMVA::Reader( "!Color:!Silent" );

    energyReader->AddVariable("triggeredSimEvent.fLength", &fLength);
    energyReader->AddVariable("triggeredSimEvent.fWidth", &fWidth);
    energyReader->AddVariable("triggeredSimEvent.fSize", &fSize);
    //energyReader->AddVariable("fEnergyGeV", &fEnergyGeV); // probably don't add 'target'

    TString methodTag = "BDT_regression_energy";
    energyReader->BookMVA(methodTag, weightsFile); 
    // methodTag should match that used to book. method type found in weights file 
    //energyReader->BookMVA(TMVA::Types::kBDT, weightsFile); // enum TMVA::Types::EMVA 



    // open ROOT file to read events
    // construct the combined TTree from all files in input list
    TString treeName = "Training"; // dir/trainingTree
    /*TChain* combinedChain = new TChain(treeName.Data());
    combinedChain = loadChain(rootFile.Data(), treeName.Data());
    TTree* regressionTree = static_cast<TTree*>(combinedChain);*/

    // use TTreeReader to read individual values (without using struct)
    auto f = TFile::Open(rootFile);
    TTreeReader myReader(treeName, f);

    // add leafs as (branch|struct)/leaf
    TTreeReaderValue<triggeredSimEvent> eventRV(myReader, "triggeredSimEvent");
    //TTreeReaderValue<Float_t> energyRV(myReader, "triggeredSimEvent.fEnergyGev");
    //TTreeReaderValue<Float_t> sizeRV(myReader, "triggeredSimEvent.fSize");
    //TTreeReaderValue<Float_t> lengthRV(myReader, "triggeredSimEvent.fLength");
    //TTreeReaderValue<Float_t> widthRV(myReader, "ftriggeredSimEvent.Width");

    
    // set up histograms
    float simEnergy_min = 100.0; // GeV
    float simEnergy_max = 100000.0;
    int numBins = 30;
    
    unique_ptr<TProfile> bias ( new TProfile("bias", "Energy Bias curve", numBins, log10(simEnergy_min), log10(simEnergy_max)) );
    bias->GetXaxis()->SetTitle("log(E[GeV]) sims");
    bias->GetYaxis()->SetTitle("energy bias");

    
    
    // loop over entries in tree 
    while(myReader.Next())
    {
	// retrieve leaf values using reader 
	auto trigSimEvent = (*eventRV);
	//auto trueEnergyGeV = (*energyRV); // from sim 
	//auto size = (*sizeRV);
	//auto length = (*lengthRV);
	//auto width = (*widthRV);

	// set variables at branch addresses for reader to read during regression 
	
	Float_t trueEnergyGeV = trigSimEvent.fEnergyGeV;
	fSize = trigSimEvent.fSize;
	fLength = trigSimEvent.fLength;
	fWidth = trigSimEvent.fWidth;

	// predict energy using MVA training weights file 
	const std::vector<Float_t>& vec_predictions = energyReader->EvaluateRegression(methodTag);
	cout << "length of EvaluateRegression vector = " << vec_predictions.size() <<endl;
	fEnergyGeV = vec_predictions[0]; // only value is the predicted (regressed?) energy 

	// fill bias histograms with delta E / E 
	Float_t energyBias = fEnergyGeV - trueEnergyGeV;
	cout << "energy bias: " << energyBias <<endl;
	Float_t weight = 1.0; // can weight by error if found 
	bias->Fill(log10(trueEnergyGeV), energyBias/trueEnergyGeV, weight);
	
    } // while reader finds values 

    // display / save results 
    TFile* fOut = new TFile("biasPlots.root", "RECREATE"); // will create the file or overwrite it 
    bias->Write();
    fOut->Close();
    
    delete energyReader;
    
    return 0; // great job 
} // int regressionEnergyBias
