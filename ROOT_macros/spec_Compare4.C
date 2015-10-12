void spec_Compare4( string fi1, string lab1, string fi2,
		    string lab2, string func3="", string lab3="",
		    string outroot="" )
{
  gStyle->SetOptStat(0);
  gStyle->SetOptFit(0);
  TFile *f1 = new TFile( fi1.c_str() );
  TFile *f2 = new TFile( fi2.c_str() );
  TDirectory *d = 0;
  VASpectrumAnl *s1 = 0, *s2 = 0;
  TGraphAsymmErrors *g1 = 0, *g2 = 0;
  f1->GetObject( "Spectrum", d );
  d->GetObject( "VASpectrumAnl", s1 );
  if ( s1 == 0 ) {
    d->GetObject( "VASpectrum", s1 );
  }
  f2->GetObject( "Spectrum", d );
  d->GetObject( "VASpectrumAnl", s2 );
  if ( s2 == 0 ) {
    d->GetObject( "VASpectrum", s2 );
  }
  g1 = s1->GetSpectrumGraph();
  g2 = s2->GetSpectrumGraph();
  g1->GetListOfFunctions()->Clear();
  g2->GetListOfFunctions()->Clear();
  float emin = 0.18;
  float emax = 1.8;
  TGraphAsymmErrors *g1a = (TGraphAsymmErrors*)g1->Clone("FlatSpecGraph1");
  TGraphAsymmErrors *g2a = (TGraphAsymmErrors*)g2->Clone("FlatSpecGraph2");
  TF1 *fit1 = new TF1( "fit1", "[0]*pow(x,[1])", emin, emax );
  TF1 *fit2 = new TF1( "fit2", "[0]*pow(x,[1])", emin, emax );
  TF1 *fun3 = new TF1( "fun3", func3.c_str(), emin, emax );
  fit1->SetLineColor( 3 );
  fit2->SetLineColor( 4 );
  fun3->SetLineColor( 6 );
  fit1->SetLineWidth( 2 );
  fit2->SetLineWidth( 2 );
  fun3->SetLineWidth( 2 );
  fit1->SetParameters( 4e-7, -2.5 );
  fit2->SetParameters( 4e-7, -2.5 );
  g1->Fit( fit1, "R" );
  cout << "Chisq/NDF = " << fit1->GetChisquare() << " / " << fit1->GetNDF() << endl;
  cout << "   probability = " << fit1->GetProb() << endl;
  g2->Fit( fit2, "R" );
  cout << "Chisq/NDF = " << fit2->GetChisquare() << " / " << fit2->GetNDF() << endl;
  cout << "   probability = " << fit2->GetProb() << endl;
  TF1 *fitInt1 = (TF1*)fit1->Clone("fitInt1");
  fitInt1->SetRange( emin, 1000 );
  float intFlux1 = fitInt1->Integral( emin, 1000 );
  float intFluxError1 = fitInt1->IntegralError( emin, 1000 );
  TF1 *fitInt2 = (TF1*)fit2->Clone("fitInt2");
  fitInt2->SetRange( emin, 1000 );
  float intFlux2 = fitInt2->Integral( emin, 1000 );
  float intFluxError2 = fitInt2->IntegralError( emin, 1000 );
  cout << endl
       << "**************************************************************"
       << endl << "*" << endl
       << "* Fit1: Integral flux above " << emin << " TeV is " 
       << intFlux1 << " +- " << intFluxError1 << endl
       << "*" << endl
       << "*" << endl << "*" << endl
       << "* Fit2: Integral flux above " << emin << " TeV is " 
       << intFlux2 << " +- " << intFluxError2 << endl
       << "*" << endl;
  cout << "*" << endl
       << "**************************************************************"
       << endl;
  fitInt1->SetRange( 1, 1000 );
  float intFlux1 = fitInt1->Integral( 1, 1000 );
  float intFluxError1 = fitInt1->IntegralError( 1, 1000 );
  fitInt2->SetRange( 1, 1000 );
  float intFlux2 = fitInt2->Integral( 1, 1000 );
  float intFluxError2 = fitInt2->IntegralError( 1, 1000 );
  cout << endl
       << "**************************************************************"
       << endl << "*" << endl
       << "* Fit1: Integral flux above " << 1 << " TeV is " 
       << intFlux1 << " +- " << intFluxError1 << endl
       << "*" << endl
       << "*" << endl << "*" << endl
       << "* Fit2: Integral flux above " << 1 << " TeV is " 
       << intFlux2 << " +- " << intFluxError2 << endl
       << "*" << endl;
  cout << "*" << endl
       << "**************************************************************"
       << endl;
  TF1 *v1 = new TF1( "v1", "fit1*pow(x,2.)", emin, emax );
  TF1 *v2 = new TF1( "v2", "fit2*pow(x,2.)", emin, emax );
  TF1 *whipple = new TF1( "whipple",
			  "3.2e-7*pow(x,-2.49)",
			  0.3, 10 );
  TF1 *whippleflat = new TF1( "whippleflat",
			      "3.2e-7*pow(x,-2.49)*pow(x,2.)",
			      0.3, 10 );
  TF1 *hegra = new TF1( "hegra",
			"2.83e-7*pow(x,-2.62)", 
			0.5, 80 );
  TF1 *hegraflat = new TF1( "hegraflat",
			"2.83e-7*pow(x,-2.62)*pow(x,2.)", 
			0.5, 80 );
  TF1 *hess = new TF1( "hess",
			"3.76e-7*pow(x,-2.39)*exp(-x/14.3)", 
			0.44, 20 );
  TF1 *hessflat = new TF1( "hessflat",
			"3.76e-7*pow(x,-2.39)*exp(-x/14.3)*pow(x,2.)", 
			0.44, 20 );
  TF1 *magic = new TF1( "magic",
			"6.0e-6*pow(x/0.3, -2.31-0.26*log10(x/0.3))", 
			0.06, 9 );
  TF1 *magicflat = new TF1( "magicflat",
			"6.0e-6*pow(x/0.3, -2.31-0.26*log10(x/0.3))*pow(x,2.)", 
			0.06, 9 );
  TF1 *alex = new TF1( "alex",
		       "3.73e-7*pow(x,-2.68)",
		       0.4, 3 );
  TF1 *alexflat = new TF1( "alexflat",
			   "3.73e-7*pow(x,-2.68)*pow(x,2.)",
			   0.4, 3 );
  TF1 *fun3flat = new TF1( "fun3flat",
			   string( func3 + "*pow(x,2.)" ).c_str(), 
			   emin, emax );
  v1->SetLineColor( 3 );
  v2->SetLineColor( 4 );
  v1->SetLineWidth( 2 );
  v2->SetLineWidth( 2 );
  fun3flat->SetLineColor( 6 );
  fun3flat->SetLineWidth( 2 );
  whipple->SetLineColor( 1 );
  whippleflat->SetLineColor( 1 );
  hegra->SetLineColor( 2 );
  hegraflat->SetLineColor( 2 );
  hess->SetLineColor( 7 );
  hessflat->SetLineColor( 7 );
  magic->SetLineColor( 6 );
  magicflat->SetLineColor( 6 );
  alex->SetLineColor( 8 );
  alex->SetLineStyle( 2 );
  alexflat->SetLineColor( 8 );
  alexflat->SetLineStyle( 2 );
  whipple->SetLineWidth( 1 );
  hegra->SetLineWidth( 1 );
  hess->SetLineWidth( 1 );
  magic->SetLineWidth( 1 );
  whippleflat->SetLineWidth( 1 );
  hegraflat->SetLineWidth( 1 );
  hessflat->SetLineWidth( 1 );
  magicflat->SetLineWidth( 1 );
  TLegend *leg = new TLegend( 0.6, 0.7, 0.95, 0.95 );
  leg->AddEntry( g1, lab1.c_str(), "ple" );
  leg->AddEntry( g2, lab2.c_str(), "ple" );
  leg->AddEntry( whipple, "Crab Whipple", "l" );
  leg->AddEntry( hegra, "Crab HEGRA", "l" );
  leg->AddEntry( hess, "Crab HESS", "l" );
  leg->AddEntry( magic, "Crab MAGIC", "l" );
  leg->AddEntry ( fun3, lab3.c_str(), "l" );
  //leg->AddEntry( alex, "Alex - Collab Mtg Old North Sims Std Cuts", "l" );

  const int n1 = g1->GetN();
  const int n2 = g2->GetN();
  double x, y, exh, exl, eyh, eyl;
  for ( int i=0; i<n1; ++i )
    {
      g1->GetPoint( i, x, y );
      g1a->SetPoint( i, x, pow(x,2)*y );
      exh = g1->GetErrorXhigh( i );
      exl = g1->GetErrorXlow( i );
      eyh = g1->GetErrorYhigh( i );
      eyl = g1->GetErrorYlow( i );
      g1a->SetPointError( i, exl, exh, pow(x,2)*eyl, pow(x,2)*eyh );
    }
  for ( int i=0; i<n2; ++i )
    {
      g2->GetPoint( i, x, y );
      g2a->SetPoint( i, x, pow(x,2)*y );
      exh = g2->GetErrorXhigh( i );
      exl = g2->GetErrorXlow( i );
      eyh = g2->GetErrorYhigh( i );
      eyl = g2->GetErrorYlow( i );
      g2a->SetPointError( i, exl, exh, pow(x,2)*eyl, pow(x,2)*eyh );
    }
  TH2F *hf = new TH2F( "hf", "", 100, 0.01, 50, 100, 1.e-12, 1.e-4 );
  TH2F *hg = new TH2F( "hg", "", 100, 0.01, 50, 100, 1.e-12, 4.e-6 );
  hf->GetXaxis()->SetTitle( "Energy (TeV)" );
  hf->GetYaxis()->SetTitle( "Flux (TeV^{-1}m^{-2}s^{-1})" );
  hg->GetXaxis()->SetTitle( "Energy (TeV)" );
  hg->GetYaxis()->SetTitle( "E^{2}*Flux (TeV^{-1}m^{-2}s^{-1})" );
  TCanvas *c1 = new TCanvas( "c1", "spec2", 0, 0, 900, 700 );
  TCanvas *c2 = new TCanvas( "c2", "spec2 * E^2", 0, 0, 900, 700 );
  c1->cd();
  c1->SetLogy();
  c1->SetLogx();
  hf->Draw();
  whipple->Draw("same");
  hegra->Draw("same");
  hess->Draw("same");
  magic->Draw("same");
  //fun3->Draw("same");
  //alex->Draw("same");
  g1->SetMarkerColor( 3 );
  g1->SetLineColor( 3 );
  g1->SetMarkerStyle( 8 );
  g1->Draw( "p" );
  g2->SetMarkerColor( 4 );
  g2->SetLineColor( 4 );
  g2->SetMarkerStyle( 8 );
  g2->Draw( "p" );
  leg->Draw();
  c2->cd();
  c2->SetLogy();
  c2->SetLogx();
  hg->Draw();
  whippleflat->Draw("same");
  hegraflat->Draw("same");
  hessflat->Draw("same");
  magicflat->Draw("same");
  //fun3flat->Draw("same");
  //alexflat->Draw("same");
  g1a->SetMarkerColor( 3 );
  g1a->SetLineColor( 3 );
  g1a->SetMarkerStyle( 8 );
  g1a->Draw( "p" );
  g2a->SetMarkerColor( 4 );
  g2a->SetLineColor( 4 );
  g2a->SetMarkerStyle( 8 );
  g2a->Draw( "p" );
  v1->Draw("same");
  v2->Draw("same");
  leg->Draw();

  if ( outroot.length() > 0 )
    {
      c1->cd();
      c1->Print( string( outroot + ".png" ).c_str() );
      c2->cd();
      c2->Print( string( outroot + "Flat.png" ).c_str() );
    }
}
