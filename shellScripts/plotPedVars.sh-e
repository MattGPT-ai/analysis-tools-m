#!/bin/bash

wobble=050

cd $VEGAS/macros/

for array in oa na ua; do 
    for atm in 21 22; do 
	for zenith in 00 20 30 40; do 
	    for noise in 100 150 200 250 300 350 400 490 605 730 870; do 

		root -l -b <<EOF
plotAllPedPedVars("/veritas/upload/OAWG/stage2/vegas2.5/Oct2012_${array}_ATM${atm}/${zenith}_deg/Oct2012_${array}_ATM${atm}_vegasv250rc5_7samples_${zenith}deg_${wobble}wobb_${noise}noise.root")
EOF

		mv plots/pedVarPlot.eps $BDT/plots/pedVars_${wobble}wobble/pedVarPlot_${array}_ATM${atm}_z${zenith}_noise${noise}.eps
		mv plots/pedVarPlot.png $BDT/plots/pedVars_${wobble}wobble/png/pedVarPlot_${array}_ATM${atm}_z${zenith}_noise${noise}.png
		mv plots/pedVarPlot.pdf $BDT/plots/pedVars_${wobble}wobble/pdf/pedVarPlot_${array}_ATM${atm}_z${zenith}_noise${noise}.pdf

		

	    done # noise level
	done # zenith 
    done # atmosphere by season
done #array

exit 0
