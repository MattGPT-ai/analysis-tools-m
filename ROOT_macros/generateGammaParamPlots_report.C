//////////////////////////////////////////////////////////////////////////////////////
//  2014/07/07 change the theta2 definition for data (using stage6 instead of stage5C)

#include <iostream>
#include <fstream>
#include <string>
#include <iomanip>
#include <vector>
#include <algorithm>
#include <functional>
#include <sstream>

#include "TCanvas.h"
#include "TPad.h"
#include "TGraph.h"
#include "TFile.h"
#include "TTree.h"
#include "TDirectory.h"
#include "TSystemDirectory.h"
#include "TList.h"
#include "TF1.h"
#include "TIterator.h"
#include "TH1F.h"
#include "TH2F.h"
#include "TH1D.h"
#include "TH2D.h"
#include "TF2.h"
#include "TStyle.h"
#include "TProfile.h"
#include "TChain.h"
#include "TLine.h"
#include "TBox.h"
#include "TEllipse.h"
#include "TPaletteAxis.h"
#include "TAxis.h"
#include "TMarker.h"
#include "TPad.h"
#include "TGraph.h"
#include "TFile.h"
#include "TTree.h"
#include "TDirectory.h"
#include "TSystemDirectory.h"
#include "TList.h"
#include "TF1.h"
#include "TIterator.h"
#include "TH1F.h"
#include "TH2F.h"
#include "TH1D.h"
#include "TH2D.h"
#include "TF2.h"
#include "TStyle.h"
#include "TProfile.h"
#include "TChain.h"
#include "TLine.h"
#include "TBox.h"
#include "TEllipse.h"
#include "TPaletteAxis.h"
#include "TAxis.h"
#include "TMarker.h"
#include "TMath.h"
#include "TPaveStats.h"
#include "TPaveText.h"
#include "TColor.h"

#include "/usr/local/veritas/vegas-v2.5.3/macros/aclicPreProcCommands.h"
#include <Riostream.h>

#include "/usr/local/veritas/vegas-v2.5.3/common/include/VAShowerData.h"
#include "/usr/local/veritas/vegas-v2.5.3/common/include/VASimulationDataClasses.h"
#include "/usr/local/veritas/vegas-v2.5.3/common/include/VAParameterData.h"

using namespace std;

int getEbin( float energy );
int getShowerParameterID( string param);
int getHillasParameterID( string param );
//outname : should include .root 
void generateGammaParamPlots( string stage6filename, string filelist,
				     bool isData,
                                     string outname, string cut,
                                     string source="Crab",
                                     double index=2.5, bool doDraw2d=false )
{
  string runType;
  if( isData ) runType = "Data";
  else runType = "Sim";

  if( source == "Crab" ) index = 2.5;
  else if (source == "Mrk421") index = 2.2;
  else {
    index = 2.5;
    cout <<"Not sure which index you want to use. We will use " << index <<endl;
  }

  double mswV, mslV, maxHeightV, thetaSqV;
  if( cut == "soft"){
    mswV = 1.1;
    mslV = 1.3;
    maxHeightV = 7;
    thetaSqV = 0.03;
  } else if ( cut == "soft_loose" ){
    mswV = 1.5;
    mslV = 1.5;
    maxHeightV = 7;
    thetaSqV = 0.04;
  } else if ( cut == "loose" ){
    mswV = 2;
    mslV = 2;
    maxHeightV = 0;
    thetaSqV = 0.04;
  } else if ( cut == "loose_small" ){
    mswV = 2;
    mslV = 2;
    maxHeightV = 0;
    thetaSqV = 0.01;
  } else if ( cut == "med" ){
    mswV = 1.1;
    mslV = 1.3;
    maxHeightV = 7;
    thetaSqV = 0.01;
  } else if ( cut == "hard" ){
    mswV = 1.1;
    mslV = 1.4;
    maxHeightV = 0;
    thetaSqV = 0.01;
  }

  cout <<"-------- cut : " << cut <<endl;
  cout <<"      MSW : " << mswV <<endl;
  cout <<"      MSL : " << mslV <<endl;
  cout <<"      Max Height: " << maxHeightV <<endl;
  cout <<"      Theta2 : " << thetaSqV <<endl;
  cout <<"----------------------------"<<endl;

  //histograms
  //shower parameter
  const int NofEbins = 6;  //6 default
//  double EbinLow_GeV[NofEbins] = { 100, 200, 500, 1000, 2000, 5000 };
//  double EbinUp_GeV[NofEbins] = { 200, 500, 1000, 2000, 5000, 10000 };

  const int NofShowerParams = 9;
  string NameOfParams[NofShowerParams] = { "MSW", "MSL", "MRSW", "MRSL", "ShowerMaxHeight",
                                          "EnergyDiff", "Energy", "Theta2", "LogTheta2"};
  int NbinsParams[NofShowerParams] = { 80, 40, 40, 40, 50,
                                       80, 80, 80, 80}; 
  float RangeLowerParams[NofShowerParams] = {0.0, 0.0, -1.5, -1.5, 0.0,
                                             0.0, -2.0, 0.0, -5.0 };
  float RangeUpperParams[NofShowerParams] = {2.0, 2.0, 1.5,  1.5, 30.,
                                             1.0, 2.0, 0.2, 2.0};

  const int NofTelParams = 17;
  string NameOfParamsTel[NofTelParams] = { "ImpactDist", "Width", "Length", "SizeFracLo", "Size",
                                          "NTube", "Loss", "Asymmetry", "MinorAsymmetry", "TDCTime", 
                                          "Max3", "Distance", "Frac1", "Frac2", "Frac3", 
                                          "Max1", "Max2" };
  int NbinsParamsTel[NofTelParams] = {  40, 60, 60, 60, 80, 
					1000, 25, 50, 50, 50,
                                        80, 25, 50, 50, 50,
                                        80, 80 }; 
  float RangeLowerParamsTel[NofTelParams] = {0.0, 0.0, 0.0, 0.0, 2.0,
                                             0.0, 0.0, -2.0, -2.0,-10000.0,
                                             1.0, 0.0, 0.0, 0.0, 0.0,
                                             1.0, 1.0 }; 
  float RangeUpperParamsTel[NofTelParams] = {400, 0.4, 0.6, 1.2, 6.0,
                                             3.0, 1.0, 2.0, 2.0, 10000.0,
                                             5.0, 2.0, 1.0, 1.0, 1.0,
                                             5.0, 5.0 };

  const int NofType = 3;
  string NameOfType[NofType] = {"On", "Off", "Excess"};
  UShort_t color_pal[NofType] = { kRed, kBlue, kBlack};
  int typeId, EbinId;

  char title[150];
  TH1F *h1Params[NofShowerParams][NofEbins][NofType];
  TH1F *h1ParamsPerTel[NofTelParams][NofEbins][kMaxTels][NofType];
  for(int i=0; i<NofShowerParams; i++){
    for(int j=0; j<NofEbins; j++){
      for(int k=0; k<NofType; k++){
        sprintf( title, "h1%s_%s_Ebin%d_%s", NameOfParams[i].c_str(), runType.c_str(), j, NameOfType[k].c_str());
        h1Params[i][j][k] = new TH1F( title, title, NbinsParams[i], RangeLowerParams[i], RangeUpperParams[i]);
        h1Params[i][j][k]->SetMarkerStyle(20);
        h1Params[i][j][k]->SetMarkerColor( color_pal[k] );
        h1Params[i][j][k]->SetLineColor( color_pal[k] );
      }
    }
  }
  for(int i=0; i<NofTelParams; i++){
    for(int j=0; j<NofEbins; j++){
      for(int k=0; k<NofType; k++){
        for(int l=0; l<kMaxTels; l++){
          sprintf( title, "h1%s_%s_Ebin%d_tel%d_%s", NameOfParamsTel[i].c_str(), runType.c_str(), j, l+1, NameOfType[k].c_str());
          h1ParamsPerTel[i][j][l][k] = new TH1F( title, title, NbinsParamsTel[i], RangeLowerParamsTel[i], RangeUpperParamsTel[i]);
          h1ParamsPerTel[i][j][l][k]->SetMarkerStyle(20);
          h1ParamsPerTel[i][j][l][k]->SetMarkerColor( color_pal[k] );
          h1ParamsPerTel[i][j][l][k]->SetLineColor( color_pal[k] ); 
        }
      }
    }
  }
   
  //read data file
  TFile *f6 = new TFile( stage6filename.c_str() );
  Double_t rAlpha, rOnExp, rOffExp;
  Double_t rDayNSDbl, rPsi, rWeight;
  Float_t rElRad, rAzRad;
  Float_t rThetaSq;
  uint32_t rEvnum, rRunnum, rMjdInt;
  bool rOnEvent, rOffEvent;
  float rEnergyGeV;
  TTree *trSt6Rs = 0;
  TTree *trSt6Es = 0;
  float grandAlpha=0;
  float weight = 0;
  if ( isData ) {
    f6->GetObject( "RunStatsTree", trSt6Rs );
    f6->GetObject( "EventStatsTree", trSt6Es );
    cout << "rs = " << trSt6Rs << "  es = " << trSt6Es << endl;
    cout << "Found " << trSt6Es->GetEntries() << " entries in EventStatsTree" << endl;
    trSt6Rs->SetBranchAddress( "fAlpha", &rAlpha );
    trSt6Rs->SetBranchAddress( "fOnExposure", &rOnExp );
    trSt6Rs->SetBranchAddress( "fOffExposure", &rOffExp );
    trSt6Es->SetBranchAddress( "DayNSDbl", &rDayNSDbl );
    trSt6Es->SetBranchAddress( "Psi", &rPsi );
    trSt6Es->SetBranchAddress( "Weight", &rWeight );
    trSt6Es->SetBranchAddress( "ArrayEventNum", &rEvnum );
    trSt6Es->SetBranchAddress( "RunNum", &rRunnum );
    trSt6Es->SetBranchAddress( "MJDInt", &rMjdInt );
    trSt6Es->SetBranchAddress( "OnEvent", &rOnEvent );
    trSt6Es->SetBranchAddress( "OffEvent", &rOffEvent );
    trSt6Es->SetBranchAddress( "EnergyGeV", &rEnergyGeV );
    trSt6Es->SetBranchAddress( "Elevation", &rElRad );
    trSt6Es->SetBranchAddress( "Azimuth", &rAzRad );
    trSt6Es->SetBranchAddress( "ThetaSq", &rThetaSq );

    //Determine overall alpha
    double totalOn = 0, totalOff = 0;
    for ( int i=0; i<trSt6Rs->GetEntries(); ++i ){
      trSt6Rs->GetEntry(i);
      totalOn += rOnExp;
      totalOff += rOffExp;
      cout << rOnExp << "  " << rOffExp
           << "  " << totalOn << "  " << totalOff << endl;
      }
    if ( totalOff > 0 ) grandAlpha = totalOn / totalOff;
    cout << "Alpha for full data set is " << grandAlpha << endl;
  }

  // Open the filelist - single file or chain - and build the index
  int length = filelist.size();
  bool ischain = false;
  unsigned nf = 0;
  if ( length > 6 ){
    if ( filelist.substr( length-4, 4 ) != "root" ) {
      ischain = true;
      cout << "Input file name doesn't end with  \"root\", so assuming it's"
           << " a text file with a list of names" <<endl;
    } else {
      cout << "Input file ends with \"root\", so assuming we're analyzing "
           << "a single file." << endl;
    }
  } else {
    cout <<"checking the filelist - " << filelist <<" : too short filename?" <<endl;
    return;
  }

  TChain *ch = new TChain( "SelectedEvents/CombinedEventsTree" );
  if ( !ischain ){
    ch->AddFile( filelist.c_str() );
    nf = 1;
  } else {
    string tmps;
    ifstream inlist( filelist.c_str(), ios::in );
    while ( inlist >> tmps ){
      ++nf;
      cout << "adding file " << nf << ": " << tmps << endl;
      ch->Add( tmps.c_str() );
    }
  }
  cout << "Chain contains " << nf << " files." << endl;
//  const int nfiles = nf;
  int numIndices = 0;
  numIndices = ch->BuildIndex("S.fRunNum", "S.fArrayEventNum");
  cout << "Build index: found " << numIndices << " entries" << endl;
  if ( numIndices <= 0 ){
    cout << "Indexing failed - quitting." << endl;
    return;
  }

  // Acquire branches of the Combined Tree
  cout << "Setting up combined tree" << endl;
  VASimulationData *sim = 0;
  VAShowerData *sh = 0;
  VAParameterisedEventData *parData = 0;
  VAHillasData *hillas[4] = {0,0,0,0};
  UChar_t is[4] = {0,0,0,0};
  Double_t rID[4] = {0,0,0,0};
  Double_t tID[4] = {0,0,0,0};
  if ( !isData ) ch->SetBranchAddress( "Sim", &sim );
  ch->SetBranchAddress( "S", &sh );
  ch->SetBranchAddress( "T1Rcn", &is[0] );
  ch->SetBranchAddress( "T2Rcn", &is[1] );
  ch->SetBranchAddress( "T3Rcn", &is[2] );
  ch->SetBranchAddress( "T4Rcn", &is[3] );
  ch->SetBranchAddress( "T1ImpactDist", &rID[0] );
  ch->SetBranchAddress( "T2ImpactDist", &rID[1] );
  ch->SetBranchAddress( "T3ImpactDist", &rID[2] );
  ch->SetBranchAddress( "T4ImpactDist", &rID[3] );
  ch->SetBranchAddress( "P", &parData );
  if ( !isData ){
    ch->SetBranchAddress( "T1TrueImpactDist", &tID[0] );
    ch->SetBranchAddress( "T2TrueImpactDist", &tID[1] );
    ch->SetBranchAddress( "T3TrueImpactDist", &tID[2] );
    ch->SetBranchAddress( "T4TrueImpactDist", &tID[3] );
  }

  //loop over events
  cout <<"starting loop over events" <<endl;
  int NumToRead = 0;

  if( isData ) NumToRead = trSt6Es->GetEntries();
  else NumToRead = ch->GetEntries(); 
  
  for(int i=0; i<NumToRead; i++){
    //initialization
    for(int n=0; n<kMaxTels; n++) hillas[n] = 0;

    //read
    if( isData ){
      trSt6Es->GetEntry(i);
      ch->GetEntryWithIndex(rRunnum, rEvnum);
    } else {
      grandAlpha = 0;
      ch->GetEntry(i);
    }
    if (parData){
      for(int n=0; n<kMaxTels; n++)
        hillas[n] = parData->getHillasData(n);    
    }

    if( !isData || rOnEvent || rOffEvent ){
      if( !isData ){
        bool isBadAz = false;
        float az = sh->fArrayTrackingAzimuth_Deg;
        if ( (source == "Crab" && az>100&&az<260)
          || (source == "Mrk421" && ((az>=0 && az<=70) || (az>=290 && az<=360))) ) 
          isBadAz = false;
        else
          isBadAz = true;
        //apply cuts to sim to match data
        if ( sh->fMSW<0.05 || sh->fMSW>mswV || sh->fMSL<0.05 || sh->fMSL>mslV ||
             sh->fTheta2_Deg2>thetaSqV || sh->fShowerMaxHeight_KM<maxHeightV
             || isBadAz
            ) {
          continue;
        }
        if( sh->fEnergy_GeV > 0 )
          grandAlpha = pow( sh->fEnergy_GeV/50., 2.0-index );
      } 
      if ( rOnEvent ){
        typeId = 0;
        weight = 1;
      }
      if ( rOffEvent ){
        typeId = 1;
        weight = grandAlpha;
      }
      if( !isData ){
        typeId = 2;
        weight = grandAlpha;
      }

      EbinId = getEbin( sh->fEnergy_GeV );
      if( EbinId == -9 )
        continue;

      //fill the histogram for shower parameters
      h1Params[getShowerParameterID("MSW")][EbinId][typeId]->Fill( sh->fMSW, weight );
      h1Params[getShowerParameterID("MSL")][EbinId][typeId]->Fill( sh->fMSL, weight );
      h1Params[getShowerParameterID("MRSW")][EbinId][typeId]->Fill( sh->fMRSW, weight );
      h1Params[getShowerParameterID("MRSL")][EbinId][typeId]->Fill( sh->fMRSL, weight );
      h1Params[getShowerParameterID("ShowerMaxHeight")][EbinId][typeId]->Fill( sh->fShowerMaxHeight_KM, weight );
      h1Params[getShowerParameterID("EnergyDiff")][EbinId][typeId]->Fill( sh->fEnergyRMS_GeV/sh->fEnergy_GeV, weight );
      h1Params[getShowerParameterID("Energy")][EbinId][typeId]->Fill( TMath::Log10(sh->fEnergy_GeV*1e-3), weight );
      if(!isData) {
        h1Params[getShowerParameterID("Theta2")][EbinId][typeId]->Fill( sh->fTheta2_Deg2, weight );
        h1Params[getShowerParameterID("LogTheta2")][EbinId][typeId]->Fill( TMath::Log10(sh->fTheta2_Deg2), weight );
      } else {
        h1Params[getShowerParameterID("Theta2")][EbinId][typeId]->Fill( rThetaSq, weight );
        h1Params[getShowerParameterID("LogTheta2")][EbinId][typeId]->Fill( TMath::Log10(rThetaSq), weight );
      }

      //fill per telescope information, broken somewhere here...
      for(int ntel=0; ntel<kMaxTels; ntel++){
        if( sh->fTelUsedInParameterReconstruction.at(ntel)) {
          h1ParamsPerTel[getHillasParameterID("ImpactDist")][EbinId][ntel][typeId]->Fill( sh->fTelImpactDistMirrPlane_M.at(ntel), weight );
          h1ParamsPerTel[getHillasParameterID("Width")][EbinId][ntel][typeId]->Fill( hillas[ntel]->fWidth, weight );
          h1ParamsPerTel[getHillasParameterID("Length")][EbinId][ntel][typeId]->Fill( hillas[ntel]->fLength, weight );
          h1ParamsPerTel[getHillasParameterID("SizeFracLo")][EbinId][ntel][typeId]->Fill( hillas[ntel]->fFractionLo, weight );
          h1ParamsPerTel[getHillasParameterID("Size")][EbinId][ntel][typeId]->Fill( TMath::Log10(hillas[ntel]->fSize), weight );
          h1ParamsPerTel[getHillasParameterID("NTube")][EbinId][ntel][typeId]->Fill( TMath::Log10(hillas[ntel]->fPixelsInImage), weight );
          h1ParamsPerTel[getHillasParameterID("Loss")][EbinId][ntel][typeId]->Fill( hillas[ntel]->fLoss, weight );
          h1ParamsPerTel[getHillasParameterID("Asymmetry")][EbinId][ntel][typeId]->Fill( hillas[ntel]->fAsymmetry, weight );
          h1ParamsPerTel[getHillasParameterID("MinorAsymmetry")][EbinId][ntel][typeId]->Fill( hillas[ntel]->fMinorAsymmetry, weight );
          h1ParamsPerTel[getHillasParameterID("TDCTime")][EbinId][ntel][typeId]->Fill( hillas[ntel]->fTDCTime, weight );
          h1ParamsPerTel[getHillasParameterID("Max3")][EbinId][ntel][typeId]->Fill( TMath::Log10(hillas[ntel]->fMax3), weight );
          h1ParamsPerTel[getHillasParameterID("Distance")][EbinId][ntel][typeId]->Fill( hillas[ntel]->fDist, weight );
          h1ParamsPerTel[getHillasParameterID("Frac1")][EbinId][ntel][typeId]->Fill( hillas[ntel]->fFrac1, weight );
          h1ParamsPerTel[getHillasParameterID("Frac2")][EbinId][ntel][typeId]->Fill( hillas[ntel]->fFrac2, weight );
          h1ParamsPerTel[getHillasParameterID("Frac3")][EbinId][ntel][typeId]->Fill( hillas[ntel]->fFrac3, weight );
          h1ParamsPerTel[getHillasParameterID("Max1")][EbinId][ntel][typeId]->Fill( TMath::Log10(hillas[ntel]->fMax1), weight );
          h1ParamsPerTel[getHillasParameterID("Max2")][EbinId][ntel][typeId]->Fill( TMath::Log10(hillas[ntel]->fMax2), weight );
        }
      } 

    } //if it is sim. or on or off

  } //read all events

  //get excess
  if( isData ){
    for(int l=0; l<NofShowerParams; l++){
      for(int n=0; n<NofEbins; n++){
        h1Params[l][n][2]->Add( h1Params[l][n][0], 1.0 );
        h1Params[l][n][2]->Add( h1Params[l][n][1], -1.0 );
      }
    }
    for(int l=0; l<NofTelParams; l++){
      for(int n=0; n<NofEbins; n++){
        for(int ntel=0; ntel<kMaxTels; ntel ++){
          h1ParamsPerTel[l][n][ntel][2]->Add( h1ParamsPerTel[l][n][ntel][0], 1.0 );
          h1ParamsPerTel[l][n][ntel][2]->Add( h1ParamsPerTel[l][n][ntel][1], -1.0 );
        }
      }
    }
  }
/*
  TCanvas *can[NofShowerParams];
  for(int i=0; i<NofShowerParams; i++){
    sprintf( title, "can_%i", i);
    can[i] = new TCanvas( title, title, 1000, 800);
    can[i]->SetFillColor(10);
    can[i]->Divide(3,2);
    for(int j=0; j<NofEbins; j++){
      can[i]->cd(j+1);
      gPad->SetGrid();
      gPad->SetTickx(1);
      gPad->SetTicky(1);
      if( isData ){
        h1Params[i][j][0]->Draw(); 
        h1Params[i][j][1]->Draw("same"); 
        h1Params[i][j][2]->Draw("same"); 
      }else {
        h1Params[i][j][2]->Draw(); 
      }
    }  
  }

  TCanvas *canTel[NofTelParams][kMaxTels];
  for(int i=0; i<NofTelParams; i++){
    for(int ntel=0; ntel<kMaxTels; ntel++){
      sprintf( title, "can%d_tel%d", i, ntel+1);
      canTel[i][ntel] = new TCanvas( title, title, 1000, 800);
      canTel[i][ntel]->SetFillColor(10);
      canTel[i][ntel]->Divide(3,2);
      for(int j=0; j<NofEbins; j++){
        canTel[i][ntel]->cd(j+1);
        gPad->SetGrid();
        gPad->SetTickx(1);
        gPad->SetTicky(1);
        if( isData ){
          h1ParamsPerTel[i][j][ntel][0]->Draw();
          h1ParamsPerTel[i][j][ntel][1]->Draw("same");
          h1ParamsPerTel[i][j][ntel][2]->Draw("same");
        } else {
          h1ParamsPerTel[i][j][ntel][2]->Draw();
        }   
      } 
    }
  }
*/
  //write to root file
  int typeStart = 0;
  if( isData ) typeStart = 0;
  else typeStart = 2;

  TFile *rfout = new TFile( outname.c_str(), "recreate");
  for(int l=0; l<NofShowerParams; l++){
    for(int n=0; n<NofEbins; n++){
      for(int m=typeStart; m<NofType; m++){
        h1Params[l][n][m]->Write();
      }
    }
  }
  for(int l=0; l<NofTelParams; l++){
    for(int n=0; n<NofEbins; n++){
      for(int ntel = 0; ntel<kMaxTels; ntel++){
        for(int m=typeStart; m<NofType; m++){
          h1ParamsPerTel[l][n][ntel][m]->Write();
        }
      }
    }
  }
  rfout->Write();
  rfout->Close();

}

int getEbin( float energy )
{
  int id = -9;
  if( energy >= 100 && energy < 200 ) id = 0;
  else if (energy >= 200 && energy < 500 ) id = 1;
  else if (energy >= 500 && energy < 1000 ) id = 2;
  else if (energy >=1000 && energy < 2000 ) id = 3;
  else if (energy >=2000 && energy < 5000 ) id = 4;
  else if (energy >=5000 && energy < 10000 ) id = 5;
  else id = -9;

  return id;

}

int getHillasParameterID( string param )
{
  if( param.compare("ImpactDist" ) == 0 ) return 0; 
  else if( param.compare( "Width" ) == 0 ) return 1; 
  else if( param.compare( "Length" ) == 0 ) return 2; 
  else if( param.compare( "SizeFracLo" ) == 0 ) return 3;
  else if( param.compare( "Size" ) == 0 ) return 4;
  else if( param.compare( "NTube") == 0 ) return 5;
  else if( param.compare( "Loss") == 0 ) return 6;
  else if( param.compare( "Asymmetry") == 0 ) return 7;
  else if( param.compare( "MinorAsymmetry") == 0 ) return 8;
  else if( param.compare( "TDCTime") == 0 ) return 9;
  else if( param.compare( "Max3") == 0 ) return 10;
  else if( param.compare( "Distance") == 0 ) return 11;
  else if( param.compare( "Frac1") == 0 ) return 12;
  else if( param.compare( "Frac2") == 0 ) return 13;
  else if( param.compare( "Frac3") == 0 ) return 14;
  else if( param.compare( "Max1") == 0 ) return 15;
  else if( param.compare( "Max2") == 0 ) return 16;
  else {
    cout <<"unknown parameter! check the code! "<< param <<endl;
    return -9;
  }
}

int getShowerParameterID( string param)
{
  if( param.compare( "MSW") == 0 ) return 0;
  else if( param.compare( "MSL") == 0 ) return 1;
  else if( param.compare( "MRSW") == 0 ) return 2;
  else if( param.compare( "MRSL") == 0 ) return 3;
  else if( param.compare( "ShowerMaxHeight") == 0 ) return 4;
  else if( param.compare( "EnergyDiff") == 0 ) return 5;
  else if( param.compare( "Energy") == 0 ) return 6;
  else if( param.compare( "Theta2") == 0 ) return 7;
  else if( param.compare( "LogTheta2") == 0 ) return 8;
  else {
    cout <<"unknown parameter! check the code! "<< param <<endl;
    return -9;
  }
}
