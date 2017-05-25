import numpy as np 
from matplotlib import pyplot as plt
import matplotlib.ticker as mtick


if __name__ == '__main__':
    from os.path import expanduser



home = expanduser('~')
val_dir = home + "/Dropbox/VEGAS/validation"

# set the energy limits 
E = 0 


# extract the lightcurve data points

lc_data = np.genfromtxt(val_dir+"/lightcurves/PKS1424_lightcurve_daily_v255_singleEA.txt") 

lc_data_points = []
for i in range(len(lc_data[:,0])):
    if lc_data[i,3] != 0 and lc_data[i,1] > 0.: # 
        lc_data_points.append(lc_data[i,:])

lc_data_points = np.array(lc_data_points) 


MJD_array = np.array(lc_data_points[:,0], dtype=np.float64)
flux_obs_array = np.array(lc_data_points[:,1], dtype=np.float64) #  / (m^2 * s)
flux_err_array = np.array(lc_data_points[:,2], dtype=np.float64)
livetime_array = np.array(lc_data_points[:,3], dtype=np.float64)

#print(flux_obs_array)
#log = list(map(lambda l: np.log10(l), _array))

fluxtime_array = flux_obs_array * livetime_array

# find the total livetime and mean flux 
total_livetime = np.sum(livetime_array)
mean_flux = np.sum(fluxtime_array) / total_livetime
print(mean_flux)


fig = plt.figure()

#plt.title("PKS1424 Integral Flux ("+str(E)+"TeV < E < 100TeV)")
plt.title("PKS1424 Integral Flux (E > 1TeV)")
plt.xlabel(r"$time\left(MJD\right)$")
plt.ylabel(r"flux $\frac{gamma}{m^{2}s}$") # gamma / m^2*s*TeV
ax = fig.add_subplot(111)
ax.errorbar(MJD_array, flux_obs_array, yerr=flux_err_array, fmt='b.', label='daily') # 
ax.ticklabel_format(style='scientific')
ax.yaxis.set_major_formatter(mtick.FormatStrFormatter('%.1e'))
plt.ylim(ymin=-3e-7)
plt.axhline(mean_flux)
plt.tight_layout()
#lgd = ax.legend(loc='upper center', bbox_to_anchor=(1.1,0.5))

plt.savefig(val_dir+"/lightcurves/PKS1424_lightcurve_2013_daily_v255_defE.pdf")
         #, bbox_extra_artists=(lgd,), bbox_inches='tight')
#plt.savefig(val_dir+"/plots/lightCurve/PKS1424_lightcurve_all_4tels_E"+str(E)+"_.png")
