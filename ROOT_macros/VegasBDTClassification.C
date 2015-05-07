// $Id: VegasTMVAClassification.C
/**********************************************************************************
 * Based on TMVA's TMVAClassification.C macro,
 * this macro provides examples for the training and testing of the
 * TMVA classifiers in VEGAS.
 *
 * Input data are directories containing CORSIKA MC signal files and background   *
 * data files                                                                     *
 *                                                                                *
 * The methods to be used can be switched on and off by means of booleans, or     *
 * via the prompt command, for example:                                           *
 *                                                                                *
 *    root -l TMVAClassification.C\(\"Fisher,Likelihood\"\)                       *
 *                                                                                *
 * (note that the backslashes are mandatory)                                      *
 * If no method given, a default set is used.                                     *
 *                                                                                *
 * The output file "TMVA.root" can be analysed with the use of dedicated          *
 * macros (simply say: root -l <macro.C>), which can be conveniently              *
 * invoked through a GUI that will appear at the end of the run of this macro.    *
 **********************************************************************************/

//See end of file for old methods, variables, etc

//THIS CODE IS USED FOR ANALYSIS OF STAGE 5 FILES

#include <cstdlib>
#include <iostream>
#include <map>
#include <string>
#include "stdio.h"
#include "TChain.h"
#include "TFile.h"
#include "TTree.h"
#include "TString.h"
#include "TObjString.h"
#include "TSystem.h"
#include "TROOT.h"
#include "TPluginManager.h"
#include "TMath.h"

#include "../tmva/test/TMVAGui.C"

#if not defined(__CINT__) || defined(__MAKECINT__)
// needs to be included when makecint runs (ACLIC)
#include "TMVA/Factory.h"
#include "TMVA/Tools.h"
#endif


void VegasTMVAClassification(TString bgDirName, TString mcDirName, char* ELower, char* EUpper, char* Zenith, TString myMethodList = "")
{
  //////////// SET DEFAULT OPTIONS !!! //////////////////////////////////

  TString bookBDToptions;
  
  // 5-16-00 to 5-18-00f
  bookBDToptions = "!H:!V:NTrees=400:BoostType=AdaBoost:SeparationType=GiniIndex:nCuts=20:PruneMethod=CostComplexity:PruneStrength=4.5";
  
  TString prepOptions;
  //prepOptions = "nTrain_Signal=0:nTrain_Background=0:SplitMode=Random:NormMode=NumEvents:!V";
  
  // To also specify the number of testing events, use:
  prepOptions = "nTrain_Signal=100000:nTrain_Background=100000:nTest_Signal=100000:nTest_Background=100000:SplitMode=Random:NormMode=NumEvents:!V";
  
  
  // read input data file with ascii format (otherwise ROOT) ?
  Bool_t ReadDataFromAsciiIFormat = kFALSE;


  // The explicit loading of the shared libTMVA is done in TMVAlogon.C, defined in .rootrc
  // if you use your private .rootrc, or run from a different directory, please copy the
  // corresponding lines from .rootrc
  
  // methods to be processed can be given as an argument; use format:
  //
  // mylinux~> root -l TMVAClassification.C\(\"myMethod1,myMethod2,myMethod3\"\)
  //
  // if you like to use a method via the plugin mechanism, we recommend using
  //
  // mylinux~> root -l TMVAClassification.C\(\"P_myMethod\"\)
  // (an example is given for using the BDT as plugin (see below),
  // but of course the real application is when you write your own
  // method based)
  
  // this loads the library
  TMVA::Tools::Instance();
  
  //---------------------------------------------------------------
  // default MVA methods to be trained + tested
  std::map<std::string, int> Use;
  

  Use["BDT"]             = 1;
  Use["BDTD"]            = 0;
  Use["BDTG"]            = 0;
  Use["BDTB"]            = 0;
  // ---
  Use["RuleFit"]         = 0;
  // ---
  Use["Plugin"]          = 0;
  // ---------------------------------------------------------------
	
  std::cout << std::endl;
  std::cout << "==> Start TMVAClassification" << std::endl;
	
  if(myMethodList != "")
    {
      for(std::map<std::string, int>::iterator it = Use.begin(); it != Use.end(); it++)
	{
	  it->second = 0;
	}
		
      std::vector<TString> mlist = TMVA::gTools().SplitString(myMethodList, ',');
      for(UInt_t i = 0; i < mlist.size(); i++)
	{
	  std::string regMethod(mlist[i]);
			
	  if(Use.find(regMethod) == Use.end())
	    {
	      std::cout << "Method \"" << regMethod << "\" not known in TMVA under this name. Choose among the following:" << std::endl;
	      for(std::map<std::string, int>::iterator it = Use.begin(); it != Use.end(); it++)
		{
		  std::cout << it->first << " ";
		}
	      std::cout << std::endl;
	      return;
	    }
	  Use[regMethod] = 1;
	}
    }
	
	
  TString outFileName = "TestBDT_ELow";
  outFileName += ELower;
  outFileName += "_EHigh" ;
  outFileName += EUpper;
  outFileName += "_Zenith" ;
  outFileName += Zenith;
  outFileName += ".root";
	
  // Create a new root output file.
  //TString outfileName( "BDT.root" );
  TFile* outputFile = TFile::Open(outFileName, "RECREATE");
	
  // Create the factory object. Later you can choose the methods
  // whose performance you'd like to investigate. The factory will
  // then run the performance analysis for you.
  //
  // The first argument is the base of the name of all the
  // weightfiles in the directory weight/
  //
  // The second argument is the output file for the training results
  // All TMVA output can be suppressed by removing the "!" (not) in
  // front of the "Silent" argument in the option string
  TMVA::Factory* factory = new TMVA::Factory("TMVAClassification", outputFile,
					     "!V:!Silent:Color:DrawProgressBar:Transformations=I;D;P;G,D:AnalysisType=Classification");
			
  // If you wish to modify default settings
  // (please check "src/Config.h" to see all available global options)
  //    (TMVA::gConfig().GetVariablePlotting()).fTimesRMS = 8.0;
  //    (TMVA::gConfig().GetIONames()).fWeightFileDir = "myWeightDirectory";
	
  // Define the input variables that shall be used for the MVA training
  // note that you may also use variable expressions, such as: "3*var1/var2*abs(var3)"
  // [all types of expressions that can also be parsed by TTree::Draw( "expression" )]
	
	
  factory->AddVariable("TMath::Log10(S.fMSL)", 'F');
  factory->AddVariable("TMath::Log10(S.fMSW)", 'F');
  factory->AddVariable("TMath::Log10(S.fShowerMaxHeight_KM)", 'F');
  factory->AddVariable("TMath::Log10(S.fMSL_RMS)", 'F');
  factory->AddVariable("TMath::Log10(S.fMSW_RMS)", 'F');
  factory->AddVariable("(S.fEnergyRMS_GeV)/S.fEnergy_GeV", 'F');
	
  // read training and test data
  if(ReadDataFromAsciiIFormat)
    {
      // load the signal and background event samples from ascii files
      // format in file must be:
      // var1/F:var2/F:var3/F:var4/F
      // 0.04551   0.59923   0.32400   -0.19170
      // ...
		
      TString datFileS = "tmva_example_sig.dat";
      TString datFileB = "tmva_example_bkg.dat";
		
      factory->SetInputTrees(datFileS, datFileB);
    }
  else
    {
      // load the signal and background event samples from ROOT trees
      
      void* bgDir = gSystem->OpenDirectory(gSystem->ExpandPathName(string(bgDirName).c_str()));
      if(!bgDir)
	{
	  cerr << "Could not open directory with background data files: " << bgDirName << endl;
	}
      
      void* sigDir = gSystem->OpenDirectory(gSystem->ExpandPathName(string(sigDirName).c_str()));
      if(!sigDir)
	{
	  cerr << "Could not open directory with background data files: " << sigDirName << endl;  
	}
      if(!bgDir || !sigDir)
	exit(1);
      
      TChain* bgChDataCombined = new TChain("SelectedEvents/CombinedEventsTree");
      TChain* sigChDataCombined = new TChain("SelectedEvents/CombinedEventsTree");
		
      const char* strPtr;
      while((strPtr = gSystem->GetDirEntry(bgDir)))
	{	
	  string file = strPtr;
	  size_t found;
	  found = file.find("root");
	  if(found == string::npos)
	    {
	      continue;
	    }
	  stringstream fnamestream;
	  fnamestream << bgDirName << "/" << file.c_str();
	  bgChDataCombined->Add(fnamestream.str().c_str());		
	} // loop over background files in directory 
      while((strPtr = gSystem->GetDirEntry(sigDir)))
	{	
	  string file = strPtr;
	  size_t found;
	  found = file.find("root");
	  if(found == string::npos)
	    {
	      continue;
	    }
	  stringstream fnamestream;
	  fnamestream << sigDirName << "/" << file.c_str();
	  sigChDataCombined->Add(fnamestream.str().c_str());		
	} // loop over signal files in directory 
			

      if(!bgChDataCombined || !sigChDataCombined)
	{
	  cerr << "Couldn't get the CombinedEventsTree" << endl;
	  return; // exit?
	}

      TTree* background = (TTree*)bgChDataCombined;
      TTree* signal = (TTree*)sigChDataCombined;

      // global event weights per tree (see below for setting event-wise weights)
      Double_t signalWeight     = 1.0;
      Double_t backgroundWeight = 1.0;
		
      // ====== register trees ====================================================
      //
      // the following method is the prefered one:
      // you can add an arbitrary number of signal or background trees
      factory->AddSignalTree(signal, signalWeight);
      factory->AddBackgroundTree(background, backgroundWeight);

    } // ========== end of register trees =============
	
  // This would set individual event weights (the variables defined in the
  // expression need to exist in the original TTree)
  //    for signal    :
  //factory->SetSignalWeightExpression("pow(S.fEnergy_GeV,-2.4)/pow(S.fEnergy_GeV,-2)");
  factory->SetSignalWeightExpression("1");
  //    for background: factory->SetBackgroundWeightExpression("weight1*weight2");
	
  //factory->SetBackgroundWeightExpression("weight");
	
  // Apply additional cuts on the signal and background samples (can be different)

  // set the Elevation cuts based off of current zenith binning 
  char* ElLower = "0"; // 0 degrees
  char* ElUpper = "1.57079634"; // 90 degrees 

  if ( strcmp(Zenith,"10")==0 )
    {
      ElLower = "1.30899694"; // 75 degrees
    }
  else if ( strcmp(Zenith,"20")==0 )
    {
      ElLower = "1.13446401"; // 65 degrees
      ElUpper = "1.30899694"; // 75 degrees
    }
  else if ( strcmp(Zenith,"30")==0 )
    {
      ElLower = "0.959931089"; // 55 degrees
      ElUpper = "1.13446401"; // 65 degrees
    }
  else if ( strcmp(Zenith,"40")==0 )
    {
      ElLower = "0.785398163"; // 45 degrees
      ElUpper = "0.959931089"; // 55 degrees  
    }

  string cut_string[2];
  //const char* cut_char;
  TCut myCutSig, myCutBg;
  for (UInt_t i=0; i<2; i++)
    {
      cut_string[i] = "S.fIsReconstructed==1 && S.fEnergy_GeV>=";
      cut_string[i] += ELower;
      cut_string[i] += " && S.fEnergy_GeV<=";
      cut_string[i] += EUpper;
	    
      cut_string[i] += " && S.fDirectionElevation_Rad>=";
      cut_string[i] += ElLower;
      cut_string[i] += " && S.fDirectionElevation_Rad<=";
      cut_string[i] += EUpper; 

    } // end loop over creating signal and background cuts
  //cut_char = cut_string.c_str();
  cut_string[0] += " && S.fTheta2_Deg2<=.03"; // only applies to signal
  myCutSig = cut_string[0].c_str();
  myCutBg = cut_string[1].c_str();
   
  TString xmlfilename = "TestBDT_ELow";
  xmlfilename += ELower;
  xmlfilename += "_EHigh" ;
  xmlfilename += EUpper;
  xmlfilename += "_Zenith" ;
  xmlfilename += Zenith;
	
  TString cutsfilename = "Cuts_ELow";
  cutsfilename += ELower;
  cutsfilename += "_EHigh" ;
  cutsfilename += EUpper;
  cutsfilename += "_Zenith" ;
  cutsfilename += Zenith;

  cout << "Using signal   cuts: " << myCutSig.GetTitle() << endl;
  cout << "and background cuts: " << myCutBg.GetTitle() << endl;
	

  factory->PrepareTrainingAndTestTree( myCutSig, myCutBg, prepOptions );
										
  // ---- Book MVA methods
  //
  // please lookup the various method configuration options in the corresponding cxx files, eg:
  // src/MethoCuts.cxx, etc, or here: http://tmva.sourceforge.net/optionRef.html
  // it is possible to preset ranges in the option string in which the cut optimisation should be done:
  // "...:CutRangeMin[2]=-1:CutRangeMax[2]=1"...", where [2] is the third input variable
	
  // Cut optimisation
	
  if(Use["BDTG"])  // Gradient Boost
    factory->BookMethod(TMVA::Types::kBDT, xmlfilename,
			"!H:!V:NTrees=100:MaxDepth=8:BoostType=Grad:Shrinkage=0.10:UseBaggedGrad:GradBaggingFraction=0.5");
							
  if(Use["BDTEE"])   // Adaptive Boost with Maxdepth=30 w/ cc pruning
    factory->BookMethod(TMVA::Types::kBDT, "BDTEE",
			"!H:!V:NTrees=400:nEventsMin=50:MaxDepth=10:BoostType=AdaBoost:SeparationType=GiniIndex:nCuts=20:PruneMethod=ExpectedError");
  // Boosted Decision Trees
  //
							
  if(Use["BDT"])
    {  
      factory->BookMethod( TMVA::Types::kBDT, xmlfilename,bookBDToptions);
    }
				
  if(Use["BDTB"])  // Bagging
    factory->BookMethod(TMVA::Types::kBDT, "BDTB",
			"!H:!V:NTrees=400:BoostType=Bagging:SeparationType=GiniIndex:nCuts=20:PruneMethod=NoPruning");
							
  if(Use["BDTD"])  // Decorrelation + Adaptive Boost
    factory->BookMethod(TMVA::Types::kBDT, "BDTD",
			"!H:!V:NTrees=400:nEventsMin=400:MaxDepth=5:BoostType=AdaBoost:SeparationType=GiniIndex:nCuts=20:PruneMethod=NoPruning:VarTransform=Decorrelate");
							
  // RuleFit -- TMVA implementation of Friedman's method
  if(Use["RuleFit"])
    factory->BookMethod(TMVA::Types::kRuleFit, "RuleFit",
			"H:!V:RuleFitModule=RFTMVA:Model=ModRuleLinear:MinImp=0.001:RuleMinDist=0.001:NTrees=20:fEventsMin=0.01:fEventsMax=0.5:GDTau=-1.0:GDTauPrec=0.01:GDStep=0.01:GDNSteps=10000:GDErrScale=1.02");
							
  // For an example of the category classifier, see: TMVAClassificationCategory
	
  // --------------------------------------------------------------------------------------------------
	
  // As an example how to use the ROOT plugin mechanism, book BDT via
  // plugin mechanism
  if(Use["Plugin"])
    {
      //
      // first the plugin has to be defined, which can happen either through the following line in the local or global .rootrc:
      //
      // # plugin handler          plugin name(regexp) class to be instanciated library        constructor format
      // Plugin.TMVA@@MethodBase:  ^BDT                TMVA::MethodBDT          TMVA.1         "MethodBDT(TString,TString,DataSet&,TString)"
      //
      // or by telling the global plugin manager directly
      gPluginMgr->AddHandler("TMVA@@MethodBase", "BDT", "TMVA::MethodBDT", "TMVA.1", "MethodBDT(TString,TString,DataSet&,TString)");
      factory->BookMethod(TMVA::Types::kPlugins, "BDT",
			  "!H:!V:NTrees=400:BoostType=AdaBoost:SeparationType=GiniIndex:nCuts=20:PruneMethod=CostComplexity:PruneStrength=50");
    }
	
  // --------------------------------------------------------------------------------------------------
	
  // ---- Now you can tell the factory to train, test, and evaluate the MVAs
	
  // Train MVAs using the set of training events
  factory->TrainAllMethods();
	
  // ---- Evaluate all MVAs using the set of test events
  factory->TestAllMethods();
	
  // ----- Evaluate and compare performance of all configured MVAs
  factory->EvaluateAllMethods();
	
  // --------------------------------------------------------------
	
  // Save the output
  outputFile->Close();
	
  std::cout << "==> Wrote root file: " << outputFile->GetName() << std::endl;
  std::cout << "==> TMVAClassification is done!" << std::endl;

  // print run options for log file
  std::cout << "Booking options: " << std::endl;
  std::cout << bookBDToptions << std::endl;
  std::cout << "Preparation options: " << std::endl;
  std::cout << prepOptions << std::endl;

  delete factory;
	
  // Launch the GUI for the root macros
  if(!gROOT->IsBatch())
    {
      TMVAGui(outFileName);
    }
} // end VegasTMVAClassification

// BOOKING OPTIONS

  // EventDisplay
  //bookBDToptions = "!H:!V:NTrees=300:BoostType=AdaBoost:SeparationType=GiniIndex:nCuts=20:nEventsMin=100:AdaBoostBeta=1.0:UseYesNoLeaf=True:PruneMethod=CostComplexity:PruneStrength=-1:MaxDepth=50";
  //factory->BookMethod( TMVA::Types::kBDT, xmlfilename,bookBDToptions);  
  // increase max depth, UpToDate?
  // Adaptive Boost with Maxdepth=10 with cost-complexity pruning						 
  //bookBDToptions = "!H:!V:NTrees=850:MinNodeSize=2.5%:MaxDepth=10:BoostType=AdaBoost:AdaBoostBeta=0.5:UseBaggedBoost:BaggedSampleFraction=0.5:SeparationType=GiniIndex:nCuts=20"; 
  //PruneMethod=CostComplexity
  // version 5-34-21
  //bookBDToptions = "!H:!V:NTrees=850:MinNodeSize=2.5%:MaxDepth=3:BoostType=AdaBoost:AdaBoostBeta=0.5:UseBaggedBoost:BaggedSampleFraction=0.5:SeparationType=GiniIndex:nCuts=20";
  //PruneMethod=CostComplexity
  // extra
  //bookBDToptions = "!H:!V:NTrees=300:MinNodeSize=2.5%:MaxDepth=20:BoostType=AdaBoost:SeparationType=GiniIndex:nCuts=20:PruneMethod=NoPruning";
  //bookBDToptions = "!H:!V:NTrees=300:nEventsMin=30:MaxDepth=20:BoostType=AdaBoost:SeparationType=GiniIndex:nCuts=20:PruneMethod=CostComplexity";
  // Gradient Boost, not used
  //bookBDToptions = "!H:!V:NTrees=1000:BoostType=Grad:Shrinkage=0.30:UseBaggedGrad:GradBaggingFraction=0.6:SeparationType=GiniIndex:nCuts=20:NNodesMax=10";
  
// PREPARE BDT OPTIONS

  // tell the factory to use all remaining events in the trees after training for testing:
  //prepOptions = "nTrain_Signal=1000:nTrain_Background=1000:SplitMode=Random:NormMode=NumEvents:!V" ;
  
  // If no numbers of events are given, half of the events in the tree are used for training, and
  // the other half for testing:
  //prepOptions = "SplitMode=random:!V";
  
  // To match EventDisplay
  //prepOptions = "nTrain_Signal=200000:nTrain_Background=200000:SplitMode=Random:NormMode=NumEvents:!V";
  
  //prepOptions = "nTrain_Signal=100:nTrain_Background=100:nTest_Signal=100:nTest_Background=100:SplitMode=Random:!V";


// OTHER VARIABLES

  //float nTels=S.fTelUsedInReconstruction[0]+S.fTelUsedInReconstruction[1]+S.fTelUsedInReconstruction[2]+S.fTelUsedInReconstruction[3];

  //factory->AddVariable("TMath::Log10((P.vfTels[0].pfHillasFitData.fChiSqrFit * S.fTelUsedInReconstruction[0] + P.vfTels[1].pfHillasFitData.fChiSqrFit * S.fTelUsedInReconstruction[1] + P.vfTels[2].pfHillasFitData.fChiSqrFit * S.fTelUsedInReconstruction[2] + P.vfTels[3].pfHillasFitData.fChiSqrFit * S.fTelUsedInReconstruction[3])/( S.fTelUsedInReconstruction[0] +  S.fTelUsedInReconstruction[1] + S.fTelUsedInReconstruction[2] + S.fTelUsedInReconstruction[3]))", 'F');
  //factory->AddVariable("TMath::Log10(pow((P.vfTels[0].pfHillasData.fSize - P.vfTels[0].pfHillasFitData.fSize) * S.fTelUsedInReconstruction[0],2) + pow((P.vfTels[1].pfHillasData.fSize - P.vfTels[1].pfHillasFitData.fSize) * S.fTelUsedInReconstruction[1],2) + pow((P.vfTels[2].pfHillasData.fSize - P.vfTels[2].pfHillasFitData.fSize) * S.fTelUsedInReconstruction[2],2) + pow((P.vfTels[3].pfHillasData.fSize - P.vfTels[3].pfHillasFitData.fSize) * S.fTelUsedInReconstruction[3],2) / ( S.fTelUsedInReconstruction[0] + S.fTelUsedInReconstruction[1] + S.fTelUsedInReconstruction[2] + S.fTelUsedInReconstruction[3]))", 'F');
	
  //factory->AddVariable( "TMath::Log10("
  //"pow( ((Tel1_HFit.fCosPsi<0) * (3.14159-TMath::ACos(Tel1_HFit.fCosPsi)) + (Tel1_HFit.fCosPsi>=0) * TMath::ACos(Tel1_HFit.fCosPsi)) - ((Tel1.fCosPsi<0) * (3.14159-TMath::ACos(Tel1.fCosPsi)) + (Tel1.fCosPsi>=0) * TMath::ACos(Tel1.fCosPsi)),2)*S.fTelUsedInReconstruction[0] +"
  //"pow( ((Tel2_HFit.fCosPsi<0) * (3.14159-TMath::ACos(Tel2_HFit.fCosPsi)) + (Tel2_HFit.fCosPsi>=0) * TMath::ACos(Tel2_HFit.fCosPsi)) - ((Tel2.fCosPsi<0) * (3.14159-TMath::ACos(Tel2.fCosPsi)) + (Tel2.fCosPsi>=0) * TMath::ACos(Tel2.fCosPsi)),2)*S.fTelUsedInReconstruction[1] +"
  //"pow( ((Tel3_HFit.fCosPsi<0) * (3.14159-TMath::ACos(Tel3_HFit.fCosPsi)) + (Tel3_HFit.fCosPsi>=0) * TMath::ACos(Tel3_HFit.fCosPsi)) - ((Tel3.fCosPsi<0) * (3.14159-TMath::ACos(Tel3.fCosPsi)) + (Tel3.fCosPsi>=0) * TMath::ACos(Tel3.fCosPsi)),2)*S.fTelUsedInReconstruction[2] +"
  //"pow( ((Tel4_HFit.fCosPsi<0) * (3.14159-TMath::ACos(Tel4_HFit.fCosPsi)) + (Tel4_HFit.fCosPsi>=0) * TMath::ACos(Tel4_HFit.fCosPsi)) - ((Tel4.fCosPsi<0) * (3.14159-TMath::ACos(Tel4.fCosPsi)) + (Tel4.fCosPsi>=0) * TMath::ACos(Tel4.fCosPsi)),2)*S.fTelUsedInReconstruction[3]"
  //"/ (S.fTelUsedInReconstruction[0]+S.fTelUsedInReconstruction[1]+S.fTelUsedInReconstruction[2]+S.fTelUsedInReconstruction[3]))", 'F' );
	
  // You can add so-called "Spectator variables", which are not used in the MVA training,
  // but will appear in the final "TestTree" produced by TMVA. This TestTree will contain the
  // input variables, the response values of all trained MVAs, and the spectator variables
  //factory->AddSpectator( "S.fEnergy_GeV", "Spectator 1", "Gev", 'F' );
  //factory->AddSpectator( "spec2:=var1*3",  "Spectator 2", "units", 'F' );


// OTHER TMVA METHODS:

/*
  Use["Cuts"]            = 0;
  Use["CutsD"]           = 0;
  Use["CutsPCA"]         = 0;
  Use["CutsGA"]          = 0;
  Use["CutsSA"]          = 0;
  // ---
  Use["Likelihood"]      = 0;
  Use["LikelihoodD"]     = 0; // the "D" extension indicates decorrelated input variables (see option strings)
  Use["LikelihoodPCA"]   = 0; // the "PCA" extension indicates PCA-transformed input variables (see option strings)
  Use["LikelihoodKDE"]   = 0;
  Use["LikelihoodMIX"]   = 0;
  // ---
  Use["PDERS"]           = 0;
  Use["PDERSD"]          = 0;
  Use["PDERSPCA"]        = 0;
  Use["PDERSkNN"]        = 0; // depreciated until further notice
  Use["PDEFoam"]         = 0;
  // --
  Use["KNN"]             = 0;
  // ---
  Use["HMatrix"]         = 0;
  Use["Fisher"]          = 0;
  Use["FisherG"]         = 0;
  Use["BoostedFisher"]   = 0;
  Use["LD"]              = 0;
  // ---
  Use["FDA_GA"]          = 0;
  Use["FDA_SA"]          = 0;
  Use["FDA_MC"]          = 0;
  Use["FDA_MT"]          = 0;
  Use["FDA_GAMT"]        = 0;
  Use["FDA_MCMT"]        = 0;
  // ---
  Use["MLP"]             = 0; // this is the recommended ANN
  Use["MLPBFGS"]         = 0; // recommended ANN with optional training method
  Use["CFMlpANN"]        = 0; // *** missing
  Use["TMlpANN"]         = 0;
  // ---
  Use["SVM"]             = 0;
  // ---
  Use["BDTEE"]           = 0;
*/

// See the original TMVAClassification.C macro in ROOT for all possible TMVA methods






// SINGLE SIGNAL FILE METHOD


//      TFile* inputSignal(0);		

      //if(!gSystem->AccessPathName(fnameSignal))
      //{
      //  inputSignal = TFile::Open(fnameSignal);   // check if file in local directory exists
      //}
      //if (!gSystem->AccessPathName( fnameBackground)) {
      //   inputBackground = TFile::Open( fnameBackground ); // check if file in local directory exists
      //}
		
      //if(!inputSignal)
      //{
      //  std::cout << "ERROR: could not open data file" << std::endl;
      //  exit(1);
      //}
      //if (!inputBackground) {
      //   std::cout << "ERROR: could not open background data file" << std::endl;
      //   exit(1);
      //}
      //std::cout << "--- TMVAClassification       : Using signal input file: " << inputSignal->GetName() << std::endl;
      //std::cout << "--- TMVAClassification       : Using background input file: " << inputBackground->GetName() << std::endl;
		
      //TTree* signal     = (TTree*)inputSignal->Get("SelectedEvents/CombinedEventsTree");
      //TTree *background = (TTree*)inputBackground->Get("ShowerEvents/ShowerEventsTree");
      //TTree *signal     = (TTree*)inputSignal->Get("SelectedEvents/CombinedEventsTree");
      //TTree *background = (TTree*)inputBackground->Get("SelectedEvents/CombinedEventsTree");

      // To give different trees for training and testing, do as follows:
      //    factory->AddSignalTree( signalTrainingTree, signalTrainWeight, "Training" );
      //    factory->AddSignalTree( signalTestTree,     signalTestWeight,  "Test" );

// Add just background by directory:
/*
      void* dir = gSystem->OpenDirectory(gSystem->ExpandPathName(string(dirName).c_str()));
      const char* strPtr;
		
      if(!dir)
	{
		
	  cout << "Could not open directory with background data files: " << dirName << endl;
	}
		
      TChain* chDataCombined = new TChain("SelectedEvents/CombinedEventsTree");
		
      while((strPtr = gSystem->GetDirEntry(dir)))
	{
		
	  string file = strPtr;
	  size_t found;
	  found = file.find("root");
	  if(found == string::npos)
	    {
	      continue;
	    }
	  stringstream fnamestream;
	  fnamestream << dirName << "/" << file.c_str();
	  chDataCombined->Add(fnamestream.str().c_str());
			
	}
		
				
      if(!chDataCombined)
	{
	  cerr << "Couldn't get the CombinedEventsTree" << endl;
	  return;
	}

      TTree* background = (TTree*)chDataCombined;
*/


		
      // Use the following code instead of the above two or four lines to add signal and background
      // training and test events "by hand"
      // NOTE that in this case one should not give expressions (such as "var1+var2") in the input
      //      variable definition, but simply compute the expression before adding the event
      //
      //    // --- begin ----------------------------------------------------------
      //    std::vector<Double_t> vars( 4 ); // vector has size of number of input variables
      //    Float_t  treevars[4];
      //    for (Int_t ivar=0; ivar<4; ivar++) signal->SetBranchAddress( Form( "var%i", ivar+1 ), &(treevars[ivar]) );
      //    for (Int_t i=0; i<signal->GetEntries(); i++) {
      //       signal->GetEntry(i);
      //       for (Int_t ivar=0; ivar<4; ivar++) vars[ivar] = treevars[ivar];
      //       // add training and test events; here: first half is training, second is testing
      //       // note that the weight can also be event-wise
      //       if (i < signal->GetEntries()/2) factory->AddSignalTrainingEvent( vars, signalWeight );
      //       else                            factory->AddSignalTestEvent    ( vars, signalWeight );
      //    }
      //
      //    for (Int_t ivar=0; ivar<4; ivar++) background->SetBranchAddress( Form( "var%i", ivar+1 ), &(treevars[ivar]) );
      //    for (Int_t i=0; i<background->GetEntries(); i++) {
      //       background->GetEntry(i);
      //       for (Int_t ivar=0; ivar<4; ivar++) vars[ivar] = treevars[ivar];
      //       // add training and test events; here: first half is training, second is testing
      //       // note that the weight can also be event-wise
      //       if (i < background->GetEntries()/2) factory->AddBackgroundTrainingEvent( vars, backgroundWeight );
      //       else                                factory->AddBackgroundTestEvent    ( vars, backgroundWeight );
      //    }
      //    // --- end ------------------------------------------------------------
      //

/*
  if(Use["Cuts"])
    factory->BookMethod(TMVA::Types::kCuts, cutsfilename,
			"!H:!V:FitMethod=MC:EffSel:SampleSize=200000:VarProp=FSmart");
							
  if(Use["CutsD"])
    factory->BookMethod(TMVA::Types::kCuts, "CutsD",
			"!H:!V:FitMethod=MC:EffSel:SampleSize=200000:VarProp=FSmart:VarTransform=Decorrelate");
							
  if(Use["CutsPCA"])
    factory->BookMethod(TMVA::Types::kCuts, "CutsPCA",
			"!H:!V:FitMethod=MC:EffSel:SampleSize=200000:VarProp=FSmart:VarTransform=PCA");
							
  if(Use["CutsGA"])
    factory->BookMethod(TMVA::Types::kCuts, "CutsGA",
			"H:!V:FitMethod=GA:CutRangeMin[0]=-10:CutRangeMax[0]=10:VarProp[1]=FMax:EffSel:Steps=30:Cycles=3:PopSize=400:SC_steps=10:SC_rate=5:SC_factor=0.95");
							
  if(Use["CutsSA"])
    factory->BookMethod(TMVA::Types::kCuts, "CutsSA",
			"!H:!V:FitMethod=SA:EffSel:MaxCalls=150000:KernelTemp=IncAdaptive:InitialTemp=1e+6:MinTemp=1e-6:Eps=1e-10:UseDefaultScale");
							
  // Likelihood
  if(Use["Likelihood"])
    factory->BookMethod(TMVA::Types::kLikelihood, "Likelihood",
			"H:!V:!TransformOutput:PDFInterpol=Spline2:NSmoothSig[0]=20:NSmoothBkg[0]=20:NSmoothBkg[1]=10:NSmooth=1:NAvEvtPerBin=50");
							
  // test the decorrelated likelihood
  if(Use["LikelihoodD"])
    factory->BookMethod(TMVA::Types::kLikelihood, "LikelihoodD",
			"!H:!V:!TransformOutput:PDFInterpol=Spline2:NSmoothSig[0]=20:NSmoothBkg[0]=20:NSmooth=5:NAvEvtPerBin=50:VarTransform=Decorrelate");
							
  if(Use["LikelihoodPCA"])
    factory->BookMethod(TMVA::Types::kLikelihood, "LikelihoodPCA",
			"!H:!V:!TransformOutput:PDFInterpol=Spline2:NSmoothSig[0]=20:NSmoothBkg[0]=20:NSmooth=5:NAvEvtPerBin=50:VarTransform=PCA");
							
  // test the new kernel density estimator
  if(Use["LikelihoodKDE"])
    factory->BookMethod(TMVA::Types::kLikelihood, "LikelihoodKDE",
			"!H:!V:!TransformOutput:PDFInterpol=KDE:KDEtype=Gauss:KDEiter=Adaptive:KDEFineFactor=0.3:KDEborder=None:NAvEvtPerBin=50");
							
  // test the mixed splines and kernel density estimator (depending on which variable)
  if(Use["LikelihoodMIX"])
    factory->BookMethod(TMVA::Types::kLikelihood, "LikelihoodMIX",
			"!H:!V:!TransformOutput:PDFInterpolSig[0]=KDE:PDFInterpolBkg[0]=KDE:PDFInterpolSig[1]=KDE:PDFInterpolBkg[1]=KDE:PDFInterpolSig[2]=Spline2:PDFInterpolBkg[2]=Spline2:PDFInterpolSig[3]=Spline2:PDFInterpolBkg[3]=Spline2:KDEtype=Gauss:KDEiter=Nonadaptive:KDEborder=None:NAvEvtPerBin=50");
							
  // test the multi-dimensional probability density estimator
  // here are the options strings for the MinMax and RMS methods, respectively:
  //      "!H:!V:VolumeRangeMode=MinMax:DeltaFrac=0.2:KernelEstimator=Gauss:GaussSigma=0.3" );
  //      "!H:!V:VolumeRangeMode=RMS:DeltaFrac=3:KernelEstimator=Gauss:GaussSigma=0.3" );
  if(Use["PDERS"])
    factory->BookMethod(TMVA::Types::kPDERS, "PDERS",
			"!H:!V:NormTree=T:VolumeRangeMode=Adaptive:KernelEstimator=Gauss:GaussSigma=0.3:NEventsMin=400:NEventsMax=600");
							
  if(Use["PDERSkNN"])
    factory->BookMethod(TMVA::Types::kPDERS, "PDERSkNN",
			"!H:!V:VolumeRangeMode=kNN:KernelEstimator=Gauss:GaussSigma=0.3:NEventsMin=400:NEventsMax=600");
							
  if(Use["PDERSD"])
    factory->BookMethod(TMVA::Types::kPDERS, "PDERSD",
			"!H:!V:VolumeRangeMode=Adaptive:KernelEstimator=Gauss:GaussSigma=0.3:NEventsMin=400:NEventsMax=600:VarTransform=Decorrelate");
							
  if(Use["PDERSPCA"])
    factory->BookMethod(TMVA::Types::kPDERS, "PDERSPCA",
			"!H:!V:VolumeRangeMode=Adaptive:KernelEstimator=Gauss:GaussSigma=0.3:NEventsMin=400:NEventsMax=600:VarTransform=PCA");
							
  // Multi-dimensional likelihood estimator using self-adapting phase-space binning
  if(Use["PDEFoam"])
    factory->BookMethod(TMVA::Types::kPDEFoam, "PDEFoam",
			"H:!V:SigBgSeparate=F:TailCut=0.001:VolFrac=0.0333:nActiveCells=500:nSampl=2000:nBin=5:CutNmin=T:Nmin=100:Kernel=None:Compress=T");
							
  // K-Nearest Neighbour classifier (KNN)
  if(Use["KNN"])
    factory->BookMethod(TMVA::Types::kKNN, "KNN",
			"H:nkNN=20:ScaleFrac=0.8:SigmaFact=1.0:Kernel=Gaus:UseKernel=F:UseWeight=T:!Trim");
  // H-Matrix (chi2-squared) method
  if(Use["HMatrix"])
    {
      factory->BookMethod(TMVA::Types::kHMatrix, "HMatrix", "!H:!V");
    }
	
  // Fisher discriminant
  if(Use["Fisher"])
    {
      factory->BookMethod(TMVA::Types::kFisher, "Fisher", "H:!V:Fisher:CreateMVAPdfs:PDFInterpolMVAPdf=Spline2:NbinsMVAPdf=60:NsmoothMVAPdf=10");
    }
	
  // Fisher with Gauss-transformed input variables
  if(Use["FisherG"])
    {
      factory->BookMethod(TMVA::Types::kFisher, "FisherG", "H:!V:VarTransform=Gauss");
    }
	
  // Composite classifier: ensemble (tree) of boosted Fisher classifiers
  if(Use["BoostedFisher"])
    {
      factory->BookMethod(TMVA::Types::kFisher, "BoostedFisher", "H:!V:Boost_Num=20:Boost_Transform=log:Boost_Type=AdaBoost:Boost_AdaBoostBeta=0.2");
    }
	
  // Linear discriminant (same as Fisher)
  if(Use["LD"])
    {
      factory->BookMethod(TMVA::Types::kLD, "LD", "H:!V:VarTransform=None");
    }
	
  // Function discrimination analysis (FDA) -- test of various fitters - the recommended one is Minuit (or GA or SA)
  if(Use["FDA_MC"])
    factory->BookMethod(TMVA::Types::kFDA, "FDA_MC",
			"H:!V:Formula=(0)+(1)*x0+(2)*x1+(3)*x2+(4)*x3:ParRanges=(-1,1);(-10,10);(-10,10);(-10,10);(-10,10):FitMethod=MC:SampleSize=100000:Sigma=0.1");
							
  if(Use["FDA_GA"])  // can also use Simulated Annealing (SA) algorithm (see Cuts_SA options])
    factory->BookMethod(TMVA::Types::kFDA, "FDA_GA",
			"H:!V:Formula=(0)+(1)*x0+(2)*x1+(3)*x2+(4)*x3:ParRanges=(-1,1);(-10,10);(-10,10);(-10,10);(-10,10):FitMethod=GA:PopSize=300:Cycles=3:Steps=20:Trim=True:SaveBestGen=1");
							
  if(Use["FDA_SA"])  // can also use Simulated Annealing (SA) algorithm (see Cuts_SA options])
    factory->BookMethod(TMVA::Types::kFDA, "FDA_SA",
			"H:!V:Formula=(0)+(1)*x0+(2)*x1+(3)*x2+(4)*x3:ParRanges=(-1,1);(-10,10);(-10,10);(-10,10);(-10,10):FitMethod=SA:MaxCalls=15000:KernelTemp=IncAdaptive:InitialTemp=1e+6:MinTemp=1e-6:Eps=1e-10:UseDefaultScale");
							
  if(Use["FDA_MT"])
    factory->BookMethod(TMVA::Types::kFDA, "FDA_MT",
			"H:!V:Formula=(0)+(1)*x0+(2)*x1+(3)*x2+(4)*x3:ParRanges=(-1,1);(-10,10);(-10,10);(-10,10);(-10,10):FitMethod=MINUIT:ErrorLevel=1:PrintLevel=-1:FitStrategy=2:UseImprove:UseMinos:SetBatch");
							
  if(Use["FDA_GAMT"])
    factory->BookMethod(TMVA::Types::kFDA, "FDA_GAMT",
			"H:!V:Formula=(0)+(1)*x0+(2)*x1+(3)*x2+(4)*x3:ParRanges=(-1,1);(-10,10);(-10,10);(-10,10);(-10,10):FitMethod=GA:Converger=MINUIT:ErrorLevel=1:PrintLevel=-1:FitStrategy=0:!UseImprove:!UseMinos:SetBatch:Cycles=1:PopSize=5:Steps=5:Trim");
							
  if(Use["FDA_MCMT"])
    factory->BookMethod(TMVA::Types::kFDA, "FDA_MCMT",
			"H:!V:Formula=(0)+(1)*x0+(2)*x1+(3)*x2+(4)*x3:ParRanges=(-1,1);(-10,10);(-10,10);(-10,10);(-10,10):FitMethod=MC:Converger=MINUIT:ErrorLevel=1:PrintLevel=-1:FitStrategy=0:!UseImprove:!UseMinos:SetBatch:SampleSize=20");
							
  // TMVA ANN: MLP (recommended ANN) -- all ANNs in TMVA are Multilayer Perceptrons
  if(Use["MLP"])
    {
      factory->BookMethod(TMVA::Types::kMLP, "MLP", "H:!V:NeuronType=tanh:VarTransform=N:NCycles=500:HiddenLayers=N+5:TestRate=10:EpochMonitoring");
    }
	
  if(Use["MLPBFGS"])
    {
      factory->BookMethod(TMVA::Types::kMLP, "MLPBFGS", "H:!V:NeuronType=tanh:VarTransform=N:NCycles=500:HiddenLayers=N+5:TestRate=10:TrainingMethod=BFGS:!EpochMonitoring");
    }
	
	
  // CF(Clermont-Ferrand)ANN
  if(Use["CFMlpANN"])
    {
      factory->BookMethod(TMVA::Types::kCFMlpANN, "CFMlpANN", "!H:!V:NCycles=2000:HiddenLayers=N+1,N");    // n_cycles:#nodes:#nodes:...
    }
	
  // Tmlp(Root)ANN
  if(Use["TMlpANN"])
    {
      factory->BookMethod(TMVA::Types::kTMlpANN, "TMlpANN", "!H:!V:NCycles=200:HiddenLayers=N+1,N:LearningMethod=BFGS:ValidationFraction=0.3");    // n_cycles:#nodes:#nodes:...
    }
	
  // Support Vector Machine
  if(Use["SVM"])
    {
      factory->BookMethod(TMVA::Types::kSVM, "SVM", "Gamma=0.25:Tol=0.001:VarTransform=Norm");
    }
*/


