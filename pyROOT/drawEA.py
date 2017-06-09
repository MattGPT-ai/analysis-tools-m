    #!/usr/bin/env python
import matplotlib
import matplotlib.pyplot as mpl
from rootpy import ROOT
import sys
import os
matplotlib.use('Agg')
matplotlib.rcParams['text.usetex'] = True
matplotlib.rcParams['font.family'] = 'serif'
matplotlib.rcParams['figure.autolayout'] = True

ROOT.gSystem.Load("libTreePlayer.so")
ROOT.gSystem.Load("libPhysics.so")
vegas = os.getenv("VEGAS")
ROOT.gSystem.Load("{0}/common/lib/libSP24sharedLite.so".format(vegas))
ROOT.gSystem.Load("{0}/resultsExtractor/lib/libStage6shared.so".format(vegas))
ROOT.gSystem.Load("{0}/showerReconstruction2/lib/libStage4.so".format(vegas))

if len(sys.argv) != 5:
    print """
    =======================
          drawEA.py
    =======================
    usage: python drawEA.py <standard EA> <comparison EA> <ZA> <output file>
    standard EA
    """
    exit

standard = sys.argv[1]
compare = sys.argv[2]
za = sys.argv[3]
outfile = sys.argv[4]

labels = dict()
labels[standard] = "Standard EA"
labels[compare] = "Produced EA"

xdict = dict()
ydict = dict()

fig, ax = mpl.subplots()
ax.set_yscale('log')
ax.set_xlabel("Log$_{10}$ E (TeV)")
ax.set_ylabel("Effective Area (m$^2$)")

for f in (standard, compare):
    tfile = ROOT.TFile(f)
    print "Opening file {0}".format(f)
    ea_dir = tfile.Get("effective_areas")
    key_list = ea_dir.GetListOfKeys()
    nkeys = key_list.GetEntries()
    xlist = list()
    ylist = list()
    print "File contains {0} effective areas".format(nkeys-1)
    counter = 0
    for i in range(0, nkeys-1):
        cur_key = key_list[i]
        keyname = cur_key.GetName()
        st = keyname.find("Zenith")
        end = keyname.find("_Noise")
        ea_zenith = keyname[st:end].split("_")[-1]
        if int(ea_zenith) != int(za):
            continue
        counter += 1
        ea = ea_dir.Get(keyname)
        print "Reading effective area {0}".format(keyname)
        ea_mc = ea.pfEffArea_MC
        ea_x = ea_mc.GetX()
        ea_y = ea_mc.GetY()
        this_xlist = list()
        this_ylist = list()
        for x in range(0, len(ea_x)):
            this_xlist.append(ea_x[x])
        for y in range(0, len(ea_y)):
            this_ylist.append(ea_y[y])
        xlist.append(this_xlist)
        ylist.append(this_ylist)

    # Now average these lists
    print "{0} effective areas at requested ZA".format(counter)
    xavg = [float(sum(l)) / len(l) for l in zip(*xlist)]
    yavg = [float(sum(l)) / len(l) for l in zip(*ylist)]

    ax.step(xavg, yavg, label=labels[f])
mpl.legend()
mpl.title("Comparison at {0} degree zenith angle".format(za))
mpl.savefig(outfile)
mpl.close()

# drawEA.py ends here
