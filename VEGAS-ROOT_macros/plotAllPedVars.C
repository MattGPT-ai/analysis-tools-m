
#include "loadChain.C"
#include "aclicPreProcCommands.h"
#include <Riostream.h>


#include <VAPlotCam.h>

/**
 * \file dumpPedPedVars.C
 * \ingroup macros
 * \brief Prints the relative gains from OAWG file to a VAPlotCam
 *
 * Original Author: Peter Cogan
 * $Author: akuznetl $
 * $Date: 2013/08/01 05:16:18 $
 * $Revision: 1.5 $
 * $Tag$
 *
 **/

// ----------------------------------------------------------------------------
// Nice useful instructions printed when the user does plotAllPedPedVars()
// ----------------------------------------------------------------------------


void plotAllPedPedVars()
{
	cout << "Macro to display the relative gains" << endl;
	cout << "---------" << endl;
	cout << "The macro header looks like this: " << endl;
	cout << "plotAllPedPedVars( string &filename)" << endl;
	cout << endl;
	cout << "or you can also use this if you already have an active loaded instance of VARootIO" << endl;
	cout << "plotAllPedPedVars(VARootIO &io)" << endl;
	cout << endl;
	cout << "Example:" << endl;
	cout << "---------" << endl;
	cout << "plotAllPedPedVars(\"myfile.root\");" << endl;
}


// ----------------------------------------------------------------------------
// This is the main function for this macro
// ----------------------------------------------------------------------------

//void plotAllPedPedVars( string filename, string textFileString )
void plotAllPedPedVars( VARootIO& io, string textFileString )
{
	gStyle->SetTitleX(0.5);
	gStyle->SetTitleAlign(23);
	gStyle->SetTitleFillColor(0);

	//VARootIO io(filename, true);     
	//io.setFilename(filename);      
	io.loadTheRootFile(); 
                                             
	int canvasSize = 400;
	int yDiff = 400;
	io.loadTheRootFile();
	if(!io.IsOpen())
	{
	  //cout << "The root file " << io.getFilename() << " could not be opened" << endl;
	  cout << "The root file " << filename << " could not be opened" << endl;
	  return;
	}
	
	const VAQStatsData* qd = io.loadTheQStatsData();
	if(qd == NULL)
	{
		cout << "No pedestal data found in the file" << endl;
		return;
	}
	
	const VARunHeader* rh = io.loadTheRunHeader();
	if(!rh)
	{
		cout << " No run header found in the file" << endl;
		return;
	}
	
	VARunDetails* details = NULL;
	details = rh->pfRunDetails;
	if(!details)
	{
		cout << "Couldn't find the run details" << endl;
		return;
	}
	
	
	float qVarMin = gDefaultPedVarMinSTDEV;
	float qVarMax = gDefaultPedVarMaxSTDEV;
	
	uint32_t numPix = 499;
       
	int xPos = 0;
	int yPos = 0;
	
	TH2F** q2d = new TH2F*[kMaxTels];
	
	//TCanvas** canvas = new TCanvas*[kMaxTels];
	TCanvas* canvas = new TCanvas("pedVarCanvasAllTels","PedVar Histograms, All Tels",xPos,yPos,canvasSize*400,canvasSize);
	canvas->Divide(4,1);
	
	char** hnames = new char*[kMaxTels];
	char** cnames = new char*[kMaxTels];
	char** titles = new char*[kMaxTels];
	TLine line;
	line.SetLineWidth(2);
	line.SetLineColor(2);
	TBox box;
	box.SetFillStyle(3004);
	box.SetFillColor(3);
	
	VAPlotCam** cams = new VAPlotCam*[kMaxTels];
	float** camVals = new float*[kMaxTels];
	for(int i = 0; i < kMaxTels; i++)
	{
		cams[i] = NULL;
		camVals[i] = NULL;
	}
       
	    
	cout << "Telescope\tMean\tStDev" << endl;	
	ofstream textFile_ofs;
	if ( ! textFileString.empty() )
	  { 
	    textFile_ofs.open(textFileString.c_str(), ofstream::out | ofstream::app); 
	    //textFile_ofs << runNum << endl;
	  }

	for(uint32_t telID = 0; telID < kMaxTels; telID++)
	{
		q2d[telID] = NULL;
		//canvas[telID] = NULL;
		hnames[telID] = NULL;
		cnames[telID] = NULL;
		titles[telID] = NULL;
		if(details->fExpectedTels[telID] == 1)
		{
			camVals[telID] = new float[numPix];
			hnames[telID] = new char[100];
			cnames[telID] = new char[100];
			titles[telID] = new char[100];
			sprintf(hnames[telID], "Tel_%dQStats", telID + 1);
			sprintf(cnames[telID], "Tel_%d Canvas Pedestals and Pedvars", telID + 1);
			sprintf(titles[telID], "Telescope %d Pedestals and Pedvars", telID + 1);
			q2d[telID] = new TH2F(hnames[telID], titles[telID], 50, 10, 25, 50, -6, 6);
			float meanPedVar = 0;
			float stdevPedVar = 0;
			for(uint32_t chan = 0; chan < numPix; chan++)
			{
				camVals[telID][chan] = qd->getTraceVarTimeIndpt(telID, chan, 7);
				meanPedVar += qd->getTraceVarTimeIndpt(telID, chan, 7);
			}
			meanPedVar /= numPix;
			for(uint32_t chan = 0; chan < numPix; chan++)
			{
				stdevPedVar += (qd->getTraceVarTimeIndpt(telID, chan, 7) - meanPedVar) * (qd->getTraceVarTimeIndpt(telID, chan, 7) - meanPedVar);
			}
			stdevPedVar /= (numPix - 1);
			stdevPedVar = TMath::Sqrt(stdevPedVar);
			float corrected = 0;
			if(stdevPedVar > 0)
				for(uint32_t chan = 0; chan < numPix; chan++)
				{
					corrected = (qd->getTraceVarTimeIndpt(telID, chan, 7) - meanPedVar) / stdevPedVar;
					q2d[telID]->Fill(qd->getTraceMeanTimeIndpt(telID, chan, 5) / 5.0, corrected);
				}
			else
			{
				cout << "Warning:Got a stdevPedVar of " << stdevPedVar << endl;
			}
			//canvas[telID] = new TCanvas(cnames[telID], titles[telID], xPos, yPos, canvasSize, canvasSize);
			cams[telID] = new VAPlotCam(numPix, titles[telID], titles[telID], canvasSize, xPos, yPos + yDiff);
			cams[telID]->SetTitle(titles[telID]);
			cams[telID]->setScale(0, 10);
			cams[telID]->pfCanvas->GetFrame()->SetFillColor(0);
			cams[telID]->plot(camVals[telID]);
			if(xPos <= 2 * yDiff)
			{
				xPos += yDiff;
			}
			else
			{
				yPos += yDiff;
			}
			//canvas[telID]->SetFillColor(0);
			canvas->SetFillColor(0);
			//canvas[telID]->cd();
			canvas->cd(telID+1);
			q2d[telID]->SetStats(false);
			//canvas[telID]->SetLeftMargin(0.12);
			canvas->SetLeftMargin(0.12);
			q2d[telID]->GetXaxis()->SetTitle("Pedestal");
			q2d[telID]->GetYaxis()->SetTitle("Pedvar");
			q2d[telID]->GetYaxis()->SetTitleOffset(1.45);
			q2d[telID]->SetMarkerStyle(7);
			q2d[telID]->Draw();
			line.DrawLine(10, qVarMin, 25, qVarMin);
			line.DrawLine(10, qVarMax, 25, qVarMax);

			//      box.DrawBox(gainMin, gainVarMin, gainMax, gainVarMax);
			
			cout << telID+1 << "\t\t" << meanPedVar << "\t" << stdevPedVar << endl;
			if ( textFile_ofs )
			  {
			    textFile_ofs << telID+1 << "\t" << meanPedVar << "\t" << stdevPedVar << endl; 
			  }

		} // if(details->fExpectedTels[telID] == 1)
	} // for loop through all tels
	
	//TString plotTitle = Form ("plots/pedVarPlot.png");
	//canvas->Print(plotTitle,"png");
			
	io.closeTheRootFile();
	
	//   char *telname = new char[100];
	//   sprintf(telname, "T%d", (int)telescopeNumber);
	//   TPaveLabel *pavetext = new TPaveLabel(1.6,0.62,1.2,0.7,telname);
	//   pavetext->SetFillColor(0);
	//   pavetext->Draw();
		
} // void plotAllPedPedVars(VARootIO& io)
 

void plotAllPedPedVars( string filename, string textFile )
{
  VARootIO io(true);
  io.setFilename(filename);
  io.loadTheRootFile();
	if(io.IsOpen())
	{
	  plotAllPedPedVars(io, textFile);
	}
	else
	{
		cout << "The root file " << filename << " could not be opened" << endl;
		return;
	}
}

