#define _OAWG

#include "TROOT.h"
#include "TString.h"

TString curIncludePath=gSystem->GetIncludePath();
TString newIncludePath=TString("-I/veritas/userspace3/mbuchove/veritas/src/vegas-v2_5_4/common/include/ ")+curIncludePath;
gSystem->SetIncludePath(newIncludePath);

#ifndef __STDC_LIMIT_MACROS
#define __STDC_LIMIT_MACROS
#endif

#ifndef __STDC_CONSTANT_MACROS
#define __STDC_CONSTANT_MACROS
#endif

#include <stdint.h>

//#include "VATime.h"
#include "/veritas/userspace3/mbuchove/veritas/src/vegas-v2_5_4/common/include/VATime.h"
#include "/veritas/userspace3/mbuchove/veritas/src/vegas-v2_5_4/common/include/VAAzElRADecXY.h"
#include "/veritas/userspace3/mbuchove/veritas/src/vegas-v2_5_4/resultsExtractor/include/VASkyMap.h"
#include "/veritas/userspace3/mbuchove/veritas/src/vegas-v2_5_4/resultsExtractor/include/VASkyMapExclusionRegion.h"
#include "/veritas/userspace3/mbuchove/veritas/src/vegas-v2_5_4/common/include/VACoordinatePair.h"


using namespace std;

void dumpStg6Results(string inFile,string outFile, int nEvents = 0,bool useRBM = 1,double theta2Cut = 0.03, bool NoFromStg5 = true,string Stg5Path = "/data/veritas/bzitzer/bootes_1/data/root/")
{
  gROOT->SetBatch(true);
  TH1D* hSigRF = new TH1D("SigDistRF","Significance Distrbution RF",50,-5,5);
  TH1D* hSigCBG = new TH1D("SigDistCBG","Significance Distrbution CBG",50,-5,5);
  
  // Opening files and getting VEGAS objects:
  TFile* f = new TFile(inFile.c_str(),"READ");
  if(!f->IsOpen() )
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
  VASkyMap* vaMapOn = (VASkyMap*)gDirectory->Get("RingBackgroundModelAnalysis/SkyMapOn");
  VASkyMap* vaMapAlpha = (VASkyMap*)gDirectory->Get("RingBackgroundModelAnalysis/fAlphaMap");
  VACoordinatePair onCenter = vaMapOn->GetCenter();
  VACoordinatePair eventCoord;
  VACoordinatePair trackCoord;
  VACoordinatePair fRootCoord;
  VACoordinatePair sourceCoord;

  // --------------------
  //  Exclusion regions:
  // --------------------
    
  TDirectory* RBMExclusion = (TDirectory*)gDirectory->Get("RingBackgroundModelAnalysis/ExclusionRegions");

  if( RBMExclusion == NULL )
    {
      cerr << "Problem loading the RBM exclusion directory!" << endl;
      return;
    }
  int nRegions = RBMExclusion->GetNkeys();
  VASkyMapExclusionRegion* hSourceExclusion;
  const int tmp = nRegions;
  VASkyMapExclusionRegion* exclList[tmp];
  vector<VASkyMapExclusionRegion*> vaSourceExcl;

  TIter next(RBMExclusion->GetListOfKeys());
  TKey *key;
  int i=0;
  while(key=(TKey*)next())
    {
      hSourceExclusion = (VASkyMapExclusionRegion*)RBMExclusion->FindObjectAny(key->GetName())->Clone();
      if( hSourceExclusion != NULL)
	{
	  if( hSourceExclusion->wasUsed() )
	    {
	      cout << i << endl;
	      exclList[i] = hSourceExclusion;
	      vaSourceExcl.push_back(hSourceExclusion);
	      cout << hSourceExclusion->GetName() << endl;
	      //cout << "Exclusion Center RA: " << hSourceExclusion->center().getRA_J2000_Deg() << endl;
	      cout << "Exclusion Center RA: " << exclList[i]->center().getRA_J2000_Deg() << endl;
	      
	      cout << "Exclusion Center Dec: " << hSourceExclusion->center().getDec_J2000_Deg() << endl;	  
	      cout << "Exclusion Radius: " << hSourceExclusion->radius_Deg() << endl;
	      i++;
	    }
	}
    }
  nRegions = i;
  dumpExcl(exclList,nRegions,outFile);


  double TelLatRad = 5.52828386357865242e-01;
  double TelLongRad = -1.93649167430676461e+00;
  Float_t EffArea,EnergyGeV,El,Az;
  double RA,Dec;
  double RATrack,DecTrack;
  double DayNS;
  UInt_t MJD;
  UInt_t RunID;
  Float_t El_track,Az_track;
  Float_t El_check,Az_check;
  double MJDDbl;
  Double_t W;
  Double_t liveTime;
  Double_t PsiEventTree;

  int NumRuns = RunTree->GetEntries(); 
  Bool_t IsOn,IsOff;
  double Noise;
  Float_t RA_fRoot,Dec_fRoot;

  EventTree->SetBranchAddress("RunNum",&RunID);
  EventTree->SetBranchAddress("Azimuth",&Az);
  EventTree->SetBranchAddress("Elevation",&El);
  EventTree->SetBranchAddress("Noise",&Noise);
  EventTree->SetBranchAddress("EnergyGeV",&EnergyGeV);
  
  EventTree->SetBranchAddress("TrackingAzimuth",&Az_track);
  EventTree->SetBranchAddress("TrackingElevation",&El_track);
  EventTree->SetBranchAddress("OnEvent",&IsOn);  
  EventTree->SetBranchAddress("OffEvent",&IsOff);    
  EventTree->SetBranchAddress("Weight",&W);
  EventTree->SetBranchAddress("Psi",&PsiEventTree);

  // EventTree->SetBranchAddress("RA",&RA_fRoot);    
  // EventTree->SetBranchAddress("Dec",&Dec_fRoot);
  
  EventTree->SetBranchAddress("MJDDbl",&MJDDbl);
  EventTree->SetBranchAddress("DayNSDbl",&DayNS);
  EventTree->SetBranchAddress("EffectiveArea",&EffArea);

  double RASource,DecSource,RAOffset,DecOffset;
  double RAError,DecError;
  double fSigRF,fSigCBG;
  int RunNumRunTree;
  RunTree->SetBranchAddress("faLiveTime",&liveTime);
  RunTree->SetBranchAddress("fSourceDecDeg",&DecSource);
  RunTree->SetBranchAddress("fSourceRADeg",&RASource);
  RunTree->SetBranchAddress("fOffsetDecDeg",&DecOffset);
  RunTree->SetBranchAddress("fOffsetRADeg",&RAOffset);
  RunTree->SetBranchAddress("fSignificance",&fSigRF);
  RunTree->SetBranchAddress("faRunNumber",&RunNumRunTree);
  // Signficance distributions:
 
  VAAzElRADecXY coord(TelLongRad,TelLatRad);
  VATime time;
  TGraph* map = new TGraph();
  TGraph* trackError = new TGraph();
  TH2D* map2 = new TH2D("skymap","raw counts map",100,65,115,100,10,30);
  double X,Y;
  double XRot,YRot;
  double theta;

  double RunIDOld = 0;
  int j = 0;
  int k = 0;

  filebuf fb;
  fb.open(outFile.c_str(),ios::out);
  ostream os(&fb);

  TGraph* geffAreaVTime = new TGraph();

  if( nEvents == 0 ){ nEvents = EventTree->GetEntries(); }
  
  int NumOnEvents = 0;
  int NumOffEvents = 0;
  // Stuff to make RBM work;
  double upperRadRBM = 0.8;
  double lowerRadRBM = 0.6;
  double angularSep,psi;
  bool IsInExcl;

  // Stuff to make zCresent work:
  double areaBgRegion = DBL_EPSILON;
  double upperRadCres = 0.4;
  double lowerRadCres = 0.6;
  double areaOnRegion = TMath::TwoPi()*(1.0 - TMath::Cos(TMath::Sqrt(theta2Cut)*TMath::DegToRad())); // rad^2
  areaOnRegion *= pow(TMath::RadToDeg(),2.0); // deg^2
  //double areaOnRegion = TMath::Pi()*theta2Cut;

  double wobOffset;

  // vaStage6 Generalized LiMa calc stuff:
  vector<double> Non;
  vector<double> Noff;
  vector<double> Alpha;
  vector<double> ExpOn;
  vector<double> ExpOff;
  vector<int> RunIDVec;
  vector<double> SigmaVec;
  int NumRuns = 0;
  // header

  os << "RunID LiveTime(min) Time(MJD) RA       Dec       RA_track        Dec_track    Energy(GeV)  IsOn Weight Elevation Azimuth Noise Offset" << endl;
  os << "----------------------------------------------------------------------------------------------------------" << endl;
  cout.precision(12);
  os.precision(7);
  
  double AvgNoiseFromStg5;
  
  for(int i=0; i<nEvents; i++)
    {
      
      EventTree->GetEntry(i);
     
      if(i%1000==0)
	cout << "On Event: " << i << " of " << nEvents <<endl;

      if(RunID != RunIDOld)
	{
	  // A new run has started:
	  if(RunIDOld != 0)
	    {
	      Non.push_back(NumOnEvents);
	      Noff.push_back(NumOffEvents);
	      ExpOn.push_back(liveTime/60);
	      ExpOff.push_back(liveTime/60);
	      Alpha.push_back(areaOnRegion/areaBgRegion);
	      cout << RunIDOld << " Non: " << NumOnEvents << " Noff: " << NumOffEvents << " Alpha: " << areaOnRegion/areaBgRegion << " Exp: " << liveTime/60 << endl;
	      fSigCBG = lima(NumOnEvents,NumOffEvents,areaOnRegion/areaBgRegion);
	      SigmaVec.push_back(fSigCBG);
	      RunIDVec.push_back(RunIDOld);
	      hSigCBG->Fill(fSigCBG);
	     
	      NumOnEvents = 0;
	      NumOffEvents = 0;
	      
	    }
      
	  RunTree->GetEntry(j);	
	  if(RunID != RunNumRunTree)
	    {
	      cout << "Run mis-match! " << endl;
	      cout << " Event Tree thinks it is run number: " << RunID << endl;
	      cout << " Run Tree thinks it is run number: " << RunNumRunTree << endl;

	    }
	  j++;
	  hSigRF->Fill(fSigRF);
	  cout << fSigRF << endl;
	  // RASource, RAOffset in Deg
	  if(NoFromStg5 == true)
	    AvgNoiseFromStg5 = getAvgPedVar(RunID,Stg5Path);
	   
	 
	  // I confess to a bit of a Kludge here:
	  coord.setRASource2000((RASource + RAOffset)*TMath::DegToRad());
	  coord.setDecSource2000((DecSource + DecOffset)*TMath::DegToRad());
	  sourceCoord.setCoordinates_Deg(RASource,DecSource,2);
	  cout << RunID << " " << liveTime << " " << RASource << " " << DecSource << " " << RAOffset << " " << DecOffset << endl; 
	}
  
      time.setFromMJDDbl(MJDDbl);
      // --------------------
      //  Coordinate transforms:
      // --------------------

      // Az,El already in radians
      coord.AzEl2RADec2000(Az,El,time,RA,Dec); // RA,Dec in radians
      // Az_track, El_track in degrees
      coord.AzEl2RADec2000(Az_track*TMath::DegToRad(),El_track*TMath::DegToRad(),time,RATrack,DecTrack); // RATrack,DecTrack in radians
      coord.AzElToXY(Az,El,time,RASource*TMath::DegToRad(),DecSource*TMath::DegToRad(),X,Y); 
      coord.AzElToXY(Az,El,time,X,Y); 
      // coord.XY2RADec2000(X,Y,time,RA,Dec);
      coord.Derotate(time,X,Y,RATrack*TMath::DegToRad(),DecTrack*TMath::DegToRad(),XRot,YRot);
      // Flip axis:
      //XRot = -1.0*XRot;
      // RA Dec in Degrees now
      RA *= TMath::RadToDeg();
      Dec *= TMath::RadToDeg();
      RATrack *= TMath::RadToDeg();
      DecTrack *= TMath::RadToDeg();
          
      // RA_fRoot *= TMath::RadToDeg();
      // Dec_fRoot *= TMath::RadToDeg();
      // RA = XRot + RATrack - RAOffset;
      //Dec = YRot + DecTrack - DecOffset;
      // RAError = RA - RA_fRoot;
      // DecError = Dec - Dec_fRoot;
      RAError = RASource - (RATrack - RAOffset);
      DecError = DecSource - (DecTrack - DecOffset);
      // error corrections:
      //      RA += RAError;
      //      Dec += DecError;
      RAError *= 3600; //arc sec
      DecError *= 3600; // arc sec
  	  
      coord.RADec2000ToAzEl(RATrack*TMath::DegToRad(),DecTrack*TMath::DegToRad(),time,Az_check,El_check);
      // checks in Deg
      Az_check*=TMath::RadToDeg();
      El_check*=TMath::RadToDeg();

      eventCoord.setCoordinates_Deg(RA,Dec,2);   
      //trackCoord.setCoordinates_Deg(RATrack,DecTrack,2);
      trackCoord.setCoordinates_Deg(RASource+RAOffset,DecSource+DecOffset,2);
      fRootCoord.setCoordinates_Deg(RA_fRoot,Dec_fRoot,2);

      angularSep = onCenter.angularSeparation_Deg(eventCoord);
      //psi = trackCoord.angularSeparation_Deg(eventCoord);
      theta =  sourceCoord.angularSeparation_Deg(eventCoord);
      psi = PsiEventTree;
      //      cout << "dPsi: " << psi - PsiEventTree << endl;
      //-------------------------	  
      // Stuff for RBM analysis:
      //-------------------------
      if(useRBM)
	{
	  IsOff = 0;
	  IsInExcl = 0;
	  if(RunID != RunIDOld)
	    {
	      //wobOffset = sqrt(pow(DecOffset,2.0)+pow(RAOffset,2.0));
	      wobOffset = sourceCoord.angularSeparation_Deg(trackCoord);
	      upperRadCres = wobOffset + sqrt(theta2Cut);
	      lowerRadCres = wobOffset - sqrt(theta2Cut);
	      // Segue North Kludge/Hack:
	      /*
	      if(TMath::Abs(trackCoord.getRA_J2000_Deg()-151.767) < 0.1 && TMath::Abs(trackCoord.getDec_J2000_Deg()-16.582) < 0.1)
		{
		  cout << "Warning! I think this is a Segue North Run!" << endl;
		  upperRadCres = 0.5;
		}
	      */
	      VASkyMap* vaMapCustom = new VASkyMap("h","h1",sourceCoord,6.0,0.01);
	      //VASkyMap* vaMapCustom = new VASkyMap("h","h1",trackCoord,6.0,0.01);
	      vaMapCustom->MakeBinAreaMap();
	      areaBgRegion = IntegrateBgArea(vaMapCustom,exclList,trackCoord,lowerRadCres,upperRadCres,nRegions);
	      vaMapCustom->Delete();

	      cout << "Alpha for Run# " << RunID << " is: " << areaOnRegion/areaBgRegion << endl; 
	     
	    }
	  //if( lowerRadRBM < angularSep && angularSep < upperRadRBM )
	  if( lowerRadCres < psi && psi < upperRadCres )   
	    {	      
	      for(int m=0; m<nRegions; m++)
		{
		  if( exclList[m]->isWithinRegion(eventCoord) )
		    IsInExcl = 1;
		}
	      if(!IsInExcl)
		{
		  IsOff = 1;
		  W = areaOnRegion/areaBgRegion;
		}
	    }
	}
      //      IsOn = reDefOnFlag(sourceCoord,eventCoord,theta2Cut);
      
      if(IsOff || IsOn)
	{

	  map->SetPoint(k,RA,Dec);
	  trackError->SetPoint(k,RAError,DecError); 
	  if(TMath::Abs(RAError) > 40.0 || TMath::Abs(DecError) > 40.0)
	    cout << "Warning! Tracking Error large for for: " << RunID << " RA Error: " << RAError << " Dec Error: " << DecError << endl;
	  k++;
	 
	  if(IsOn)
	    {
	      // if( sqrt((RA - RASource)**2.0 + (Dec - DecSource)**2.0) > sqrt(theta2Cut))
	      if( theta > sqrt(theta2Cut) )
		{
		  cout << "Theta: " << theta << endl;
		}
	      NumOnEvents++;
	    }
	  if(IsOff){ NumOffEvents++; }

	  // putting needed output into ASCII file
	  os << RunID << " ";
	  os << liveTime << " ";

	  os.precision(12);
	  os << MJDDbl << " ";
	  os.precision(9);
	  os << RA << " ";
	  os << Dec << " ";
	  os << RATrack << " ";
	  os << DecTrack << " ";
	  os.precision(7);
	  os << EnergyGeV << "        ";
	  os << IsOn << "    ";
	  os << W << "       ";
	
	  os << El_track << " ";
	  os << Az_track << " ";
	  if(!NoFromStg5)
	    os << Noise << " ";
	  else
	    os << AvgNoiseFromStg5 << " ";
	  os << psi << " ";

	  os << endl;
	  
	}
      RunIDOld = RunID;
    }

  Non.push_back(NumOnEvents);
  Noff.push_back(NumOffEvents);
  ExpOn.push_back(liveTime/60);
  ExpOff.push_back(liveTime/60);
  Alpha.push_back(areaOnRegion/areaBgRegion);
  fSigCBG = lima(NumOnEvents,NumOffEvents,areaOnRegion/areaBgRegion);
  SigmaVec.push_back(fSigCBG);
  RunIDVec.push_back(RunIDOld);
 
  cout << RunIDOld << " Non: " << NumOnEvents << " Noff: " << NumOffEvents << " Alpha: " << areaOnRegion/areaBgRegion << " Exp: " << liveTime/60 << endl;
    
  VAStatisticsUtilitiesAnl* StatAnl = new VAStatisticsUtilitiesAnl(Non,Noff,ExpOn,ExpOff,Alpha);
  
  cout.precision(7);
  cout << "Number of ON events: " << sumVector(Non) << endl;
  cout << "Number of OFF events: " << sumVector(Noff) << endl;
  cout << "Mean Alpha: " << sumVector(Alpha)/Alpha.size() << endl;
  cout << "Total Exp Time: " << sumVector(ExpOn) << endl;
  cout << "Excess : " << StatAnl->ExcessRate() << " +/- " << StatAnl->ExcessRateError() << endl;
  cout << "Generalized LiMa Significance: " << StatAnl->GeneralisedLiMa() << endl;
  fb.close();
  fb.open("Results.txt",ios::out);
  ostream os(&fb);
  for(int i=0; i<Non.size(); i++)
    {
      os << "Results for run# " << RunIDVec.at(i) << endl;
      os << "  Number of ON events: " << Non.at(i) << endl;
      os << "  Number of OFF events: " << Noff.at(i) << endl;
      os << "  Alpha: " << Alpha.at(i) << endl;
      os << "  Exp Time: " << ExpOn.at(i) << endl;
      os << "  Significance: " << SigmaVec.at(i) << endl;
      os << "  " << endl;
    }
  os << "---------------------------" << endl;
  os << "Final Results for all runs:" << endl;
  os << "  Number of ON events: " << sumVector(Non) << endl;
  os << "  Number of OFF events: " << sumVector(Noff) << endl;
  os << "  Mean Alpha: " << calcWeightAvgVector(Alpha,ExpOn) << endl;
  os << "  Total Exp Time: " << sumVector(ExpOn) << endl;
  os << "  Excess : " << StatAnl->ExcessRate() << " +/- " << StatAnl->ExcessRateError() << endl;
  os << "  Generalized LiMa Significance: " << StatAnl->GeneralisedLiMa() << endl;
  fb.close();
  
  TCanvas* c1 = new TCanvas();
  map->Draw("A*");
  TEllipse* drawBg[tmp];
  for(int k=0; k<nRegions; k++)
    {
      drawBg[k] = new TEllipse(exclList[k]->center().getRA_J2000_Deg(),exclList[k]->center().getDec_J2000_Deg(), exclList[k]->radius_Deg(),exclList[k]->radius_Deg());
      drawBg[k]->SetLineColor(kBlue);
      drawBg[k]->SetFillColor(0);
      drawBg[k]->SetFillStyle(0);
      
      drawBg[k]->Draw("same");
    }
  // ON region:
  TEllipse* drawONregion = new TEllipse(RASource,DecSource,sqrt(theta2Cut),sqrt(theta2Cut));
 
  drawONregion->SetLineColor(kRed);
  drawONregion->SetFillColor(0);
  drawONregion->SetFillStyle(0);     
  drawONregion->Draw("same");

  TCanvas* c2 = new TCanvas();
  trackError->GetXaxis()->SetTitle("#delta RA (asec)");
  trackError->GetYaxis()->SetTitle("#delta Dec (asec)");
  
  trackError->Draw("A*");

 
  fSigCBG = lima(NumOnEvents,NumOffEvents,areaOnRegion/areaBgRegion);
  hSigCBG->Fill(fSigCBG);
  TCanvas* c3 = new TCanvas();
  TH1F* hSigRBM = (TH1F*)gDirectory->Get("RingBackgroundModelAnalysis/SigDistributionMinusAllExcl");

  TLegend* l = new TLegend(0.7,0.7,0.9,0.9);

  //hSigRBM->SetDirectory(0);
  hSigRF->SetDirectory(0);
  hSigCBG->SetDirectory(0);
  hSigRF->Scale(1.0/hSigRF->GetEntries());
  //hSigRBM->Scale(1.0/hSigRBM->GetEntries());
  hSigCBG->Scale(1.0/hSigCBG->GetEntries());
 
  hSigCBG->Draw();
  hSigCBG->SetLineColor(kBlue);
 
  hSigRF->Draw("same");
  hSigRF->SetLineColor(kBlack);
 
  //hSigRBM->SetLineColor(kRed);
  //hSigRBM->Draw("same");

  //l->AddEntry(hSigRBM,"Ring Background Model");
  l->AddEntry(hSigRF,"Reflected Ring Model");
  l->AddEntry(hSigCBG,"Cresent Background Model");
  l->Draw("same");
    
  hSigRF->Fit("gaus","LLN");
  hSigCBG->Fit("gaus","LLN");
  //hSigRBM->Fit("gaus","LLN");
  /*
  TF1* hFitRF = hSigRF->GetFunction("gaus");
  TF1* hFitCBG = hSigRF->GetFunction("gaus");
  TF1* hFitRBM = hSigRF->GetFunction("gaus");
  
  hFitRF->Draw("same"); 
  hFitRF->SetLineColor(kBlue);
  hFitCBG->Draw("same");
  
  hFitRBM->Draw("same");
  hFitRBM->SetLineColor(kRed);
  */
  cout << "Number of RF entries: " << hSigRF->GetEntries() << endl;
  cout << "Number of CBG entries: " << hSigCBG->GetEntries() << endl;
  cout << "CBG Results in Results.txt and Results.root. Remember to rename them!" << endl;
  f->Close();
  TFile* fOut = new TFile("Results.root","RECREATE");
  if(!fOut->IsOpen())
    {
      cerr << "Problem with output root file!" << endl;
      return;
    }
  //hSigRBM->Write();
  hSigRF->Write();
  hSigCBG->Write();
  c1->Write();
  c2->Write();
  c3->Write();
  fOut->Close();
}

double sumVector(vector<double> x)
{
  double sum = 0;
  for(int i=0; i<x.size(); i++)
    sum += x.at(i);
  
  return(sum);
}

double calcWeightAvgVector(vector<double> x,vector<double> w)
{
  double sum = 0;
  double norm = 0;
  for(int i=0; i<x.size(); i++)
    {
      sum += x.at(i)*w.at(i);
      norm += w.at(i);
    }
  return(sum/norm);
}

bool reDefOnFlag(VACoordinatePair SourcePt,VACoordinatePair EventPt,double theta2Cut)
{
  /*
  double ra_s = SourcePt.getRA_J2000_Deg();
  double dec_s = SourcePt.getDec_J2000_Deg();
  double ra = EventPt.getRA_J2000_Deg();
  double dec = EventPt.getDec_J2000_Deg();
  double theta = sqrt(pow(ra_s - ra,2) + pow(dec_s - dec,2)); 
*/
  //  double theta = SourcePt.angularSeparation_Deg(EventPt);

  double theta = EventPt.angularSeparation_Deg(SourcePt);
  
  if(theta < sqrt(theta2Cut))
    return(true);
  else
    return(false);

}

void dumpExcl(VASkyMapExclusionRegion** x,int n,string outFile)
{
  ostringstream os;
  os << outFile << ".ex";
  ofstream out(os.str().c_str());
  out.precision(7);
  for(int i=0; i<n; i++)
    {  
      cout <<x[i]->GetName() << " " << x[i]->radius_Deg() << endl;
      if(x[i]->wasUsed())
	{
	  out << "Region Name:" << x[i]->GetName() << endl;
	  out << "Radius (deg): " << x[i]->radius_Deg() << endl;
	  out << "RA (deg): " << x[i]->center().getRA_J2000_Deg() << endl;
	  out << "Dec (deg): " << x[i]->center().getDec_J2000_Deg() << endl;
	  out << endl;
	}
    }
}

double getLTFromStg5File(int RunNum,string inRootPath)
{
  ostringstream os;
  os << inRootPath << "/" << RunNum << ".stg5.root";
  cout << "Getting PedVar from: " << os.str() << endl;
  return(getLTFromStg5File(os.str().c_str()));

}

double getLTFromStg5File(string inRootFile)
{

  VARootIO io(inRootFile.c_str(),true);
  io.loadTheRootFile();
  if(!io.IsOpen())
    {
      cout << "Warning! No root file! " << endl;
      return(0);
    }
  VARunHeader* runHeader = io.loadTheRunHeader();
  VARunDetails* runDetails = runHeader->pfRunDetails;
  io.closeTheRootFile();
  return(runDetails->fRunCutLiveTimeSeconds);
}

double GetSourceOnArea(VASkyMapExclusionRegion** ExclList,int nExclRegions)
{
  // Do not use! Source Excl radius > theta cut!
  double rad = 0;
  double area = 0;
  for(int i=0; i<ExclList.size(); i++)
    {
      if(!strcmp( ExclList[i]->GetName(),"Source") )
	rad = ExclList[i]->radius_Deg();
    }
  area = TMath::Pi()*(rad**2.0);
  return(area);
}

double IntegrateBgArea(VASkyMap* vaMap,VASkyMapExclusionRegion** ExclList,VACoordinatePair vaCenter,double innerRadius = 0.4,double outerRadius = 0.6,int nExclRegions)
{
  VASkyMap* vaMap2 = new VASkyMap("vaMap","Area Bins",vaCenter,6,0.025);
  vaMap2->MakeBinAreaMap();
  if( vaMap == NULL )
    {
      cout << "Problem with map object!" << endl;
      return(DBL_EPSILON);
    }
  VACoordinatePair pt;
  double psi,RA,Dec;
  double area = 0;
  bool isInExcl = 0;
  for(int i=0; i<vaMap->GetNbinsX(); i++)
    {
      for(int j=0; j<vaMap->GetNbinsY(); j++)
	{
	  isInExcl = 0;
	  pt = vaMap->GetBinCoordinates(i,j);
	  psi = vaCenter.angularSeparation_Deg(pt);
	  if( innerRadius < psi && psi < outerRadius )
	    { 
	      //cout << i << " " << j << endl;
	      //cout << vaMap->GetBinArea(i,j) << endl;
	      //cout << vaMap2->GetBinArea(i,j) << endl;	      
	      for(int k=0; k<nExclRegions; k++)
		{
		  if( ExclList[k]->isWithinRegion(pt) )
		    isInExcl = 1;
		}
	      if(!isInExcl){ area += vaMap->GetBinArea(i,j); }
	    }
	}
    }
  vaMap2->Delete();
  return(area);

}

double lima(double on, double off, double alpha)
{


  double diff = on-alpha*off;

  if (on>0 && off>0){
    double lima17 = TMath::Sqrt(2) * 
      TMath::Power(
                   on * TMath::Log( ((1.0+alpha)/alpha) * (on/(on+off))  )
                   +
                   off * TMath::Log( (1.0+alpha)*(off/(on+off)))
                   , 0.5);

  }
  else {
    cout<<"warning "<<on<<" "<<off<<endl;
    return 0;
  }
  
  if(diff<0)
    return -lima17;
  else
    return lima17;
}

double getAvgPedVar(int RunNum,string inRootPath,int winSize = 7, int numTels = 4)
{
  ostringstream os;
  os << inRootPath << "/" << RunNum << ".stg5.root";
  cout << "Getting PedVar from: " << os.str() << endl;
  return(getAvgPedVar(os.str(),winSize,numTels));

}
double getAvgPedVar(string inRootFile,int winSize = 7, int numTels = 4)
{
  //cout << inRootFile << endl;
  if(numTels==0)
    return(0);

  VARootIO io(inRootFile.c_str(),true);
  io.loadTheRootFile();
  if(!io.IsOpen())
    {
      cout << "Warning! No root file! " << endl;
      return(0);
    }
  const VAPixelStatusData* pd = io.loadThePixelStatusData();
  const VAArrayInfo* ai = io.loadTheArrayInfo();
  const VAQStatsData* qd = io.loadTheQStatsData();
  
  double PedVar = 0;
  for(int i=0; i<numTels; i++)
    PedVar += qd->getCameraAverageTraceVarTimeIndpt(i,7,pd,ai);
  io.closeTheRootFile();
  return(PedVar/numTels);
}
