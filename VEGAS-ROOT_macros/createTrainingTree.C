// writes a root file with a simplified tree structure for training
// given a stage 2 simulation ROOT file (GriSUDet)

#include <TTree.h>
#include <VARootIO.h>
#include "triggeredSimEvent.h"
//#include "VAParameterisedEventData.h"

using namespace std;

// provide either a root file or text file with root file paths
int createTrainingTree(TString infile, TString outfile)
{
    //static
    // initialize variables for filling struct 
    Float_t fEnergyGeV, fPrimaryZenithDeg, fPrimaryAzimuthDeg, fLength, fWidth, fSize, fTimeGradient, fLoss;
    triggeredSimEvent trigSimEvent = triggeredSimEvent(); // for writing 

    // for branch, if type is other than float, need to specify types with varname/F, for example
    const char* leafList = "fEnergyGeV:fLength:fWidth:fSize";
    //:fPrimaryZenithDeg:fPrimaryAzimuthDeg:fTimeGradient:fLoss:fDist
    
    // quality cuts 
    int NTubesMin = 5;
    float distanceUpper = 1.38; // 1.43 [degrees]

    
    // create output file for writing new branch
    TFile hfile(outfile,"RECREATE","simplified ROOT file with single branch structure for training on simulated events");

    // Create a ROOT Tree
    TTree *trainTree = new TTree("Training","ROOT tree with single training branch");
    //trainTree->Branch("triggeredSimEvent", &trigSimEvent, leafList);
    trainTree->Branch("fEnergyGeV", &fEnergyGeV, "fEnergyGeV");
    trainTree->Branch("fLength", &fLength, "fLength");
    trainTree->Branch("fWidth", &fWidth, "fWidth");
    trainTree->Branch("fSize", &fSize, "fSize");
    // should make 4 branches for each telescope 
    
    
    
    //// set up input to connect simulated events to shower events /////
    
    // open input file for reading only
    VARootIO* pfRootIO = new VARootIO(string(infile.Data()), true); 

    pfRootIO->loadTheRootFile();
    if(!pfRootIO->IsOpen())
        {
            cerr << "Couldn't open " << infile << endl;
	    return 1;
        }


    VAParameterisedEventData* paramData = nullptr;
    //TTree* paramEventsTree = (TTree*)pfRootIO->loadAnObject("CombinedEventsTree", "SelectedEvents", true);
    //TTree* paramEventsTree = (TTree*)tfile->Get("SelectedEvents/CombinedEventsTree");
    TTree* paramEventsTree = pfRootIO->loadTheParameterisedEventTree();
    paramEventsTree->SetBranchAddress("P", &paramData);
    //vector<VAParameterisedEventTelData*> vfTels
    //VAHillasData*           pfHillasData;


    TTree* simTree = pfRootIO->loadTheSimulationEventTree();    
    VASimulationData* simData = nullptr;
    simTree->SetBranchAddress("Sim", &simData);
    //TTree* simTree = static_cast<TTree*>pfRootIO->loadAnObject("CombinedEventsTree", "
    //simTree->SetBranchAddress(gSimulatedEventsBranchName.c_str(), &simData); 
    //TTree* combinedEventsTree = paramEventsTree;
    TTree* showerTree = pfRootIO->loadTheShowerEventTree();
    VAShowerData* showerData = nullptr;

        if(showerTree)
        {
            if(!showerTree->GetBranch(gShowerEventsBranchName.c_str()))
            {
                cerr << "Couldn't find a branch called " << gShowerEventsBranchName << endl;
                return false;
            }
            showerTree->SetBranchAddress(gShowerEventsBranchName.c_str(),
                                                &showerData);

	    cout << " got shower branch" << endl;
        } // if(pfShowerEventTree)
        else
        {
            cerr << "Couldn't load the shower event data from " <<endl;
            return false;
        
        }

	//showerTree->SetBranchAddress("S", &showerData);

    
    if(!paramEventsTree)
      {
	  cerr << "Couldn't get a pointer to the shower tree" << endl;
	  return 1;
      }
    if(!simTree)
      {
	  cerr << "Couldn't get a pointer to the simulation tree" << endl;
	  return 1;
      }
    if(!simTree->GetBranch(gSimulatedEventsBranchName.c_str()))
	{
	    cerr << "Couldn't find a branch called " << gSimulatedEventsBranchName << endl;
	    return false;
	}

    
    cout << "simulated events: " << simTree->GetEntries() << endl;
    cout << "parameterised events: " << paramEventsTree->GetEntries() << endl;

    cout << "Building simulation index" << endl;
    paramEventsTree->BuildIndex("fRunNum", "fArrayEventNum");    
    //paramEventsTree->BuildIndex("P.fRunNum", "P.fArrayEventNum");
    //simTree->BuildIndex("fRunNum", "fArrayEventNum");
    cout << "done" << endl;
    

    // now loop over all entries 
    unsigned long long int simEntries = simTree->GetEntries();    
    for(unsigned long long int i = 0; i < simEntries; i++)
      {
	  if(simTree->GetEntry(i) <= 0)
	    {
		cerr << "could not get entry " << i <<endl;
		return 1;
	    }

	  if(i%1000000 == 0)
	  {
	      cout << "event\t" << i <<endl;
	  }
	  
	  // check simData is not null and generated an array event 
	  if(simData && simData->fTriggeredArray) 
	    {
		// 
		Long64_t stereoEntryNumber = paramEventsTree->
		    GetEntryWithIndex(simData->fRunNum, simData->fArrayEventNum);

		// ensure shower event is valid 
		if(stereoEntryNumber >= 0 && paramData) 
		  {

		      //VAParameterisedEventTelData* = paramData->
		      VAHillasData* hillasData = paramData->vfTels.at(0)->pfHillasData;

		      // check quality (cuts) 
		      if(hillasData->fGoodImage
			 && hillasData->fPixelsInImage >= NTubesMin
			 && hillasData->fDist <= distanceUpper){ // && NTubes >= NTubesMin, DistanceUpper
		      // should i check if event was reconstructed? doubt it 
		      // now set the appropriate values in the struct before filling tree
		      fLength = hillasData->fLength;
		      fWidth = hillasData->fWidth;
		      fSize = hillasData->fSize;
		      //fTimeGradient = hillasData->fTimeGradient;
		      //fLoss = hillasData->fLoss;
		      //fDist = hillasData->fDist;
		      
		      // energy needs to come from simulated event
		      fEnergyGeV = simData->fEnergyGeV;
		      //fPrimaryZenithDeg = simData->fPrimaryZenithDeg;
		      //fPrimaryAzimuthDeg = simData->fPrimaryAzimuthDeg;
		      } // if telescope image is good 

		      // write the event to the tree in new branch 
		      trainTree->Fill();
		      
		      /*
			uint32_t    fRunNum; //The number of the run - important when many runs get
			//combined since the fEventIndex and fArrayEventNum
			//will no longer be unique
			uint32_t    fArrayEventNum;//Event number - unique for single run only.

			double      fOriginRA;     //Ra and Dec of center of camera at event time.
			double      fOriginDec;    //In radians
			double      fOriginElevationRad; //Elevation of the camera center at event time
			double      fOriginAzimuthRad; //Azimuth of the camera center at event time
			uint16_t    fTelId;         //Telescope ID (node # T1=0)this telescope event
			
			double      fXO;       //X in cameraplane(deg) of assumed source position
			double      fYO;       //Y in cameraplane(deg) of assumed source position
			// Used to recenter camera plane to
			// Field-of-view(FOV) where XO,YO is now 0,0 in fov
			double      fXC;           //X in FOV(deg) of centroid location
			double      fYC;           //Y in FOV(deg) of centroid location

			double      fCosPsi;        //Direction cosigns of major axis
			double      fSinPsi;
			double      fAsymmetry;     //Asymmetry along major axis
			double      fMinorAsymmetry;//Asymmetry along minor axis
			VAEventType fTriggerCode;
			bool        fGoodImage;    //Flag that this image can be analyized(size>0)
			bool        fIsL2Triggered;//Flag that this telescope had an L2 trigger

		      */

		  } // successfully got param data entry corresponding to triggered sim event 
	    } // successfully got sim data that triggered array 
      }	// for loop over entries in simulation tree 

    // write all (branches) to this file 
    hfile.Write();
    cout << "tree written to file!" <<endl;
    
    hfile.Close();
    //pfRootIO->Close();
    //delete VASimulationData();

    return 0; // great job!
} // createTrainingTree
