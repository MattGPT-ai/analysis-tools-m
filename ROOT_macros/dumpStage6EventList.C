#ifndef __STDC_LIMIT_MACROS
#define __STDC_LIMIT_MACROS
#endif

#ifndef __STDC_CONSTANT_MACROS
#define __STDC_CONSTANT_MACROS
#endif

#ifndef _OAWG
#define _OAWG
#endif

//#include <stdio.h>
#include <iostream>
#include <string>
#include <fstream>

#include "TROOT.h"
#include "TTree.h"
#include "TFile.h"
//#include "TString.h"

//#include "VATime.h"

//using std::string;
using std::cout;
using std::cerr;
using std::endl;


void dumpStage6EventList(std::string inFilename, std::string outFilename, int nEvents=0 )
{
  //gROOT->SetBatch(true);

  TFile* inFile = new TFile(inFilename.c_str(),"READ");
  if( !inFile->IsOpen() )
    {
      cerr << "Problem opening ROOT file!" << endl;
      return;
    }
  
  TTree* EventTree = (TTree*)gDirectory->Get("EventStatsTree");
  if( EventTree == NULL )
    {
      cout << "No Event Tree!" << endl;
      return;
    }

  TTree* RunTree = (TTree*)gDirectory->Get("RunStatsTree");
  if( RunTree == NULL )
    {
      cout << "No Run Tree!" << endl;
      return;
    }

  //  std::ostream test(std::cout);
  //test << "hi" << endl;
  
  Bool_t IsOn;
  //Double_t MJDDbl; //time
  double MJDDbl;
  Float_t EnergyGeV;

  EventTree->SetBranchAddress("OnEvent",&IsOn);
  EventTree->SetBranchAddress("MJDDbl",&MJDDbl);
  EventTree->SetBranchAddress("EnergyGeV",&EnergyGeV);

  //VATime time;

  if ( nEvents == 0 ) { 
    int nEvents = EventTree->GetEntries(); 
  } 
  UInt_t j=0, k=0;
  UInt_t NumRuns = 0; // 
  
  std::filebuf filBuf;
  filBuf.open(outFilename.c_str(),std::ios::out);
  std::ostream outStream(&filBuf);

  //os << "Time(MJD) Energy(GeV) << endl;
  cout.precision(14);
  outStream.precision(7);

  for (int i=0; i<nEvents; i++)
    {
      EventTree->GetEntry(i);

      if(i%1000 == 0)
	cout << "Event: " << i << " of " << nEvents << endl;
    
      
      //time.setFromMJDDbl(MJDDbl);

      if(IsOn)
	{
	  outStream.precision(20);
	  outStream << MJDDbl << "\t";
	  outStream.precision(12);
	  outStream << EnergyGeV << "\t";
	  outStream << endl;
	}

    } // end loop over events 

  
  inFile->Close();
  //outFile->Close();
  filBuf.close();

  exit(EXIT_SUCCESS);
} // end dumpStage6EventList

/*
int main(int argc, char** argv)
{

  std::string inFilename = "/veritas/userspace2/mbuchove/Mrk421/config/stage6_eventList_Mrk421s6.root";
  std::string outFilename = "/veritas/userspace2/mbuchove/Mrk421/config/eventList.txt";


  dumpStage6EventList(inFilename, outFilename);
  
  return EXIT_SUCCESS;

}
*/
