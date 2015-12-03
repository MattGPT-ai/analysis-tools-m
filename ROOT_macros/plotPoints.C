#include <cstdlib>
#include <iostream>
#include <fstream>

int plotPoints( char* filename1, char* filename2 )
{
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

  TGraphErrors* graph1 = new TGraphErrors();
  while (pointsFile1 >> energy >> dNdE >> fluxError)
    {
      graph1->SetPoint(pointNum,energy,dNdE);
      graph1->SetPointError(pointNum,0,fluxError);

      pointNum++;
    } // read in points 

  pointNum = 0;
  TGraphErrors* graph2 = new TGraphErrors();
  while (pointsFile2 >> energy >> dNdE >> fluxError)
    {
      graph2->SetPoint(pointNum,energy,dNdE);
      graph2->SetPointError(pointNum,0,fluxError);

      pointNum++;
    } // read in points 

  TMultiGraph* combinedGraph = new TMultiGraph();
  combinedGraph->Add(graph1);
  combinedGraph->Add(graph2);

  TCanvas* canvas0 = new TCanvas("canvas0","Plot Canvas",200,10,700,500);
  canvas0->SetLogx();
  canvas0->SetLogy();
  canvas0->cd();
  //graph1->Draw("AL");
  combinedGraph->Draw("");

  pointsFile1.close();
  pointsFile2.close();

  return EXIT_SUCCESS; 
} // plotPoints 
