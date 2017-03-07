#include <iostream>
#include <fstream>
#include <string>
#include <iomanip>
#include <vector>
#include <algorithm>
#include <functional>
#include <sstream>

#include "TCanvas.h"
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
#include "TGraphErrors.h"

//#include "/usr/local/veritas/vegas-v2_5_2/macros/aclicPreProcCommands.h"

using namespace std;
  
const int kMaxTels = 4;
const int NofEbins = 6;
int EbinLow_GeV[NofEbins] = { 100, 200, 500, 1000, 2000, 5000 };
int EbinUp_GeV[NofEbins] = { 200, 500, 1000, 2000, 5000, 10000 };

const int NofShowerParams = 9;
string NameOfParams[NofShowerParams] = { "MSW", "MSL", "MRSW", "MRSL", "ShowerMaxHeight",
                                          "EnergyDiff", "Energy", "Theta2", "LogTheta2"};
float LowerV[NofShowerParams] = { 0.5, 0, -1, -1, 0,
                                  -999, -999, 0, -999 };
float UpperV[NofShowerParams] = { 1.5, 2.0, 1, 1, 15,
                                  -999, -999, 0.04, -999 };

const int NofTelParams = 17;               
string NameOfParamsTel[NofTelParams] = { "ImpactDist", "Width", "Length", 
																					"SizeFracLo", "Size",
                                          "NTube", "Loss", "Asymmetry", "MinorAsymmetry", "TDCTime",
                                          "Max3", "Distance", "Frac1", "Frac2", "Frac3",
                                          "Max1", "Max2" };

const int NofType = 3;
string NameOfType[NofType] = {"On", "Off", "Excess"};

TH1F *h1Params1[NofShowerParams][NofEbins][NofType];
TH1F *h1ParamsAccumulated1[NofShowerParams][NofEbins][NofType];
TH1F *h1ParamsPerTel1[NofTelParams][NofEbins][kMaxTels][NofType];
TH1F *h1ParamsPerTelCombined1[NofTelParams][kMaxTels][NofType];

TH1F *h1Params2[NofShowerParams][NofEbins][NofType];
TH1F *h1ParamsAccumulated2[NofShowerParams][NofEbins][NofType];
TH1F *h1ParamsPerTel2[NofTelParams][NofEbins][kMaxTels][NofType];
TH1F *h1ParamsPerTelCombined2[NofTelParams][kMaxTels][NofType];

TH1F *h1ParamsAccumulatedDiff[NofShowerParams][NofEbins][NofType];
TFile *rfin1;
TFile *rfin2;

void printParameters()
{
  cout <<"!! Shower Parameters" <<endl;
  for(int i=0; i<NofShowerParams; i++){
    cout << NameOfParams[i] <<"\t";
  }
  cout <<endl;

 cout <<"!! Hillas Parameters" <<endl;
 for(int i=0; i<NofTelParams; i++){
    cout << NameOfParamsTel[i] <<"\t";
 }
 cout <<endl;


}

void plotParameters( string paramFilename1, bool isData )
{
  rfin1 = new TFile( paramFilename1.c_str(), "read");
  char title[200];

  string runType;
  if( isData ) runType="Data";
  else runType="Sim";

  TCanvas *can[NofShowerParams];
  for(int i=0; i<NofShowerParams; i++){
    for(int j=0; j<NofEbins; j++){
      for(int k=0; k<NofType; k++){
        sprintf( title, "h1%s_%s_Ebin%d_%s", NameOfParams[i].c_str(), runType.c_str(), j, NameOfType[k].c_str());
        h1Params1[i][j][k] = (TH1F*)rfin1->Get( title );
        sprintf( title, "%s_%s_E%dGeV-E%dGeV_%s", NameOfParams[i].c_str(), runType.c_str(), EbinLow_GeV[j], EbinUp_GeV[j], NameOfType[k].c_str());
        h1Params1[i][j][k]->SetTitle( title );
      }
    }
  }

  for(int i=0; i<NofTelParams; i++){
    for(int j=0; j<NofEbins; j++){
      for(int k=0; k<NofType; k++){
        for(int ntel=0; ntel<kMaxTels; ntel++){
          sprintf( title, "h1%s_%s_Ebin%d_tel%d_%s", NameOfParamsTel[i].c_str(), runType.c_str(), j, ntel+1, NameOfType[k].c_str());
          h1ParamsPerTel1[i][j][ntel][k] = (TH1F*)rfin1->Get( title );
          sprintf( title, "h1%s_%s_E%dGeV-E%dGeV_tel%d_%s", NameOfParamsTel[i].c_str(), runType.c_str(), EbinLow_GeV[j], EbinUp_GeV[j], ntel+1, NameOfType[k].c_str());
          h1ParamsPerTel1[i][j][ntel][k]->SetTitle(title);
        }
      }
    }
  }

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
      h1Params1[i][j][0]->Draw();
      h1Params1[i][j][1]->Draw("same");
      h1Params1[i][j][2]->Draw("same");
    }
  }
/*
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
        h1ParamsPerTel1[i][j][ntel][0]->Draw();
        h1ParamsPerTel1[i][j][ntel][1]->Draw("same");
        h1ParamsPerTel1[i][j][ntel][2]->Draw("same");

      }
    }
  }
*/
}

void overlayParamPlots_report(string paramFilename1, bool isData1, string paramFilename2, bool isData2, double yaxis_min=1e-2, double yaxis_max=10, string printfilename="",Short_t col2=kRed, bool doNormalizedArea=true)
{
  cout <<"file1 (black) : " << paramFilename1 <<endl;
  cout <<"file2 ( " << col2 <<" ) : "<< paramFilename2 <<endl;

  TFile *rfin1 = new TFile( paramFilename1.c_str(), "read");
  TFile *rfin2 = new TFile( paramFilename2.c_str(), "read");

  //plot single parameters
  char title[200];

    string runType1, runType2;
    if( isData1 ) runType1="Data";
    else runType1="Sim";
    if( isData2 ) runType2="Data";
    else runType2="Sim";

    int reportTypeId=2;

    for(int i=0; i<NofEbins; i++){
      for(int j=0; j<NofShowerParams; j++){
        sprintf( title, "h1%s_%s_Ebin%d_%s", NameOfParams[j].c_str(), runType1.c_str(), i, NameOfType[reportTypeId].c_str());
        h1Params1[j][i][reportTypeId] = (TH1F*)rfin1->Get( title );
        h1Params1[j][i][reportTypeId]->SetLineColor(kBlack);
        h1Params1[j][i][reportTypeId]->SetMarkerSize(1.5);
        sprintf( title, "h1%s_%s_Ebin%d_%s", NameOfParams[j].c_str(), runType2.c_str(), i, NameOfType[reportTypeId].c_str());
        h1Params2[j][i][reportTypeId] = (TH1F*)rfin2->Get( title );
        h1Params2[j][i][reportTypeId]->SetMarkerStyle(20);
        h1Params2[j][i][reportTypeId]->SetMarkerColor(col2);
        h1Params2[j][i][reportTypeId]->SetMarkerSize(1.5);
        h1Params2[j][i][reportTypeId]->SetLineColor(col2);
      }
      for(int j=0; j<NofTelParams; j++){
        for(int ntel=0; ntel<kMaxTels; ntel++){
          sprintf( title, "h1%s_%s_Ebin%d_tel%d_%s", NameOfParamsTel[j].c_str(), runType1.c_str(), i, ntel+1, NameOfType[reportTypeId].c_str());
          h1ParamsPerTel1[j][i][ntel][reportTypeId] = (TH1F*)rfin1->Get( title );
          if( i == 0 ){
            sprintf( title, "h1%s_%s_tel%d_%s", NameOfParamsTel[j].c_str(), runType1.c_str(), ntel+1, NameOfType[reportTypeId].c_str());
            h1ParamsPerTelCombined1[j][ntel][reportTypeId] = (TH1F*)h1ParamsPerTel1[j][i][ntel][reportTypeId]->Clone(title);
          } else {
            h1ParamsPerTelCombined1[j][ntel][reportTypeId]->Add( h1ParamsPerTel1[j][i][ntel][reportTypeId], 1 );
          }
          h1ParamsPerTelCombined1[j][ntel][reportTypeId]->SetLineColor(kBlack);

          sprintf( title, "h1%s_%s_Ebin%d_tel%d_%s", NameOfParamsTel[j].c_str(), runType2.c_str(), i, ntel+1, NameOfType[reportTypeId].c_str());
          h1ParamsPerTel2[j][i][ntel][reportTypeId] = (TH1F*)rfin2->Get( title );
          if( i == 0 ){
            sprintf( title, "h1%s_%s_tel%d_%s", NameOfParamsTel[j].c_str(), runType1.c_str(), ntel+1, NameOfType[reportTypeId].c_str());
            h1ParamsPerTelCombined2[j][ntel][reportTypeId] = (TH1F*)h1ParamsPerTel2[j][i][ntel][reportTypeId]->Clone(title);
          } else {
            h1ParamsPerTelCombined2[j][ntel][reportTypeId]->Add( h1ParamsPerTel2[j][i][ntel][reportTypeId], 1 );
          }
          h1ParamsPerTelCombined2[j][ntel][reportTypeId]->SetMarkerStyle(25);
          h1ParamsPerTelCombined2[j][ntel][reportTypeId]->SetMarkerColor(col2);
          h1ParamsPerTelCombined2[j][ntel][reportTypeId]->SetMarkerSize(1.5);
          h1ParamsPerTelCombined2[j][ntel][reportTypeId]->SetLineColor(col2);
        }
      }
    }

    double norm1, norm2;
    double value;
    for(int i=0; i<NofEbins; i++){
      for(int j=0; j<NofShowerParams; j++){
        norm1 = 0; norm2 = 0;
        for(int n=1; n<=h1Params1[j][i][reportTypeId]->GetNbinsX(); n++)
          norm1 += h1Params1[j][i][reportTypeId]-> GetBinContent(n);

        for(int n=1; n<=h1Params1[j][i][reportTypeId]->GetNbinsX(); n++){
          if( norm1 > 0 ){
            h1Params1[j][i][reportTypeId]->SetBinContent(n, h1Params1[j][i][reportTypeId]->GetBinContent(n)/(norm1));
            if( h1Params1[j][i][reportTypeId]->GetBinError(n)/(norm1) > 1e-4 )
              h1Params1[j][i][reportTypeId]->SetBinError(n, h1Params1[j][i][reportTypeId]->GetBinError(n)/(norm1));
          }
        }

        for(int n=1; n<=h1Params2[j][i][reportTypeId]->GetNbinsX(); n++)
          norm2 += h1Params2[j][i][reportTypeId]-> GetBinContent(n);

        for(int n=1; n<=h1Params2[j][i][reportTypeId]->GetNbinsX(); n++){
          double value = h1Params2[j][i][reportTypeId]->GetBinError(n) ;
          if( norm2 > 0 ) {
            h1Params2[j][i][reportTypeId]->SetBinContent(n, h1Params2[j][i][reportTypeId]->GetBinContent(n)/(norm2));
            if( value == value && h1Params2[j][i][reportTypeId]->GetBinContent(n)/(norm2) > 0  ){
//              cout <<NameOfParams[j] <<" " << n <<" " <<norm2 <<" " << value <<" " << h1Params2[j][i][reportTypeId]->GetBinContent(n) <<" " << h1Params2[j][i][reportTypeId]->GetBinContent(n)/(norm2) <<" " <<  value/norm2 <<endl; 
              h1Params2[j][i][reportTypeId]->SetBinError(n, value/(norm2));
            }
          }
        }
      }
    }

    for(int j=0; j<NofTelParams; j++){
      for(int ntel=0; ntel<kMaxTels; ntel ++){
        norm1 = 0; norm2 = 0;
        for(int n=1; n<=h1ParamsPerTelCombined1[j][ntel][reportTypeId]->GetNbinsX(); n++)
          norm1 += h1ParamsPerTelCombined1[j][ntel][reportTypeId]->GetBinContent(n);

        for(int n=1; n<h1ParamsPerTelCombined1[j][ntel][reportTypeId]->GetNbinsX(); n++){
          if( norm1 > 0 ){
          h1ParamsPerTelCombined1[j][ntel][reportTypeId]
            ->SetBinContent(n, h1ParamsPerTelCombined1[j][ntel][reportTypeId]->GetBinContent(n)/(norm1));
          if( h1ParamsPerTelCombined1[j][ntel][reportTypeId]->GetBinError(n)/(norm1) > 1e-4 ){
            if( NameOfParamsTel[j].compare("Size")==0 )
              cout << n <<" "<< h1ParamsPerTelCombined1[j][ntel][reportTypeId]->GetBinError(n) <<" " << h1ParamsPerTelCombined1[j][ntel][reportTypeId]->GetBinError(n)/(norm1) <<endl; 
            h1ParamsPerTelCombined1[j][ntel][reportTypeId]
            ->SetBinError(n, h1ParamsPerTelCombined1[j][ntel][reportTypeId]->GetBinError(n)/(norm1));
            }
          }
        }

        for(int n=1; n<=h1ParamsPerTelCombined2[j][ntel][reportTypeId]->GetNbinsX(); n++)
          norm2 += h1ParamsPerTelCombined2[j][ntel][reportTypeId]->GetBinContent(n);

        for(int n=1; n<h1ParamsPerTelCombined2[j][ntel][reportTypeId]->GetNbinsX(); n++){
          if(norm2 > 0 ){
          h1ParamsPerTelCombined2[j][ntel][reportTypeId]
            ->SetBinContent(n, h1ParamsPerTelCombined2[j][ntel][reportTypeId]->GetBinContent(n)/(norm2));
//          cout << NameOfParamsTel[j] <<" " << n <<" " <<norm2 <<" " << h1ParamsPerTelCombined2[j][ntel][reportTypeId]->GetBinError(n) <<" " << h1ParamsPerTelCombined2[j][ntel][reportTypeId]->GetBinError(n)/(norm2) <<endl; 
          if( h1ParamsPerTelCombined2[j][ntel][reportTypeId]->GetBinError(n)/(norm2) > 1 )
            h1ParamsPerTelCombined2[j][ntel][reportTypeId]
            ->SetBinError(n, h1ParamsPerTelCombined2[j][ntel][reportTypeId]->GetBinError(n)/(norm2));
          }
        }
      }
    }

    TCanvas *canSP[NofShowerParams];
    for(int i=0; i<NofShowerParams; i++){
      sprintf( title, "can_%s", NameOfParams[i].c_str());
      canSP[i] = new TCanvas( title, title, 0, 0, 1200, 800);
      canSP[i]->SetFillColor(10);
      canSP[i]->Divide(3,2);
      for(int j=0; j<NofEbins; j++){
        canSP[i]->cd(j+1);
        gPad->SetGrid();
        h1Params1[i][j][reportTypeId]->Draw("p");
        if( NameOfParams[i].compare("MRSW") == 0 || NameOfParams[i].compare("MRSL") == 0  ){
          h1Params1[i][j][reportTypeId]->GetYaxis()->SetRangeUser(0, 0.2);
        } 
        if( NameOfParams[i].compare("MSW") == 0 || NameOfParams[i].compare("MSL") == 0 ){
          h1Params1[i][j][reportTypeId]->GetYaxis()->SetRangeUser(0, 0.2);
          h1Params1[i][j][reportTypeId]->GetXaxis()->SetRangeUser(0.6, 1.6); 
        }
        h1Params2[i][j][reportTypeId]->Draw("psames");
      }
      canSP[i]->cd();
      if (i == 0) {
	      canSP[i]->Print((printfilename + "(").c_str(), "pdf");
      } else {
  	    canSP[i]->Print( printfilename.c_str(), "pdf");
      }
    }

    TCanvas *canHP[kMaxTels];
    for(int ntel = 0; ntel<kMaxTels; ntel++){
      sprintf( title, "canHP_Tel%d", ntel+1);
      canHP[ntel] = new TCanvas( title, title, 0, 0, 1200, 800);
      if( ntel == 0 && printfilename.size() > 0 ){ 
        canHP[ntel]->Print( (printfilename + "(").c_str(), "pdf");
      }
      canHP[ntel]->SetFillColor(10);
      canHP[ntel]->Divide(5,3);
      for(int i=0; i<NofTelParams; i++){
        canHP[ntel]->cd(i+1);
        if( NameOfParamsTel[i].compare("SizeFracLo") == 0 ||
            NameOfParamsTel[i].compare("Size") == 0 ||
            NameOfParamsTel[i].compare("NTube") == 0 ||
            NameOfParamsTel[i].compare("Max3") == 0 ){
          gPad->SetLogy();
        } 
        h1ParamsPerTelCombined1[i][ntel][reportTypeId]->Draw("p");
        if( NameOfParamsTel[i].compare("ImpactDist") == 0 ||
            NameOfParamsTel[i].compare("Length") == 0   
          ){
          h1ParamsPerTelCombined1[i][ntel][reportTypeId]->GetYaxis()->SetRangeUser(yaxis_min, yaxis_max/2);
        }
        if( NameOfParamsTel[i].compare("Width") == 0){
          h1ParamsPerTelCombined1[i][ntel][reportTypeId]->GetYaxis()->SetRangeUser(yaxis_min, yaxis_max);
        }
        h1ParamsPerTelCombined2[i][ntel][reportTypeId]->Draw("psames");
      }
      canHP[ntel]->cd();
      canHP[ntel]->Print( printfilename.c_str(), "pdf");
    }
    canHP[0]->Print( (printfilename + ")").c_str(), "pdf");
}

void overlayParamPlots_report(string paramFilename1, bool isData1, string paramFilename2, bool isData2, string paramToPlot, int rebin=1, double yaxis_min=1e-2, double yaxis_max=10, string printfilename="", Short_t col2=kRed, bool doNormalizedArea=true)
{
    cout <<"file1 (black) : " << paramFilename1 <<endl;
    cout <<"file2 ("<< col2 <<"): "<< paramFilename2 <<endl;

    TFile *rfin1 = new TFile( paramFilename1.c_str(), "read");
    TFile *rfin2 = new TFile( paramFilename2.c_str(), "read");

    //plot single parameters
    char title[200];

    string runType1, runType2;
    if( isData1 ) runType1="Data";
    else runType1="Sim";
    if( isData2 ) runType2="Data";
    else runType2="Sim";

    int reportTypeId=2;
    bool showerParameter = false;
    int paramIdToPlot = -9;
 
    for(int i=0; i<NofShowerParams; i++){
      if( paramToPlot.compare( NameOfParams[i]) == 0 ){
        showerParameter = true;
        paramIdToPlot = i;
        for(int j=0; j<NofEbins; j++){
          sprintf( title, "h1%s_%s_Ebin%d_%s", NameOfParams[i].c_str(), runType1.c_str(), j, NameOfType[reportTypeId].c_str());
          h1Params1[i][j][reportTypeId] = (TH1F*)rfin1->Get( title );
          h1Params1[i][j][reportTypeId]->SetLineColor(kBlack);
          h1Params1[i][j][reportTypeId]->SetMarkerSize(1.5);
          sprintf( title, "h1AC%s_%s_Ebin%d_%s", NameOfParams[i].c_str(), runType1.c_str(), j, NameOfType[reportTypeId].c_str());
          h1ParamsAccumulated1[i][j][reportTypeId] = (TH1F*)h1Params1[i][j][reportTypeId]->Clone( title );
          h1ParamsAccumulated1[i][j][reportTypeId]->Reset();
          sprintf( title, "h1ACDiff%s_Ebin%d_%s", NameOfParams[i].c_str(), j, NameOfType[reportTypeId].c_str());
          h1ParamsAccumulatedDiff[i][j][reportTypeId] = (TH1F*)h1Params1[i][j][reportTypeId]->Clone( title );
          h1ParamsAccumulatedDiff[i][j][reportTypeId]->Reset();

          sprintf( title, "h1%s_%s_Ebin%d_%s", NameOfParams[i].c_str(), runType2.c_str(), j, NameOfType[reportTypeId].c_str());
          h1Params2[i][j][reportTypeId] = (TH1F*)rfin2->Get( title );
          h1Params2[i][j][reportTypeId]->SetMarkerStyle(21);
          h1Params2[i][j][reportTypeId]->SetMarkerColor(col2);
          h1Params2[i][j][reportTypeId]->SetMarkerSize(1.5);
          h1Params2[i][j][reportTypeId]->SetLineColor(col2);
          sprintf( title, "h1AC%s_%s_Ebin%d_%s", NameOfParams[i].c_str(), runType1.c_str(), j, NameOfType[reportTypeId].c_str());
          h1ParamsAccumulated2[i][j][reportTypeId] = (TH1F*)h1Params2[i][j][reportTypeId]->Clone( title );
          h1ParamsAccumulated2[i][j][reportTypeId]->Reset();
          if( rebin > 1 ){
            h1Params1[i][j][reportTypeId]->Rebin( rebin ); 
            h1ParamsAccumulated1[i][j][reportTypeId]->Rebin( rebin ); 
            h1ParamsAccumulatedDiff[i][j][reportTypeId]->Rebin( rebin ); 
            h1Params2[i][j][reportTypeId]->Rebin( rebin ); 
            h1ParamsAccumulated2[i][j][reportTypeId]->Rebin( rebin ); 
          }
        }
      }
    }

    if( !showerParameter ){
      for(int i=0; i<NofTelParams; i++){
        if( paramToPlot.compare(NameOfParamsTel[i]) == 0 ){
          paramIdToPlot = i;
          for(int j=0; j<NofEbins; j++){
            for(int ntel=0; ntel<kMaxTels; ntel++){
              sprintf( title, "h1%s_%s_Ebin%d_tel%d_%s", NameOfParamsTel[i].c_str(), runType1.c_str(), j, ntel+1, NameOfType[reportTypeId].c_str());
              h1ParamsPerTel1[i][j][ntel][reportTypeId] = (TH1F*)rfin1->Get( title );
              h1ParamsPerTel1[i][j][ntel][reportTypeId]->SetLineColor(kBlack);
              if( j == 0 ){
                sprintf( title, "h1%s_%s_tel%d_%s", NameOfParamsTel[i].c_str(), runType1.c_str(), ntel+1, NameOfType[reportTypeId].c_str());
                h1ParamsPerTelCombined1[i][ntel][reportTypeId] = (TH1F*)h1ParamsPerTel1[i][j][ntel][reportTypeId]->Clone(title);
              } else {
                h1ParamsPerTelCombined1[i][ntel][reportTypeId]->Add( h1ParamsPerTel1[i][j][ntel][reportTypeId], 1 );
              }
              sprintf( title, "h1%s_%s_Ebin%d_tel%d_%s", NameOfParamsTel[i].c_str(), runType2.c_str(), j, ntel+1, NameOfType[reportTypeId].c_str());
              h1ParamsPerTel2[i][j][ntel][reportTypeId] = (TH1F*)rfin2->Get( title );
              h1ParamsPerTel2[i][j][ntel][reportTypeId]->SetMarkerStyle(25);
              h1ParamsPerTel2[i][j][ntel][reportTypeId]->SetMarkerColor(col2);
              h1ParamsPerTel2[i][j][ntel][reportTypeId]->SetMarkerSize(1.5);
              h1ParamsPerTel2[i][j][ntel][reportTypeId]->SetLineColor(col2);
              if( j == 0 ){
                sprintf( title, "h1%s_%s_tel%d_%s", NameOfParamsTel[i].c_str(), runType2.c_str(), ntel+1, NameOfType[reportTypeId].c_str());
                h1ParamsPerTelCombined2[i][ntel][reportTypeId] = (TH1F*)h1ParamsPerTel2[i][j][ntel][reportTypeId]->Clone(title);
              } else {
                h1ParamsPerTelCombined2[i][ntel][reportTypeId]->Add( h1ParamsPerTel2[i][j][ntel][reportTypeId], 1 );
              }
              if( rebin > 1 ){
                h1ParamsPerTel1[i][j][ntel][reportTypeId]->Rebin( rebin );
                h1ParamsPerTel2[i][j][ntel][reportTypeId]->Rebin( rebin );
                if( j == 0 ){
                  h1ParamsPerTel1[i][j][ntel][reportTypeId]->Rebin( rebin );
                  h1ParamsPerTel2[i][j][ntel][reportTypeId]->Rebin( rebin );
                }
              }
            }
          }
        }
      }
    }
    if( paramIdToPlot == - 9 ){
      cout <<"couldn't find the parameter " << paramToPlot << endl;
      return ;
    }
 
    double norm1, norm2;
    double sum1, sum2;
    double value;
    int NbinRangeLower, NbinRangeUpper;
    for(int i=0; i<NofEbins; i++){
      norm1 = 0; norm2 = 0;
      if( showerParameter ){
        if( doNormalizedArea ){
          if( LowerV[paramIdToPlot] != -999 && UpperV[paramIdToPlot] != -999 ){
            NbinRangeLower = h1Params1[paramIdToPlot][i][reportTypeId]->FindBin(LowerV[paramIdToPlot]);
            NbinRangeUpper = h1Params1[paramIdToPlot][i][reportTypeId]->FindBin(UpperV[paramIdToPlot]);
          } else {
            NbinRangeLower = 1;
            NbinRangeUpper = h1Params1[paramIdToPlot][i][reportTypeId]->GetNbinsX();
          }
 
          for(int n=NbinRangeLower; n<=NbinRangeUpper; n++)
            norm1 += h1Params1[paramIdToPlot][i][reportTypeId]-> GetBinContent(n);

          if( LowerV[paramIdToPlot] == -999 ||  UpperV[paramIdToPlot] == -999 ){
            NbinRangeLower = 1;
            NbinRangeUpper = h1Params2[paramIdToPlot][i][reportTypeId]->GetNbinsX();
          }

          for(int n=NbinRangeLower; n<=NbinRangeUpper; n++)
            norm2 += h1Params2[paramIdToPlot][i][reportTypeId]-> GetBinContent(n);

        } else {
          norm1 = h1Params1[paramIdToPlot][i][reportTypeId]->GetMaximum();
          norm2 = h1Params2[paramIdToPlot][i][reportTypeId]->GetMaximum();
        }
        cout <<norm1 <<" " << norm2 <<endl;

        sum1 = 0;
        for(int n=1; n<=h1Params1[paramIdToPlot][i][reportTypeId]->GetNbinsX(); n++){
          if( norm1 > 0 ){
            h1Params1[paramIdToPlot][i][reportTypeId]->SetBinContent(n, h1Params1[paramIdToPlot][i][reportTypeId]->GetBinContent(n)/(norm1));
            if( h1Params1[paramIdToPlot][i][reportTypeId]->GetBinError(n)/(norm1) > 1e-4 )
              h1Params1[paramIdToPlot][i][reportTypeId]->SetBinError(n, h1Params1[paramIdToPlot][i][reportTypeId]->GetBinError(n)/(norm1));
            if(LowerV[paramIdToPlot] != -999 && UpperV[paramIdToPlot] != -999 ) {
              sum1 += h1Params1[paramIdToPlot][i][reportTypeId]->GetBinContent(n);
              h1ParamsAccumulated1[paramIdToPlot][i][reportTypeId]->SetBinContent(n, sum1);
            }
          }
        }

        sum2 = 0;
        for(int n=1; n<=h1Params2[paramIdToPlot][i][reportTypeId]->GetNbinsX(); n++){
          if( norm2 > 0 ){
            h1Params2[paramIdToPlot][i][reportTypeId]->SetBinContent(n, h1Params2[paramIdToPlot][i][reportTypeId]->GetBinContent(n)/(norm2));
            if( h1Params2[paramIdToPlot][i][reportTypeId]->GetBinError(n)/(norm1)>1e-4 )
              h1Params2[paramIdToPlot][i][reportTypeId]->SetBinError(n, h1Params2[paramIdToPlot][i][reportTypeId]->GetBinError(n)/(norm2));
            if( LowerV[paramIdToPlot] != -999 && UpperV[paramIdToPlot] != -999 ) {
              sum2 += h1Params2[paramIdToPlot][i][reportTypeId]->GetBinContent(n);
              h1ParamsAccumulated2[paramIdToPlot][i][reportTypeId]->SetBinContent(n, sum2);
            }
          }
        }
        // accumulation curve difference
        for(int n=1; n<=h1ParamsAccumulated1[paramIdToPlot][i][reportTypeId]->GetNbinsX(); n++){
          if( TMath::Abs(h1ParamsAccumulated1[paramIdToPlot][i][reportTypeId]->GetBinCenter(n) - h1ParamsAccumulated2[paramIdToPlot][i][reportTypeId]->GetBinCenter(n)) < 1e-2 ){ 
            double val1 = h1ParamsAccumulated1[paramIdToPlot][i][reportTypeId]->GetBinContent(n);
            double val2 = h1ParamsAccumulated2[paramIdToPlot][i][reportTypeId]->GetBinContent(n);
            h1ParamsAccumulatedDiff[paramIdToPlot][i][reportTypeId]->SetBinContent(n, val1-val2);
          }
        }

      } else {
        for(int ntel=0; ntel<kMaxTels; ntel ++){
          norm1 = 0; 
          if( doNormalizedArea ){
            for(int n=1; n<=h1ParamsPerTel1[paramIdToPlot][i][ntel][reportTypeId]->GetNbinsX(); n++)
              norm1 += h1ParamsPerTel1[paramIdToPlot][i][ntel][reportTypeId]->GetBinContent(n);
          } else {
          }

          for(int n=1; n<h1ParamsPerTel1[paramIdToPlot][i][ntel][reportTypeId]->GetNbinsX(); n++){
            if( norm1 > 0 ){
            h1ParamsPerTel1[paramIdToPlot][i][ntel][reportTypeId]
              ->SetBinContent(n, h1ParamsPerTel1[paramIdToPlot][i][ntel][reportTypeId]->GetBinContent(n)/(norm1));
            if( h1ParamsPerTel1[paramIdToPlot][i][ntel][reportTypeId]->GetBinError(n)/(norm1) > 1e-4 ){
              h1ParamsPerTel1[paramIdToPlot][i][ntel][reportTypeId]
              ->SetBinError(n, h1ParamsPerTel1[paramIdToPlot][i][ntel][reportTypeId]->GetBinError(n)/(norm1));
              }
            }
          }

          if( i == 0 ){
            norm1 = 0;
            for(int n=1; n<=h1ParamsPerTelCombined1[paramIdToPlot][ntel][reportTypeId]->GetNbinsX(); n++)
              norm1 += h1ParamsPerTelCombined1[paramIdToPlot][ntel][reportTypeId]->GetBinContent(n);

            for(int n=1; n<h1ParamsPerTelCombined1[paramIdToPlot][ntel][reportTypeId]->GetNbinsX(); n++){
              if( norm1 > 0 ){
              h1ParamsPerTelCombined1[paramIdToPlot][ntel][reportTypeId]
                ->SetBinContent(n, h1ParamsPerTelCombined1[paramIdToPlot][ntel][reportTypeId]->GetBinContent(n)/(norm1));
              if( h1ParamsPerTelCombined1[paramIdToPlot][ntel][reportTypeId]->GetBinError(n)/(norm1) > 1e-4 ){
                h1ParamsPerTelCombined1[paramIdToPlot][ntel][reportTypeId]
                ->SetBinError(n, h1ParamsPerTelCombined1[paramIdToPlot][ntel][reportTypeId]->GetBinError(n)/(norm1));
                }
              }
            }
            norm2 = 0;
            for(int n=1; n<=h1ParamsPerTelCombined2[paramIdToPlot][ntel][reportTypeId]->GetNbinsX(); n++)
              norm2 += h1ParamsPerTelCombined2[paramIdToPlot][ntel][reportTypeId]->GetBinContent(n);

            for(int n=1; n<h1ParamsPerTelCombined2[paramIdToPlot][ntel][reportTypeId]->GetNbinsX(); n++){
              if( norm2 > 0 ){
              h1ParamsPerTelCombined2[paramIdToPlot][ntel][reportTypeId]
                ->SetBinContent(n, h1ParamsPerTelCombined2[paramIdToPlot][ntel][reportTypeId]->GetBinContent(n)/(norm2));
              if( h1ParamsPerTelCombined2[paramIdToPlot][ntel][reportTypeId]->GetBinError(n)/(norm2) > 1e-4 ){
                h1ParamsPerTelCombined2[paramIdToPlot][ntel][reportTypeId]
                ->SetBinError(n, h1ParamsPerTelCombined2[paramIdToPlot][ntel][reportTypeId]->GetBinError(n)/(norm2));
                }
              }
            }
          }
          norm2 = 0;
          if( doNormalizedArea ){
            for(int n=1; n<=h1ParamsPerTel2[paramIdToPlot][i][ntel][reportTypeId]->GetNbinsX(); n++)
              norm2 += h1ParamsPerTel2[paramIdToPlot][i][ntel][reportTypeId]->GetBinContent(n);
          } else {
            norm2 = h1ParamsPerTel2[paramIdToPlot][i][ntel][reportTypeId]->GetMaximum();
          }

          for(int n=1; n<h1ParamsPerTel2[paramIdToPlot][i][ntel][reportTypeId]->GetNbinsX(); n++){
            if(norm2 > 0 ){
            h1ParamsPerTel2[paramIdToPlot][i][ntel][reportTypeId]
              ->SetBinContent(n, h1ParamsPerTel2[paramIdToPlot][i][ntel][reportTypeId]->GetBinContent(n)/(norm2));
            if( h1ParamsPerTel2[paramIdToPlot][i][ntel][reportTypeId]->GetBinError(n)/(norm2) > 1 )
              h1ParamsPerTel2[paramIdToPlot][i][ntel][reportTypeId]
              ->SetBinError(n, h1ParamsPerTel2[paramIdToPlot][i][ntel][reportTypeId]->GetBinError(n)/(norm2));
            }
          }
        }
      }
    }

    TCanvas *can[kMaxTels];
    TCanvas *canResFrac[kMaxTels];
    TCanvas *canAccumulated[kMaxTels];
    TBox *box = new TBox();
    box->SetFillColor(col2);
    box->SetFillStyle(3002);
    TLine *line1 = new TLine();
    line1->SetLineColor(kBlue);
    line1->SetLineWidth(1);
    line1->SetLineStyle(2);

    TGaxis *axisAccumulated[NofEbins];
    int maxVBin;
    Float_t rightmax;
    Float_t scale;

    if( showerParameter ) {
      can[0] = new TCanvas("can0","can0", 1200, 800);
      if( printfilename.size() > 0 ){
        can[0]->Print( (printfilename + "[").c_str(), "pdf");
      }
      can[0]->SetFillColor(10);
      can[0]->Divide(3,2);
      canResFrac[0] = new TCanvas("canResFrac0","canResFrac0", 1200, 800);
      canResFrac[0]->SetFillColor(10);
      canResFrac[0]->Divide(3,2);
      if( LowerV[paramIdToPlot] != -999 && UpperV[paramIdToPlot] != -999 ){
        canAccumulated[0] = new TCanvas("canAccumulated0","canAccumulated0", 1200, 800);
        canAccumulated[0]->SetFillColor(10);
        canAccumulated[0]->Divide(3,2);
      }

      for(int i=0; i<NofEbins; i++){
        can[0]->cd(i+1);
        gPad->SetGrid();
        sprintf( title, "%s, E%.1fTeV-E%.1fTeV", NameOfParams[paramIdToPlot].c_str(), EbinLow_GeV[i]*1e-3, EbinUp_GeV[i]*1e-3);
        h1Params1[paramIdToPlot][i][reportTypeId]->SetTitle( title );
        h1Params1[paramIdToPlot][i][reportTypeId]->Draw("p");
        h1Params1[paramIdToPlot][i][reportTypeId]->GetYaxis()->SetRangeUser(yaxis_min, yaxis_max);
        if( LowerV[paramIdToPlot] != -999 && UpperV[paramIdToPlot] != -999 ) 
          h1Params1[paramIdToPlot][i][reportTypeId]->GetXaxis()->SetRangeUser(LowerV[paramIdToPlot], UpperV[paramIdToPlot]);
        h1Params2[paramIdToPlot][i][reportTypeId]->Draw("psames");

        canResFrac[0]->cd(i+1);
        gPad->SetGrid();
        gPad->SetTickx(1);
        gPad->SetTicky(1);
        sprintf( title, "h1%s_%s_Ebin%d_%s_ResFrac",
                 NameOfParams[paramIdToPlot].c_str(), runType1.c_str(), i, NameOfType[reportTypeId].c_str() );
        TH1F *tmp = (TH1F*)h1Params1[paramIdToPlot][i][reportTypeId]->Clone( title );
        tmp->Add( h1Params1[paramIdToPlot][i][reportTypeId], h1Params2[paramIdToPlot][i][reportTypeId], -1, 1 );
        tmp->Divide( h1Params1[paramIdToPlot][i][reportTypeId] );
        sprintf( title, "%s (%s-%s)/%s, E%.1fTeV ~ E%.1fTeV",
                 NameOfParams[paramIdToPlot].c_str(), runType2.c_str(), runType1.c_str(), runType1.c_str(), EbinLow_GeV[i]*1e-3, EbinUp_GeV[i]*1e-3);
        tmp->SetTitle( title );
        tmp->Draw("p");
        tmp->GetYaxis()->SetRangeUser(-2,2);
        maxVBin = h1Params1[paramIdToPlot][i][reportTypeId]->GetMaximumBin();
        box->DrawBox( tmp->GetBinCenter(maxVBin-3), -1, tmp->GetBinCenter(maxVBin+3) , 1);
        gPad->Modified();
        gPad->Update();

        if( LowerV[paramIdToPlot] != -999 && UpperV[paramIdToPlot] != -999 ){  
          canAccumulated[0]->cd(i+1);
          gPad->SetGrid();
          //gPad->SetTickx(1);
          //gPad->SetTicky(1);

          sprintf( title, "%s, E%.1fTeV-E%.1fTeV", NameOfParams[paramIdToPlot].c_str(), EbinLow_GeV[i]*1e-3, EbinUp_GeV[i]*1e-3);
          h1ParamsAccumulated1[paramIdToPlot][i][reportTypeId]->SetTitle( title );
          h1ParamsAccumulated1[paramIdToPlot][i][reportTypeId]->SetStats(kFALSE);
          h1ParamsAccumulated1[paramIdToPlot][i][reportTypeId]->Draw("l");
          h1ParamsAccumulated1[paramIdToPlot][i][reportTypeId]->GetXaxis()->SetRangeUser( LowerV[paramIdToPlot], UpperV[paramIdToPlot]);
          h1ParamsAccumulated1[paramIdToPlot][i][reportTypeId]->GetYaxis()->SetRangeUser( 0, 1.1); 
          gPad->Modified();
          gPad->Update();
          h1ParamsAccumulated2[paramIdToPlot][i][reportTypeId]->Draw("lsame");
          gPad->Modified();
          gPad->Update();

          //rightmax = 1.1*h1ParamsAccumulatedDiff[paramIdToPlot][i][reportTypeId]->GetMaximum();
//          scale = gPad->GetUymax()*0.6;
          h1ParamsAccumulatedDiff[paramIdToPlot][i][reportTypeId]->SetLineColor(kBlue);
          h1ParamsAccumulatedDiff[paramIdToPlot][i][reportTypeId]->SetLineWidth(2);
          for(int nn=1; nn<=h1ParamsAccumulatedDiff[paramIdToPlot][i][reportTypeId]->GetNbinsX(); nn++){
            double val = h1ParamsAccumulatedDiff[paramIdToPlot][i][reportTypeId]->GetBinContent(nn);
            scale = val*gPad->GetUymax()/0.4 + gPad->GetUymax()/2.0;
            h1ParamsAccumulatedDiff[paramIdToPlot][i][reportTypeId]->SetBinContent( nn, scale); 
          }
          h1ParamsAccumulatedDiff[paramIdToPlot][i][reportTypeId]->Draw("same");
          line1->DrawLine( gPad->GetUxmin(), gPad->GetUymax()/2.0, gPad->GetUxmax(), gPad->GetUymax()/2.0);
//          gPad->Modified();
//          gPad->Update();
        
          axisAccumulated[i] = new TGaxis(gPad->GetUxmax(),gPad->GetUymin(), gPad->GetUxmax(), gPad->GetUymax(), -0.2, 0.2, 510,"+L");
          axisAccumulated[i]->SetLineColor(kBlue);
          axisAccumulated[i]->SetLabelColor(kBlue);
          axisAccumulated[i]->Draw();
        }  
      }
      if( printfilename.size() > 0 ){
        can[0]->Print( printfilename.c_str(), "pdf");
        canResFrac[0]->Print( printfilename.c_str(), "pdf");
        if( LowerV[paramIdToPlot] != -999 && UpperV[paramIdToPlot] != -999 ){  
          canAccumulated[0]->Print( printfilename.c_str(), "pdf");
          canAccumulated[0]->Print( (printfilename + "]").c_str(), "pdf");
        } else {
          canResFrac[0]->Print( (printfilename + "]").c_str(), "pdf");
        }
      }
    } else {
      for(int ntel=0; ntel<kMaxTels; ntel++){
        sprintf( title, "can%d", ntel+1);
        can[ntel] = new TCanvas( title, title, 0, 0, 1200, 800);
        can[ntel]->SetFillColor(10);
        can[ntel]->Divide(3,2);
        sprintf( title, "canResFrac%d", ntel+1);
        canResFrac[ntel] = new TCanvas( title, title, 0, 0, 1200, 800);
        canResFrac[ntel]->SetFillColor(10);
        canResFrac[ntel]->Divide(3,2);
        if( printfilename.size() > 0  && ntel == 0 ){
          can[ntel]->Print((printfilename + "[").c_str(), "pdf");
        }

        for(int i=0; i<NofEbins; i++){
          can[ntel]->cd(i+1);
          gPad->SetGrid();
          gPad->SetTickx(1);
          gPad->SetTicky(1);
          if( paramToPlot.compare("SizeFracLo") == 0 ||
              paramToPlot.compare("Size") == 0 ||
              paramToPlot.compare("NTube") == 0 ||
              paramToPlot.compare("Max3") == 0 ){
            h1ParamsPerTel1[paramIdToPlot][i][ntel][reportTypeId]->GetYaxis()->SetRangeUser(yaxis_min, yaxis_max);
            gPad->SetLogy();
          } 
          h1ParamsPerTel1[paramIdToPlot][i][ntel][reportTypeId]->Draw("p");
          if( paramToPlot.compare("ImpactDist") == 0 ||
              paramToPlot.compare("Width") == 0 ||
              paramToPlot.compare("Length") == 0   
            ){
            h1ParamsPerTel1[paramIdToPlot][i][ntel][reportTypeId]->GetYaxis()->SetRangeUser(yaxis_min, yaxis_max);
          }
          h1ParamsPerTel2[paramIdToPlot][i][ntel][reportTypeId]->Draw("psames");

          maxVBin = h1ParamsPerTel1[paramIdToPlot][i][ntel][reportTypeId]->GetMaximumBin();

          canResFrac[ntel]->cd(i+1);
          gPad->SetGrid();
          gPad->SetTickx(1);
          gPad->SetTicky(1);
          sprintf( title, "h1%s_%s_Ebin%d_tel%d_%s_ResFrac", 
                   NameOfParamsTel[paramIdToPlot].c_str(), runType1.c_str(), i, ntel+1, NameOfType[reportTypeId].c_str() );
          TH1F *tmp = (TH1F*)h1ParamsPerTel1[paramIdToPlot][i][ntel][reportTypeId]->Clone( title );
          tmp->Add( h1ParamsPerTel1[paramIdToPlot][i][ntel][reportTypeId], h1ParamsPerTel2[paramIdToPlot][i][ntel][reportTypeId], -1, 1 ); 
          tmp->Divide( h1ParamsPerTel1[paramIdToPlot][i][ntel][reportTypeId] );
          sprintf( title, "%s (%s-%s)/%s, Ebin%d Tel%d", 
                   NameOfParamsTel[paramIdToPlot].c_str(), runType2.c_str(), runType1.c_str(), runType1.c_str(), i, ntel+1 );
          tmp->SetTitle( title );
          tmp->Draw("p");
          tmp->GetYaxis()->SetRangeUser(-2,2);
          box->DrawBox( tmp->GetBinCenter(maxVBin-3), -1, tmp->GetBinCenter(maxVBin+3) , 1);
          gPad->Modified();
          gPad->Update();
        }
        if ( printfilename.size() > 0 ){
          can[ntel]->Print( printfilename.c_str(), "pdf");
          canResFrac[ntel]->Print( printfilename.c_str(), "pdf");
        }  
      }

      TCanvas *c2 = new TCanvas("c2","c2",800,800);
      c2->Divide(2,2);
      for(int ntel = 0; ntel<kMaxTels; ntel++){
        c2->cd(ntel+1);
        gPad->SetGrid();
        if( paramToPlot.compare("SizeFracLo") == 0 ||
            paramToPlot.compare("Size") == 0 ||
            paramToPlot.compare("NTube") == 0 ||
            paramToPlot.compare("Max3") == 0 ){
          h1ParamsPerTelCombined1[paramIdToPlot][ntel][reportTypeId]->GetYaxis()->SetRangeUser(yaxis_min, yaxis_max);
          gPad->Modified();
          gPad->SetLogy();
        }
        h1ParamsPerTelCombined1[paramIdToPlot][ntel][reportTypeId]->Draw("p");
        if( paramToPlot.compare("ImpactDist") == 0 ||
            paramToPlot.compare("Width") == 0 ||
            paramToPlot.compare("Length") == 0
          ){
          h1ParamsPerTelCombined1[paramIdToPlot][ntel][reportTypeId]->GetYaxis()->SetRangeUser(yaxis_min, yaxis_max);
        }
         h1ParamsPerTelCombined2[paramIdToPlot][ntel][reportTypeId]->Draw("psames");    
      }
      c2->cd();
      if ( printfilename.size() > 0 ){
        c2->Print( printfilename.c_str(), "pdf" );
        c2->Print(  (printfilename + "]").c_str(), "pdf");
      }
    }

}

void overlayParamPlotsWBK_report(string paramFilename1, bool isData1, string paramFilename2, bool isData2, string paramToPlot, int rebin=1, double yaxis_min=1e-2, double yaxis_max=10, string printfilename="", bool doNormalizedArea=true, short col2=kRed)
{
    cout <<"file1 (black) : " << paramFilename1 <<endl;
    cout <<"file2 : "<< paramFilename2 <<endl;

    TFile *rfin1 = new TFile( paramFilename1.c_str(), "read");
    TFile *rfin2 = new TFile( paramFilename2.c_str(), "read");

    //plot single parameters
    char title[200];

    string runType1, runType2;
    if( isData1 ) runType1="Data";
    else runType1="Sim";
    if( isData2 ) runType2="Data";
    else runType2="Sim";

    if( runType1 != "Sim" && runType2 != "Data"){
       cout <<"This requires sim as file1 & data as file2!! "<<endl;
       return;
    }

    int reportTypeId=2;
    bool showerParameter = false;
    int paramIdToPlot = -9;
    Short_t color_pal[3] = {kMagenta, kCyan, kRed};
 
    for(int i=0; i<NofShowerParams; i++){
      if( paramToPlot.compare( NameOfParams[i]) == 0 ){
        showerParameter = true;
        paramIdToPlot = i;
        for(int j=0; j<NofEbins; j++){
          sprintf( title, "h1%s_%s_Ebin%d_%s", NameOfParams[i].c_str(), runType1.c_str(), j, NameOfType[reportTypeId].c_str());
          h1Params1[i][j][reportTypeId] = (TH1F*)rfin1->Get( title );
          h1Params1[i][j][reportTypeId]->SetLineColor(kBlack);
          h1Params1[i][j][reportTypeId]->SetMarkerSize(1.5);

          for(int k=0; k<3; k++){
            sprintf( title, "h1%s_%s_Ebin%d_%s", NameOfParams[i].c_str(), runType2.c_str(), j, NameOfType[k].c_str());
            h1Params2[i][j][k] = (TH1F*)rfin2->Get( title );
            h1Params2[i][j][k]->SetMarkerStyle(21);
            h1Params2[i][j][k]->SetMarkerColor(color_pal[k]);
            h1Params2[i][j][k]->SetMarkerSize(1.5);
            h1Params2[i][j][k]->SetLineColor(color_pal[k]);
            if( rebin > 1 ){
              h1Params2[i][j][k]->Rebin( rebin ); 
            }
          }
          if( rebin > 1 ){
          	for(int k=0; k<3; k++){
            	h1Params1[i][j][k]->Rebin( rebin ); 
          	}	
          }
        } //NofEbins
      }
    }

//now time to play with 
    if( !showerParameter ){
      for(int i=0; i<NofTelParams; i++){
        if( paramToPlot.compare(NameOfParamsTel[i]) == 0 ){
          paramIdToPlot = i;
          for(int j=0; j<NofEbins; j++){
            for(int ntel=0; ntel<kMaxTels; ntel++){
              for(int k=0; k<3; k++){
                if( k == reportTypeId ){
                  sprintf( title, "h1%s_%s_Ebin%d_tel%d_%s", NameOfParamsTel[i].c_str(), runType1.c_str(), j, ntel+1, NameOfType[reportTypeId].c_str());
                  h1ParamsPerTel1[i][j][ntel][reportTypeId] = (TH1F*)rfin1->Get( title );
                  h1ParamsPerTel1[i][j][ntel][reportTypeId]->SetLineColor(kBlack);
                  if( j == 0 ){
                    sprintf( title, "h1%s_%s_tel%d_%s", NameOfParamsTel[i].c_str(), runType1.c_str(), ntel+1, NameOfType[reportTypeId].c_str());
                    h1ParamsPerTelCombined1[i][ntel][reportTypeId] = (TH1F*)h1ParamsPerTel1[i][j][ntel][reportTypeId]->Clone(title);
                  } else {
                    h1ParamsPerTelCombined1[i][ntel][reportTypeId]->Add( h1ParamsPerTel1[i][j][ntel][reportTypeId], 1 );
                  }
                }
                sprintf( title, "h1%s_%s_Ebin%d_tel%d_%s", NameOfParamsTel[i].c_str(), runType2.c_str(), j, ntel+1, NameOfType[k].c_str());
                h1ParamsPerTel2[i][j][ntel][k] = (TH1F*)rfin2->Get( title );
                h1ParamsPerTel2[i][j][ntel][k]->SetMarkerStyle(25);
                h1ParamsPerTel2[i][j][ntel][k]->SetMarkerColor(col2);
                h1ParamsPerTel2[i][j][ntel][k]->SetMarkerSize(1.5);
                h1ParamsPerTel2[i][j][ntel][k]->SetLineColor(col2);
                if( j == 0 && k == 0 ){
                  sprintf( title, "h1%s_%s_tel%d_%s", NameOfParamsTel[i].c_str(), runType2.c_str(), ntel+1, NameOfType[k].c_str());
                  h1ParamsPerTelCombined2[i][ntel][k] = (TH1F*)h1ParamsPerTel2[i][j][ntel][k]->Clone(title);
                } else {
                  h1ParamsPerTelCombined2[i][ntel][k]->Add( h1ParamsPerTel2[i][j][ntel][k], 1 );
                }
              }
              if( rebin > 1 ){
                h1ParamsPerTel1[i][j][ntel][reportTypeId]->Rebin( rebin );
                for(int k=0; k<3; k++)
                  h1ParamsPerTel2[i][j][ntel][k]->Rebin( rebin );
                if( j == 0 ){
                  h1ParamsPerTel1[i][j][ntel][reportTypeId]->Rebin( rebin );
                  for(int k=0; k<3; k++)
                    h1ParamsPerTel2[i][j][ntel][k]->Rebin( rebin );
                }
              }
            } //ntel
          }//NofEbin
        }
      }
    }
    if( paramIdToPlot == - 9 ){
      cout <<"couldn't find the parameter " << paramToPlot << endl;
      return ;
    }
 
    double norm1, norm2;
    double sum1, sum2;
    double value;
    int NbinRangeLower, NbinRangeUpper;
    for(int i=0; i<NofEbins; i++){
      norm1 = 0; norm2 = 0;
      if( showerParameter ){
        if( doNormalizedArea ){
          if( LowerV[paramIdToPlot] != -999 && UpperV[paramIdToPlot] != -999 ){
            NbinRangeLower = h1Params1[paramIdToPlot][i][reportTypeId]->FindBin(LowerV[paramIdToPlot]);
            NbinRangeUpper = h1Params1[paramIdToPlot][i][reportTypeId]->FindBin(UpperV[paramIdToPlot]);
          } else {
            NbinRangeLower = 1;
            NbinRangeUpper = h1Params1[paramIdToPlot][i][reportTypeId]->GetNbinsX();
          }
 
          for(int n=NbinRangeLower; n<=NbinRangeUpper; n++)
            norm1 += h1Params1[paramIdToPlot][i][reportTypeId]-> GetBinContent(n);

          if( LowerV[paramIdToPlot] == -999 ||  UpperV[paramIdToPlot] == -999 ){
            NbinRangeLower = 1;
            NbinRangeUpper = h1Params2[paramIdToPlot][i][reportTypeId]->GetNbinsX();
          }

          for(int n=NbinRangeLower; n<=NbinRangeUpper; n++)
            norm2 += h1Params2[paramIdToPlot][i][reportTypeId]-> GetBinContent(n);

        } else {
          norm1 = h1Params1[paramIdToPlot][i][reportTypeId]->GetMaximum();
          norm2 = h1Params2[paramIdToPlot][i][reportTypeId]->GetMaximum();
        }
        cout <<norm1 <<" " << norm2 <<endl;

        for(int n=1; n<=h1Params1[paramIdToPlot][i][reportTypeId]->GetNbinsX(); n++){
          if( norm1 > 0 ){
            h1Params1[paramIdToPlot][i][reportTypeId]->SetBinContent(n, h1Params1[paramIdToPlot][i][reportTypeId]->GetBinContent(n)/(norm1));
            if( h1Params1[paramIdToPlot][i][reportTypeId]->GetBinError(n)/(norm1) > 1e-4 )
              h1Params1[paramIdToPlot][i][reportTypeId]->SetBinError(n, h1Params1[paramIdToPlot][i][reportTypeId]->GetBinError(n)/(norm1));
          }
        }

        for(int k=0; k<3; k++){
          for(int n=1; n<=h1Params2[paramIdToPlot][i][k]->GetNbinsX(); n++){
            if( norm2 > 0 ){
              h1Params2[paramIdToPlot][i][k]->SetBinContent(n, h1Params2[paramIdToPlot][i][k]->GetBinContent(n)/(norm2));
              if( h1Params2[paramIdToPlot][i][k]->GetBinError(n)/(norm1)>1e-4 )
                h1Params2[paramIdToPlot][i][k]->SetBinError(n, h1Params2[paramIdToPlot][i][k]->GetBinError(n)/(norm2));
            }
          }
        }

      } else {
        for(int ntel=0; ntel<kMaxTels; ntel ++){
          norm1 = 0; 
          if( doNormalizedArea ){
            for(int n=1; n<=h1ParamsPerTel1[paramIdToPlot][i][ntel][reportTypeId]->GetNbinsX(); n++)
              norm1 += h1ParamsPerTel1[paramIdToPlot][i][ntel][reportTypeId]->GetBinContent(n);
          } else {
          }

          for(int n=1; n<h1ParamsPerTel1[paramIdToPlot][i][ntel][reportTypeId]->GetNbinsX(); n++){
            if( norm1 > 0 ){
            h1ParamsPerTel1[paramIdToPlot][i][ntel][reportTypeId]
              ->SetBinContent(n, h1ParamsPerTel1[paramIdToPlot][i][ntel][reportTypeId]->GetBinContent(n)/(norm1));
            if( h1ParamsPerTel1[paramIdToPlot][i][ntel][reportTypeId]->GetBinError(n)/(norm1) > 1e-4 ){
              h1ParamsPerTel1[paramIdToPlot][i][ntel][reportTypeId]
              ->SetBinError(n, h1ParamsPerTel1[paramIdToPlot][i][ntel][reportTypeId]->GetBinError(n)/(norm1));
              }
            }
          }

          if( i == 0 ){
            norm1 = 0;
            for(int n=1; n<=h1ParamsPerTelCombined1[paramIdToPlot][ntel][reportTypeId]->GetNbinsX(); n++)
              norm1 += h1ParamsPerTelCombined1[paramIdToPlot][ntel][reportTypeId]->GetBinContent(n);

            for(int n=1; n<h1ParamsPerTelCombined1[paramIdToPlot][ntel][reportTypeId]->GetNbinsX(); n++){
              if( norm1 > 0 ){
              h1ParamsPerTelCombined1[paramIdToPlot][ntel][reportTypeId]
                ->SetBinContent(n, h1ParamsPerTelCombined1[paramIdToPlot][ntel][reportTypeId]->GetBinContent(n)/(norm1));
              if( h1ParamsPerTelCombined1[paramIdToPlot][ntel][reportTypeId]->GetBinError(n)/(norm1) > 1e-4 ){
                h1ParamsPerTelCombined1[paramIdToPlot][ntel][reportTypeId]
                ->SetBinError(n, h1ParamsPerTelCombined1[paramIdToPlot][ntel][reportTypeId]->GetBinError(n)/(norm1));
                }
              }
            }
            norm2 = 0;
            for(int n=1; n<=h1ParamsPerTelCombined2[paramIdToPlot][ntel][reportTypeId]->GetNbinsX(); n++)
              norm2 += h1ParamsPerTelCombined2[paramIdToPlot][ntel][reportTypeId]->GetBinContent(n);
         
            for(int k=0; k<3; k++){
              for(int n=1; n<h1ParamsPerTelCombined2[paramIdToPlot][ntel][k]->GetNbinsX(); n++){
                if( norm2 > 0 ){
                h1ParamsPerTelCombined2[paramIdToPlot][ntel][k]
                  ->SetBinContent(n, h1ParamsPerTelCombined2[paramIdToPlot][ntel][k]->GetBinContent(n)/(norm2));
                  if( h1ParamsPerTelCombined2[paramIdToPlot][ntel][k]->GetBinError(n)/(norm2) > 1e-4 ){
                    h1ParamsPerTelCombined2[paramIdToPlot][ntel][k]
                    ->SetBinError(n, h1ParamsPerTelCombined2[paramIdToPlot][ntel][k]->GetBinError(n)/(norm2));
                  }
                }
              }
            }
          }
          norm2 = 0;
          if( doNormalizedArea ){
            for(int n=1; n<=h1ParamsPerTel2[paramIdToPlot][i][ntel][reportTypeId]->GetNbinsX(); n++)
              norm2 += h1ParamsPerTel2[paramIdToPlot][i][ntel][reportTypeId]->GetBinContent(n);
          } else {
            norm2 = h1ParamsPerTel2[paramIdToPlot][i][ntel][reportTypeId]->GetMaximum();
          }
          for(int k=0; k<3; k++){
            for(int n=1; n<h1ParamsPerTel2[paramIdToPlot][i][ntel][k]->GetNbinsX(); n++){
              if(norm2 > 0 ){
              h1ParamsPerTel2[paramIdToPlot][i][ntel][k]
                ->SetBinContent(n, h1ParamsPerTel2[paramIdToPlot][i][ntel][k]->GetBinContent(n)/(norm2));
              if( h1ParamsPerTel2[paramIdToPlot][i][ntel][k]->GetBinError(n)/(norm2) > 1 )
                h1ParamsPerTel2[paramIdToPlot][i][ntel][k]
                ->SetBinError(n, h1ParamsPerTel2[paramIdToPlot][i][ntel][k]->GetBinError(n)/(norm2));
              }
            }
          }
        }
      }
    }

  TCanvas *can[kMaxTels];
  TBox *box = new TBox();
  box->SetFillColor(kRed);
  box->SetFillStyle(3002);
  TLine *line1 = new TLine();
  line1->SetLineColor(kBlue);
  line1->SetLineWidth(1);
  line1->SetLineStyle(2);

  int maxVBin;
  Float_t rightmax;
  Float_t scale;

  if( showerParameter ) {
    can[0] = new TCanvas("can0","can0", 1200, 800);
    if( printfilename.size() > 0 ){
      can[0]->Print( (printfilename + "[").c_str(), "pdf");
    }
    can[0]->SetFillColor(10);
    can[0]->Divide(3,2);

    for(int i=0; i<NofEbins; i++){
      can[0]->cd(i+1);
      gPad->SetGrid();
      sprintf( title, "%s, E%.1fTeV-E%.1fTeV", NameOfParams[paramIdToPlot].c_str(), EbinLow_GeV[i]*1e-3, EbinUp_GeV[i]*1e-3);
      h1Params1[paramIdToPlot][i][reportTypeId]->SetTitle( title );
      h1Params1[paramIdToPlot][i][reportTypeId]->Draw("p");
      h1Params1[paramIdToPlot][i][reportTypeId]->GetYaxis()->SetRangeUser(yaxis_min, yaxis_max);
      if( LowerV[paramIdToPlot] != -999 && UpperV[paramIdToPlot] != -999 ) 
        h1Params1[paramIdToPlot][i][reportTypeId]->GetXaxis()->SetRangeUser(LowerV[paramIdToPlot], UpperV[paramIdToPlot]);
      for(int k=0; k<3; k++)
        h1Params2[paramIdToPlot][i][k]->Draw("psames");
    }  
    if( printfilename.size() > 0 )
      can[0]->Print( printfilename.c_str(), "pdf");
    
  } else {
    for(int ntel=0; ntel<kMaxTels; ntel++){
      sprintf( title, "can%d", ntel+1);
      can[ntel] = new TCanvas( title, title, 0, 0, 1200, 800);
      can[ntel]->SetFillColor(10);
      can[ntel]->Divide(3,2);
      if( printfilename.size() > 0  && ntel == 0 )
        can[ntel]->Print((printfilename + "[").c_str(), "pdf");

      for(int i=0; i<NofEbins; i++){
        can[ntel]->cd(i+1);
        gPad->SetGrid();
        gPad->SetTickx(1);
        gPad->SetTicky(1);
        if( paramToPlot.compare("SizeFracLo") == 0 ||
            paramToPlot.compare("Size") == 0 ||
            paramToPlot.compare("NTube") == 0 ||
            paramToPlot.compare("Max3") == 0 ){
          h1ParamsPerTel1[paramIdToPlot][i][ntel][reportTypeId]->GetYaxis()->SetRangeUser(yaxis_min, yaxis_max);
          gPad->SetLogy();
        } 
        h1ParamsPerTel1[paramIdToPlot][i][ntel][reportTypeId]->Draw("p");
        if( paramToPlot.compare("ImpactDist") == 0 ||
            paramToPlot.compare("Width") == 0 ||
            paramToPlot.compare("Length") == 0   
          ){
          h1ParamsPerTel1[paramIdToPlot][i][ntel][reportTypeId]->GetYaxis()->SetRangeUser(yaxis_min, yaxis_max);
        }
        for(int k=0; k<3; k++)
          h1ParamsPerTel2[paramIdToPlot][i][ntel][k]->Draw("psames");

        maxVBin = h1ParamsPerTel1[paramIdToPlot][i][ntel][reportTypeId]->GetMaximumBin();
      }
      if ( printfilename.size() > 0 )
        can[ntel]->Print( printfilename.c_str(), "pdf");
        
     }
  }
}
