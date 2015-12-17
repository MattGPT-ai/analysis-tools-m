#include <cstdlib>
#include <iostream>
#include <fstream>
//#include <cmath>

int plotPoints( char* filename1, char* filename2 )
{
  
  // set global style options, such as for the marker
  // setting them individually resulted in markers that were not visible, not sure why
  gStyle->SetMarkerStyle(20); 
  //gPad->SetGridx();
  //gPad->SetGridy();

  // open the files, check, read in the points 
  std::ifstream pointsFile1, pointsFile2;
  pointsFile1.open(filename1);
  pointsFile2.open(filename2);

  if( !pointsFile1.is_open() )
    std::cerr << "Cannot open file: " << filename1 << std::endl;
  if( !pointsFile2.is_open() )
    std::cerr << "Cannot open file: " << filename2 << std::endl;
  if( !pointsFile1.is_open() || !pointsFile2.is_open() )
    return EXIT_FAILURE;

  int pointNum = 0; 
  float energy; // in TeV
  float dNdE; // 1/TeV*m^2*s
  float fluxError; // same as flux 

  TGraphErrors* graph1A = new TGraphErrors(); // flux plot for series 1
  TGraphErrors* graph1B = new TGraphErrors(); // energy squared flux for series 1
  while (pointsFile1 >> energy >> dNdE >> fluxError)
    {
      graph1A->SetPoint(pointNum,energy,dNdE);
      graph1A->SetPointError(pointNum,0,fluxError);

      graph1B->SetPoint(pointNum,energy,energy*energy*dNdE); //math.pow(energy,2)
      graph1B->SetPointError(pointNum,0,energy*energy*fluxError); // not sure this is the proper error here 

      pointNum++;
    } // read in points 

  pointNum = 0;
  TGraphErrors* graph2A = new TGraphErrors(); // flux plot for series 2 
  TGraphErrors* graph2B = new TGraphErrors(); // energy squared flux for series 2
  while (pointsFile2 >> energy >> dNdE >> fluxError)
    {
      graph2A->SetPoint(pointNum,energy,dNdE);
      graph2A->SetPointError(pointNum,0,fluxError);

      graph2B->SetPoint(pointNum,energy,energy*energy*dNdE);
      graph2B->SetPointError(pointNum,0,energy*energy*fluxError);

      pointNum++;
    } // read in points 
  
  //graph1A->SetMarkerStyle(10); // does not work
  //graph1A->SetLineColor(0);

  // set the marker properties 
  graph1A->SetMarkerColor(2);
  graph1A->SetMarkerSize(0.5);
  graph1B->SetMarkerColor(2);
  graph1B->SetMarkerSize(0.5);

  graph2A->SetMarkerColor(3);
  graph2A->SetMarkerSize(0.5);
  graph2B->SetMarkerColor(3);
  graph2B->SetMarkerSize(0.5);

  // combine both series onto each multiplot 
  TMultiGraph* combinedGraphA = new TMultiGraph();
  combinedGraphA->Add(graph1A);
  //combinedGraphA->Add(graph2A);
  TMultiGraph* combinedGraphB = new TMultiGraph();
  combinedGraphB->Add(graph1B);
  //combinedGraphB->Add(graph2B);

  // Set titles and add legned: 
  //combinedGraphA->SetMinimum(2);
  combinedGraphA->SetTitle("Sgr A* Flux Spectrum");
  combinedGraphB->SetTitle("Sgr A* Energy Squared Flux Spectrum");

  TLegend* legendA = new TLegend(0.5,0.65,0.88,0.85);
  legendA->AddEntry(graph1A,"Matt","p");
  legendA->AddEntry(graph2A,"Andy","p");
  TLegend* legendB = new TLegend(0.5,0.65,0.88,0.85);
  legendB->AddEntry(graph1A,"Matt","p");
  legendB->AddEntry(graph2A,"Andy","p");

  TCanvas* canvasA = new TCanvas("canvasA","Sgr A* Flux Canvas",200,10,700,500);
  canvasA->SetLogx();
  canvasA->SetLogy();
  canvasA->cd();
  combinedGraphA->Draw("A P"); // must draw first before axes are generated 

  TAxis* combinedXAxis = combinedGraphA->GetXaxis();
  combinedXAxis->SetTitle("Energy (TeV)");
  combinedXAxis->CenterTitle();
  combinedXAxis->SetRangeUser(2,50);
  TAxis* combinedYAxis = combinedGraphA->GetYaxis();
  combinedYAxis->SetTitle("dN/dE (1/TeV*m^2*s)");
  combinedYAxis->CenterTitle();

    // have to redraw once we've set everything 
  combinedGraphA->Draw("A P"); // draw with no line
  //legendA->Draw(); // does this have to come after second draw? 
  canvasA->Update(); // doesn't seem to be doing anything, which is why we have to draw again 

  TCanvas* canvasB = new TCanvas("canvasB","Sgr A* Energy Squared Flux Canvas",200,10,700,500);
  canvasB->SetLogx();
  canvasB->SetLogy();
  canvasB->cd();
  combinedGraphB->Draw("A P"); 

  combinedXAxis = combinedGraphB->GetXaxis();
  combinedYAxis = combinedGraphB->GetYaxis();
  combinedXAxis->SetTitle("Energy (TeV)");
  combinedXAxis->CenterTitle();
  combinedXAxis->SetRangeUser(2,50);
  combinedYAxis->SetTitle("E^2*dN/dE (TeV/m^2*s)");
  combinedYAxis->CenterTitle();

  // draw plot B 
  combinedGraphB->Draw("A P");
  //legendB->Draw();
  canvasB->Update();

  std::cout << "Plots completed. Delete everything? Y or N" << std::endl;
  char response = '';
  // delete and close everything 
  std::cin >> response;

  if (response == 'Y')
    {
      delete graph1A;
      delete graph2A;
      delete legendA;
      delete combinedGraphA;
      delete canvasA;
      delete graph1B;
      delete graph2B;
      delete legendB;
      delete combinedGraphB;
      delete canvasB;
    } // check for affirmative response 

  pointsFile1.close();
  pointsFile2.close();

  return EXIT_SUCCESS; // great job 
} // plotPoints 
