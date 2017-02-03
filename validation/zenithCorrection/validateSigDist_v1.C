#include <TFile.h>
#include <TH1D.h>
#include <TF1.h>
#include <TMath.h>
#include <TFitResultPtr.h>

using namespace std;

void validateSigDist(string inFile,const double widthTolerance = 0.05,const double meanTolerance = 0.1, const double probTolerance = TMath::Erfc(5.0/sqrt(2)),bool verbose = true)
{
  cout << "Now starting Ben Zitzer's (un)fancy validation script!" << endl;
  
  cout << "Looking for stage 6 file... ";
  TFile* f = new TFile(inFile.c_str(),"READ");
  if(!f->IsOpen())
    {
      cout << "FAIL!" << endl;
      return;
    }
  cout << "OK!" << endl;

  cout << "Looking for significance distribution histogram... ";
  TH1D* hSigDistAllExcl = 
    (TH1D*)f->Get("RingBackgroundModelAnalysis/SigDistributionMinusAllExcl");
  if( hSigDistAllExcl == NULL )
    {
      cout << "FAIL!" << endl;
      return;
    }
  cout << "OK!" << endl;

  string fitOpt = "";
  
  hSigDistAllExcl->Sumw2();
  hSigDistAllExcl->Scale(1.0/hSigDistAllExcl->GetSumOfWeights());
  

  if(verbose)
    fitOpt = "N";
  else
    fitOpt = "0";

  TF1* fFitGaus = new TF1("fFitGaus","gaus",-6,10);
  cout << "Doing Fit to Gaussian... ";
  TFitResultPtr fitPtr = hSigDistAllExcl->Fit(fFitGaus,fitOpt.c_str(),"R",-6,10);
  /*
  TFitResult* fitResult = fitPtr.Get();
  if( fitResult != NULL )
    {
      cout << " FAIL!" << endl;
      return;
    }
  cout << "OK!" << endl;
  */
  cout << "Done!" << endl;

  cout << "Checking significance distribution width within tolerance... ";
  double sigWidth = fFitGaus->GetParameter(2);
  if( widthTolerance < TMath::Abs(sigWidth - 1.0) )
    {
      cout << "FAIL!" << endl;
      return;
    }
  cout << "OK!" << endl;
  
  cout << "Checking significance distribution mean within tolerance... ";
  double sigMean = fFitGaus->GetParameter(1);
  if( meanTolerance < TMath::Abs(sigMean) )
    {
      cout << "FAIL!" << endl;
      return;
    }
  cout << "OK!" << endl;

  cout << "Checking Gaussian fit probabability within tolerance... ";
  double prob = fFitGaus->GetProb();
  if(verbose)
    {
      cout << endl;
      cout << " Number of DOF: " << fFitGaus->GetNDF() << endl;
      cout << " Chi^2 of fit: " << fFitGaus->GetChisquare() << endl;
      cout << " Probability: " << prob << endl;
    }

  if( prob < probTolerance )
    {
      cout << "FAIL!" << endl;
      return;
    }
  cout << "OK!" << endl;

  cout << "Everything looks OK! " << endl;
}

int main(int argc, char** argv)
{
  
  if( argc == 1 )
    {
      cout << "Not enough input arguments!" << endl;
      return(0);
    }
  
  string str = argv[1];
  validateSigDist(str);
}
