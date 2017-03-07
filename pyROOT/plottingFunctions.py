# compatible with python 2 
"""
Module for plotting VEGAS results
compatible with python 2 
"""
from os import path 

import numpy as np
import matplotlib.pyplot as plt
from matplotlib.cm import register_cmap, cmap_d
import matplotlib.lines as mlines
from matplotlib.patches import Ellipse

from astropy.wcs import WCS
from astropy.io import fits, ascii
from astropy import units as u
from astropy.visualization import MinMaxInterval, SqrtStretch, ImageNormalize, LogStretch
from astropy.convolution import Gaussian2DKernel, convolve_fft
from astropy.table import Column

from pprint import pprint
from wcsaxes import SphericalCircle
import pyregion

from scipy.stats import norm
from scipy.optimize import curve_fit, leastsq



_has_ROOT = None
def loadRootVegas():
    """Attempt to load the ROOT / VEGAS libraries if they haven't been loaded yet"""
    #global _has_ROOT
    pass
    
if _has_ROOT == None:
    # do not fail if ROOT is not available, but disable features 
    print "Attempting to import ROOT..."
    
    try:
        import ROOT
    except ImportError:
        _has_ROOT = False
        print "ROOT import failed. You will not be able to use ROOT functionality :("
    else:
        _has_ROOT = True
        from ROOT import gROOT, gSystem, TFile, TGraphAsymmErrors, TH1, TF1, TFitResultPtr
        root_version_major = gROOT.GetVersion()[0]
        import root_numpy # try 

        # load libraries differently depending on versions
        # should also check VEGAS / cmake version 
        if root_version_major == '5':
            vegasPath = path.expandvars("$VEGAS")
            gSystem.Load("libTreePlayer.so")
            gSystem.Load("libPhysics.so")
            gSystem.Load(vegasPath + "/common/lib/libSP24sharedLite.so")
            gSystem.Load(vegasPath + "/resultsExtractor/lib/libStage6shared.so")
            gSystem.AddIncludePath("-Wno-unused -Wno-shadow -Wno-unused-parameter")
            gROOT.ProcessLine(".L " + vegasPath + "/common/include/VACommon.h")
            gROOT.ProcessLine(".include " + vegasPath + "/common/include/")
            gROOT.ProcessLine(".include " + vegasPath + "/resultsExtractor/include/")
            gROOT.ProcessLine(".include " + vegasPath + "/cfitsio/include/")
        #elif root_version_major == 6:
            #ROOT6 stuff 
        else:
            print "Root version ", root_version_major, " not supported! Use version 5 or 6!"
            _has_ROOT = True
            
        print "ROOT import complete"
                
# loadRootVegas 


#taken from http://nbviewer.jupyter.org/gist/adonath/c9a97d2f2d964ae7b9eb
ds9b = {'red': lambda v : 4 * v - 1,
        'green': lambda v : 4 * v - 2,
        'blue': lambda v : np.select([v < 0.25, v < 0.5, v < 0.75, v <= 1],
                                     [4 * v, -4 * v + 2, 0, 4 * v - 3])}

register_cmap('ds9b', data=ds9b)

plt.rcParams['image.cmap'] = 'ds9b' 
print "default colormap is now ", plt.rcParams['image.cmap']

def _gaus(x,a,x0,sigma):
    return a*np.exp(-(x-x0)**2/(2*sigma**2))

class skymapPlotter():
    '''
    A class produced to plot FITS maps
    Initial prouction by Ralph Bird (ralph.bird.1@gmail.com) any comments please get in touch.
    This is an edit of my personal plotting system, do not expect it to either be bullet proof
    or perfect, recommentdations greatfully received.
    
    All plotting attributes can be set in the init or later one at a time.
    
    to see the list of attributes and what they are set to call plottingMethods.printAttr()
    '''
    def __init__(self, **kwargs):
        '''
        Variables that can be defined
        '''
        self.coordSystem     = "icrs"

        self.showGrid        = False
        self.overPlotAltAxes = False
        self.altAxesColor    = "cyan"
        self.primAxesColor   = "black"
        self.figsize         = (9,8)
        self.axisfontsize    = 10
        self.tickfontsize    = 8
        self.dl = self.db = self.dra = self.ddec = 1.*u.deg
        self.setNaNtoValue   = False
        self.smooth          = False
        self.stretch         = "none"
        self.interpolation   = "none"
        
        self.showColorbar    = True
        self.cbarPos         = 0.87
        self.cbarLabel       = None
        self.raFormat        = 'hh:mm'
        self.decFormat       = 'dd'
        self.lFormat         = 'd'
        self.bFormat         = 'd'
        
        for key, value in kwargs.items():
              setattr(self, key, value)
                
    def printAttr(self):
        '''
        This simply dumps all of the attributes that are currently set, 
        useful to see what is going on "under the hood" and give ideas for
        variables that can be changed'''
        pprint (vars(self))

    def _addAxes(self):
        '''
        This sets up the coordinate systems based upon the base system and whether you
        want to overplot another (the other) system, show a grid, etc.
        '''
        if self.coordSystem == "icrs":
            self.axes.coords['ra'].set_ticks(color=self.primAxesColor, spacing=self.dra)
            self.axes.coords['dec'].set_ticks(color=self.primAxesColor, spacing=self.ddec)
            self.axes.coords['ra'].set_major_formatter(self.raFormat)
            self.axes.coords['dec'].set_major_formatter(self.decFormat)
            self.axes.coords['ra'].set_axislabel(r'$\alpha_{\mathrm{J2000}}$',  fontsize=self.axisfontsize)
            self.axes.coords['dec'].set_axislabel(r'$\delta_{\mathrm{J2000}}$', fontsize=self.axisfontsize)
            self.axes.tick_params(axis='both', which='major', labelsize=self.tickfontsize)


            if self.showGrid:
                self.axes.coords.grid(color=self.primAxesColor, linestyle='solid')

            if self.overPlotAltAxes:
                self.cbarPos = 0.91
                self.overlay = self.axes.get_coords_overlay('fk5')
                self.overlay['glon'].set_ticks(color=self.altAxesColor,  spacing=self.dl)
                self.overlay['glat'].set_ticks(color=self.altAxesColor, spacing=self.db)
                self.overlay['glon'].set_axislabel(r'$l[^\circ]$', fontsize=self.axisfontsize)
                self.overlay['glat'].set_axislabel(r'$b[^\circ]$', fontsize=self.axisfontsize)
                self.overlay.grid(color=self.altAxesColor, linestyle='--')
                self.axes.tick_params(axis='both', which='major', labelsize=self.tickfontsize)
                self.overlay['glat'].set_major_formatter(self.bFormat)
                self.overlay['glon'].set_major_formatter(self.lFormat)

        elif self.coordSystem == "galactic":
            self.axes.coords['glon'].set_ticks(color=self.primAxesColor, spacing=self.dl)
            self.axes.coords['glat'].set_ticks(color=self.primAxesColor, spacing=self.db)
            self.axes.coords['glat'].set_major_formatter(self.bFormat)
            self.axes.coords['glon'].set_major_formatter(self.lFormat)
            self.axes.coords['glon'].set_axislabel(r'$l[^\circ]$', fontsize=self.axisfontsize)
            self.axes.coords['glat'].set_axislabel(r'$b[^\circ]$', fontsize=self.axisfontsize)
            self.axes.tick_params(axis='both', which='major', labelsize=self.tickfontsize)


            if self.showGrid:
                self.axes.coords.grid(color=self.primAxesColor, linestyle='solid')

            if self.overPlotAltAxes:
                self.cbarPos = 0.91
                self.overlay = self.axes.get_coords_overlay('fk5')
                self.overlay['ra'].set_ticks(color=self.altAxesColor,  spacing=self.dra)
                self.overlay['dec'].set_ticks(color=self.altAxesColor, spacing=self.ddec)
                self.overlay['ra'].set_axislabel(r'$\alpha_{\mathrm{J2000}}$',  fontsize=self.axisfontsize)
                self.overlay['dec'].set_axislabel(r'$\delta_{\mathrm{J2000}}$', fontsize=self.axisfontsize)
                self.overlay['ra'].set_major_formatter(self.raFormat)
                self.overlay['dec'].set_major_formatter(self.decFormat)
                self.overlay.grid(color=self.altAxesColor, linestyle='--')
                self.axes.tick_params(axis='both', which='major', labelsize=self.tickfontsize)
        else:
            print ('Unknown coordinate system {0:s}, please check').format(self.coordSystem)        

    def _setAxisRange(self):
        '''
        Set the axes range.  This class takes either the min and max ranges in from the user or
        sets them accordingly from the file.  Since it works from the "real world" numbers backwards
        it might result in white space at the edges but I view that as preferable to having an ugly code
        if only want to give eg a min and use the map max.
        '''
        if self.coordSystem == "icrs":
            if not "ramin" in vars(self):
                if "RA" in self._header['CTYPE1']:
                    self.ramin = self._header['CRVAL1'] - self._header['CRPIX1'] * self._header['CDELT1'] * -1
                else:
                    self.ramin = self._header['CRVAL2'] - self._header['CRPIX2'] * self._header['CDELT2']
            elif type(self.ramin) == u.quantity.Quantity:
                self.ramin = self.ramin.to(u.deg).value

            if not 'ramax' in vars(self):
                if "RA" in self._header['CTYPE1']:
                    self.ramax = self._header['CRVAL1'] + (self._header['NAXIS1'] - self._header['CRPIX1']) * \
                                self._header['CDELT1'] * -1
                else:
                    self.ramax = self._header['CRVAL2'] + (self._header['NAXIS2'] - self._header['CRPIX2']) * \
                                    self._header['CDELT2']  
            elif type(self.ramax) == u.quantity.Quantity:
                self.ramax = self.ramax.to(u.deg).value

            if not "decmin" in vars(self):
                if "RA" in self._header['CTYPE1']:
                    self.decmin = self._header['CRVAL2'] - self._header['CRPIX2'] * self._header['CDELT2']
                else:
                    self.decmin = self._header['CRVAL1'] - self._header['CRPIX1'] * self._header['CDELT1'] * -1
            elif type(self.decmin) == u.quantity.Quantity:
                self.decmin = self.decmin.to(u.deg).value

            if not 'decmax' in vars(self):
                if "RA" in self._header['CTYPE1']:
                    self.decmax = self._header['CRVAL2'] + (self._header['NAXIS2'] - self._header['CRPIX2']) * \
                                    self._header['CDELT2']        
                else:
                    self.decmax = self._header['CRVAL1'] + (self._header['NAXIS1'] - self._header['CRPIX1']) * \
                                    self._header['CDELT1'] * -1
            elif type(self.decmax) == u.quantity.Quantity:
                self.decmax = self.decmax.to(u.deg).value
                        
            pramin, pdecmin = self._w.all_world2pix(self.ramin, self.decmin, 1)
            pramax, pdecmax = self._w.all_world2pix(self.ramax, self.decmax, 1)
            arrayShape = np.shape(self._data)

            # lazy check to make sure that we dont have white space at the edges
            if pramin > arrayShape[1]:
                pramin = arrayShape[1]
            if pdecmax > arrayShape[0]:
                pdecmax = arrayShape[0]
            if pramax < 0:
                pramax = 0
            if pdecmin < 0:
                pdecmin = 0
                
            self.axes.set_xlim(pramax, pramin) # this produces axes that cover the whole range of the fits figure
            self.axes.set_ylim(pdecmin, pdecmax)

            # since we are working with WCS axes I have not managed to get the "standard"
            # tricks for adding a color bar to work.
            # this is used in a fudge later that seems to work
            self.aspectRatio = (float(pdecmax) - pdecmin) / (pramin - pramax) 
          
        elif self.coordSystem == "galactic":
            if not "lmin" in vars(self):
                self.lmin = self._header['CRVAL1'] - self._header['CRPIX1'] * self._header['CDELT1'] * -1
            elif type(self.lmin) == u.quantity.Quantity:
                self.lmin = self.lmin.to(u.deg).value

            if not 'lmax' in vars(self):
                self.lmax = self._header['CRVAL1'] + (self._header['NAXIS1'] - self._header['CRPIX1']) * \
                            self._header['CDELT1'] * -1
            elif type(self.lmax) == u.quantity.Quantity:
                self.lmax = self.lmax.to(u.deg).value

                    
            if not "bmin" in vars(self):
                self.bmin = self._header['CRVAL2'] - self._header['CRPIX2'] * self._header['CDELT2']
            elif type(self.bmin) == u.quantity.Quantity:
                self.bmin = self.bmin.to(u.deg).value

            if not 'bmax' in vars(self):
                self.bmax = self._header['CRVAL2'] + (self._header['NAXIS2'] - self._header['CRPIX2']) * \
                            self._header['CDELT2']
            elif type(self.bmax) == u.quantity.Quantity:
                self.bmax = self.bmax.to(u.deg).value


            plmin, pbmin = self._w.all_world2pix(self.lmin, self.bmin, 1)
            plmax, pbmax = self._w.all_world2pix(self.lmax, self.bmax, 1)
            
            # lazy check to make sure that we dont have white space at the edges
            arrayShape = np.shape(self._data)
            if plmin > arrayShape[1]:
                plmin = arrayShape[1]
            if pbmax > arrayShape[0]:
                pbmax = arrayShape[0]
            if plmax < 0:
                plmax = 0
            if pbmin < 0:
                pbmin = 0
            
            self.axes.set_xlim(plmax, plmin) # this produces axes that cover the whole range of the fits figure
            self.axes.set_ylim(pbmin, pbmax)

            # since we are working with WCS axes I have not managed to get the "standard"
            # tricks for adding a color bar to work.
            # this is used in a fudge later that seems to work
            self.aspectRatio = (float(pbmax) - pbmin) / (plmin - plmax) 
    
        else:
            print ('Unknown coordinate system {0:s}, please check').format(self.coordSystem)

    def _setupAxes(self):
        '''
        This does all of the grunt work setting up the shapes of the axes and ticks,
        especially for the colorbar.
        '''
        self._setAxisRange()
        self._addAxes()

        if self.showColorbar:
            # since we are working with WCS axes I have not managed to get the "standard"
            # tricks for adding a color bar to work.
            # the aspect ratio is set using the number of pixels in each dimension
            self.cax = self.fig.add_axes([self.cbarPos, 0.5 - self.aspectRatio * 0.4,
                                          0.02, 0.79 *self.aspectRatio])
            self.cbar   = self.fig.colorbar(self.im, cax = self.cax)

            if not self.cbarLabel is None:
                self.cbar.set_label(self.cbarLabel)
            else:
                if 'EXTNAME' in self._header:
                    self.cbar.set_label(self._header['EXTNAME'])
                else:
                    self.cbar.set_label("Arbritray Units")
                    
            if "cbarLim" in vars(self):
                self.cbar.set_clim(self.cbarLim)

            if "cbarticks" in vars(self):
                self.cbar.set_ticks(self.cbarticks)

            if "cbarticklabels" in vars(self):
                self.cbar.set_ticklabels(self.cbarticklabels)


    def loadArray(self, data, header):
        '''
        load an array and a header  N.B. this does not handle data cubes, 
        these need to be processed prior to plotting to plot

        inputs
        ------
        data   = input data array (2D)
        header = header associated with data array
        '''
        self._data   = data
        self._header = header
        self._w = WCS(self._header)
        
        # use this as a check on the projection of the data
        if ('GLON' in self._header['CTYPE1']) or ('GLON' in self._header['CTYPE2']):
            self.coordSystem = "galactic"
        
    def loadFITS(self, fitsFile, hdu=0):
        '''
        load a fits file.  N.B. this does not handle data cubes, 
        these need to be processed prior to plotting to plot

        inputs
        ------
        fitsFile = input fits file
        hdu      = hdu to plot, can be index or name
        '''

        # use this as a check on the projection of the data
        self._data, self._header = fits.getdata(fitsFile, hdu, header=True)
        self._w = WCS(self._header)

        # use this as a check on the projection of the data
        if ('GLON' in self._header['CTYPE1']) or ('GLON' in self._header['CTYPE2']):
            self.coordSystem = "galactic"
            
    def plotMap(self, **kwargs):
        '''
        Plot the map.  Additional kwargs for plotting can be set here and passed
        to ax.imshow
        
        For the full list of variables that can be set it is best to read the code,
        I define some of them here.
        Note:  options for imshow such as interpolation can also be passed

        stretch         : none/sqrt/log (in theory any of the astropy stretches could be added)
        smooth          : perform Gaussian smoothing. Set to desired sigma in deg.
        
        setNaNtoValue   : if not False then sets NaNs to this value
        dl/db/dra/ddec  : spacing of ticks on axes (requires astropy unit i.e. 1*u.deg)
        vmin/vmax       : set the z scale
        cmap            : set the colormap, else the default is used (which should be ds9b)
        showGrid        : overplot a grid on the skymap
        overPlotAltAxes : add second grid for alternate axes (eq for gal and gal for eq)
        altAxesColor    : color for alt axes grid/tick
        primAxesColor   : color for primary axes grid/tick
        figsize         : figuresize for plot
        axisfontsize    : font size for axes labels
        tickfontsize    : font size for tick labels
        cbarLabel       : set label for colorbar
        cbarLim         : set limits for colorbar
        cbarticks       : set colorbar ticks
        cbarticklabels  : set colorbar tick labels
        ramin/ramax (etc) : set as astropy units qunatities
        '''
        
        for key, value in kwargs.items():
            setattr(self, key, value)            
            
        if not self.setNaNtoValue is False:
            self._data[np.invert(np.isfinite(self._data))] = self.setNaNtoValue
        
        if not self.smooth is False:
            self._data = self._data.astype("float")
            gauss      = Gaussian2DKernel(stddev=(float(self.smooth)/np.abs(self._header['CDELT1'])))
            self._data = convolve_fft(self._data, gauss)
        
        # I would like to be able to pass a figure or an axes to this but I dont have the time to fiddle with 
        # this at the moment - one for the future when I need it!

        # if not "fig" in vars(self):
        self.fig = plt.figure(figsize=self.figsize)
        # if not "axes" in vars(self):
        self.axes = self.fig.add_axes([0.15, 0.1, 0.7, 0.8], projection=self._w)

        interval = MinMaxInterval()
        vmin, vmax = interval.get_limits(self._data)
        if not "vmin" in vars(self):
            self.vmin = np.nanmin(self._data)
        if not "vmax" in vars(self):
            self.vmax = np.nanmax(self._data)
            
        # Create interval object
        if self.stretch == "sqrt":
            print ('rescale to sqrt stretch')
            print ('if you havent already consider setting your own cbarticks and cbarticklabels')
            norm = ImageNormalize(vmin=self.vmin, vmax=self.vmax, stretch=SqrtStretch())
            self.norm = norm
        elif self.stretch == "log":
            print ('rescale to log stretch')
            print ('if you havent already consider setting your own cbarticks and cbarticklabels')
            norm = ImageNormalize(vmin=self.vmin, vmax=self.vmax, stretch=LogStretch())
            self.norm = norm
        elif self.stretch != "none":
            print ('I dont know what stretch you want me to do so I am not doing anything!')


        self.im = self.axes.imshow(self._data, origin="lower left", 
                                  **{key: vars(self)[key] for key in vars(self) 
                                        if (key in plt.imshow.__code__.co_varnames)})
        self._setupAxes()
        self.fig.set_facecolor("w")

    def overplotContoursArray(self, contData, contHeader, smooth = False, label = None, zorder = 1, **kwargs):
        '''
        Overplot contours from a np.array and it associated header.
        kwargs are passed to contour plotter (takes plt.contour kwargs).
        levels are calculated automaically but can be passed using the keyword levels
        
        If label is set then an entry is added to the legend.
        smooth is the stddev of the smoothing gaussian if given (in deg)
        '''

        if not smooth is False:
            gauss = Gaussian2DKernel(stddev=(float(smooth)/np.abs(contHeader['CDELT1'])))
            contData = convolve_fft(contData, gauss)

        c = self.axes.contour(contData, transform=self.axes.get_transform(WCS(contHeader)), 
                              zorder = zorder, **self._checkKwargs(plt.contour, kwargs))
        if not "conts" in vars(self):
            self.contours = []

        self.contours.append(c)
        
        if not label is None:
            if not ("legLines" in vars(self) and "legLabels" in vars(self)):
                self.legLines  = []
                self.legLabels = []

            self.legLines.append(mlines.Line2D([], [], **self._checkKwargs(mlines.Line2D, kwargs)))
            self.legLabels.append(label)

    def overplotContoursFitsFile(self, fitsFile, hdu = 0, smooth = False, label = None, **kwargs):
        '''
        Read in a fits file and overplot the contours.  kwargs are passed to 
        both the fits reader and to the contour plotter.
        
        If label is set then an entry is added to the legend.
        smooth is the stddev of the smoothing gaussian if given (in deg)
        '''

        contData, contHeader = fits.getdata(fitsFile, hdu, header=True,
                                                **{key: kwargs[key] for key in kwargs 
                                                    if (key in fits.getdata.__code__.co_varnames)})

        self.overplotContoursArray(contData, contHeader, smooth = smooth, label = label, **kwargs)
        
    def overplotMarkers(self, xList, yList, coordsys = 'icrs', zorder = 5, **kwargs):
        '''
        Plot a list of markers with a single label.
        
        inputs:
        -------
        xList - xcoordinate locations (ra, l)
        yList - ycoordinate locations (dec, b)
        coordsys - coordinate system (icrs/galactic)
        
        kwargs are from plt.scatter and can include label, markers etc.
        '''
        self.axes.scatter(xList, yList, transform=self.axes.get_transform(coordsys), 
                          zorder = zorder, **kwargs)
    
    def overplotMarkersLabelledList(self, xList, yList, labList, coordsys = 'icrs', zorder = 5, **kwargs):
        '''
        Plot a list of markers with a list of individual labels.  
        n.b. this uses the same marker etc for each one
        
        inputs:
        -------
        xList - xcoordinate locations (ra, l)
        yList - ycoordinate locations (dec, b)
        coordsys - coordinate system (icrs/galactic)
        
        kwargs are from plt.scatter and can include label, markers etc.
        '''
        if len(xList) == len(yList) == len(labList):
            for x, y, lab in zip(xList, yList, labList):
                self.axes.scatter(x, y, label = lab, 
                                  transform=self.axes.get_transform(coordsys), 
                                  zorder = zorder, **kwargs)
                
    def plotLegend(self, loc="best", legendFaceColor = "w", legendTextColor = "k", 
                   scatterpoints=1, fontsize = 10, ncol = 2, markerscale = 0.8, **kwargs):
        '''
        Plot an plt.legend instance, some defaults are given here that I like 
        but it will also take the kwargs from the class
        '''
        legLines, legLabels = self.axes.get_legend_handles_labels()

        if  ("legLines" in vars(self)) and ("legLabels" in vars(self)):
            self.legLines  = legLines  + self.legLines
            self.legLabels = legLabels + self.legLabels
        else:
            self.legLines  = legLines
            self.legLabels = legLabels

        self.legendFaceColor = legendFaceColor
        self.legendTextColor = legendTextColor

        self.legendDictionary = {"loc" : loc,  "fontsize" : fontsize, "ncol" : ncol, 
                                 "scatterpoints" : scatterpoints, "markerscale" : markerscale}
        self.legendDictionary.update(kwargs)

        self._plotLegendToAxes()

    def switchLegendEntries(self, a, b):
        '''
        This function reverses the positions of legend elements a and b in the legeend.
        If called this will 
        '''
        self.legLines[b], self.legLines[a] = self.legLines[a], self.legLines[b]
        self.legLabels[b], self.legLabels[a] = self.legLabels[a], self.legLabels[b]
        self._plotLegendToAxes()

        
    def _plotLegendToAxes(self):  
        '''
        The final act of plotting is done here so if the legend entries are switched this can 
        be recalled and will overplot the existing legend.
        '''
        
        self.legend = self.axes.legend(self.legLines, self.legLabels, **self.legendDictionary)

        self.legend.get_frame().set_facecolor(self.legendFaceColor)
        for text in self.legend.get_texts():
            text.set_color(self.legendTextColor)

    def addPSF(self, x, y, text=None, psf = 0.1*u.deg, col = "k", lw = 2, facecolor='none', zorder = 8, 
               fontsize = 10, fontweight = "bold", **kwargs):
        '''
        Add a PSF circle at the specified location (in l,b or ra,dec as appropriate).
        Units must be given.
        
        Inputs:
        -------
        x, y : center of circle
        text : none|left|right position of text (PSF) relative to circle
        psf  : size of psf circle
        '''
        dx = psf / np.cos(y.to(u.radian).value) * 1.1
        
        psf = SphericalCircle((x, y), psf,
                             edgecolor=col, facecolor=facecolor, lw=lw, zorder=zorder,
                             transform=self.axes.get_transform(self.coordSystem), )

        self.axes.add_patch(psf)
        if text == "right":
            self.axes.text((x - dx).to(u.deg).value, y.to(u.deg).value, "PSF",
                            transform=self.axes.get_transform(self.coordSystem), 
                            fontsize=10, fontweight="bold", color=col, 
                            ha="left", va="center")
        elif text == "left":
            self.axes.text((x + dx).to(u.deg).value, y.to(u.deg).value, "PSF",
                            transform=self.axes.get_transform(self.coordSystem), 
                            fontsize=fontsize, fontweight=fontweight, color=col, 
                            ha="right", va="center")

    def addEllipse(self, x, y, sma = 0.1*u.deg, smi = 0.1*u.deg, rotation = 0*u.deg,
                   zorder = 4, edgecolor = "black", facecolor = "none", linewidth = 2, 
                   linestyle = "-", **kwargs):
        '''
        This function plots an ellipse e.g. to show an extension.  It correctly handles spherical coordinates.
        
        Notes: Units must be given         
        
        inputs:
        -------
        x, y     : center of ellipse
        sma, smi : semimajor and semi minor axes
        rotation : is clockwise from the semimajor aligned along the x axis (i.e. b/dec = const)
        kwargs are for a matplotlib.patches.Ellipse
        '''
        
        ellipse = Ellipse((x.to(u.deg).value, y.to(u.deg).value), 
                          sma.to(u.deg).value, smi.to(u.deg).value, rotation.to(u.deg).value, 
                          transform=self.axes.get_transform(self.coordSystem), zorder=zorder,
                          edgecolor=edgecolor, facecolor=facecolor, linewidth=linewidth, 
                          linestyle=linestyle, **kwargs)
        self.axes.add_patch(ellipse)
        
    def addText(self, x, y, text, ha = "left", va = "center", zorder=6,
                fontsize=10, fontweight="bold", color="k", **kwargs):
        '''
        Add text at the location x, y (where x = l/ra, y = b/dec, units must be given)
        
        kwargs are passed to plt.text
        '''
        self.axes.text(x.to(u.deg).value, y.to(u.deg).value, text, ha=ha, va=va,
                       transform=self.axes.get_transform(self.coordSystem), zorder = zorder,
                       fontsize=fontsize, fontweight=fontweight, color=color, **kwargs)




    def _checkKwargs(self, function, kwDict):
        '''
        This is a nasty function which I have produced to ensure that the correct kwargs are passed.
        Annoyingly, function.__code__.co_varnames does not give all the kwargs that I would expect
        it to so for some functions I have had to add an additional check to a list that I have 
        generated from the matplotlib documentation.  If anyone knows a better way then PLEASE tell me!
        
        Inputs:
        -------
        function - the function to be used, pass as function not a string
        kwDict   - a dictionary of all of the possible kwargs that could be passed to the function
        
        Returns:
        --------
        retkwDict - a dictionary of the kwargs that the function accepts (to the best of this functions knowledge)
        '''
        retkwDict = {}
        if function  == plt.contour:
            contourKwargs = ["corner_mask", "colors", "alpha", "cmap", "norm", 
                             "vmin", "vmax", "levels", "origin", "extent", "locator", 
                             "extend", "xunits", "yunits", "antialiased", "nchunk", 
                             "linewidths", "linestyles", "zorder"] 
            for k in kwDict.keys():
                if (k in contourKwargs) or (k in function.__code__.co_varnames):
                    retkwDict[k] = kwDict[k]
        elif function == mlines.Line2D:
            # mlines.Line2D is used a lot for legends but takes different key words, so this is the "correction"
            # it only uses the first value of any lists so e.g. if the line colors vary with level then
            # this will not pick that up, if you want that you will have to code that yourself.
            for k in kwDict.keys():
                if k == "colors":
                    retkwDict['color'] = kwDict[k]
                elif k == "linwidths":
                    retkwDict['linewidth'] = kwDict[k]
                elif k == "linestyles":
                    retkwDict['linestyle'] = kwDict[k]
        else:
            for k in kwDict.keys():
                if k in function.__code__.co_varnames:
                    retkwDict[k] = kwDict[k]
        return retkwDict

    def overplotDS9Regions(self, ds9RegFile, patchLineColor="k", patchLineWidth=2, plotText = False):
        '''
        Overplot a ds9 region file
        '''
        r2 = pyregion.open(ds9RegFile).as_imagecoord(self._w)
        patch_list, artist_list = r2.get_mpl_patches_texts()

        for p in patch_list:
            p.set_edgecolor(patchLineColor)
            p.set_linewidth(patchLineWidth)
            self.axes.add_patch(p)
        if plotText:
            for t in artist_list:
                t.set_color(patchLineColor)
                t.set_ha("left")
                self.axes.add_artist(t)

    def addTitle(self, title = "Title"):
        '''
        Add a title to a plot
        '''
        self.axes.set_title(title)


class sigDistPlotter():
    '''
    A class to plot signifcance distributions, either all on a single plot or as four separate plots
    in a single figure.

    settings can be checked using sigDistPlotter.printAttr()
    '''
    def __init__(self, **kwargs):
        '''nothing to init'''
        self.colors = ['k', 'b', 'g', 'purple']
        self.normcolor = 'r'
        self.fitxloc = 0.95
        self.fityloc = 0.7
        self.figsize = (10,10)
        
        for key, value in kwargs.items():
            setattr(self, key, value)  
        
    def printAttr(self):
        '''
        This simply dumps all of the attributes that are currently set, 
        useful to see what is going on "under the hood" and give ideas for
        variables that can be changed'''
        pprint (vars(self))

    def loadFITSfile(self, fitsFile):
        ''' 
        Load fits file with the data - at the moment this assumes VEGAS.
        '''
        ff = fits.open(fitsFile)
        self.sigDistTable = ff['Significance Distributions'].data
        
        self.sigmas          = self.sigDistTable['Sigma'][1:]
        self.countsAll       = self.sigDistTable['Counts'][1:]
        self.countsExcStars  = self.sigDistTable['CountsMinusStars'][1:]
        self.countsExcSource = self.sigDistTable['CountsMinusSource'][1:]
        self.countsExcAll    = self.sigDistTable['CountsMinusAll'][1:]
        
        self.totExcAll   = np.nansum((self.countsExcAll).astype(float) * 
                                     ((self.sigmas[2]).astype(float) - self.sigmas[1]))
        self.meanExcAll  = np.nanmean((self.countsExcAll))
        self.stdevExcAll = np.std(np.isfinite(self.countsExcAll))
        
    def _plotCommon(self, legend = True, fontsize = 10, **kwargs):
        plt.plot(self.sigmas[1:], norm.pdf(self.sigmas[1:]) * self.totExcAll, 
                 color = self.normcolor, label="Normal Distribution")
        
        plt.semilogy(nonposy="clip")
        ylow, yhigh = plt.gca().get_ylim()
        ymax = np.nanmax(self.countsAll)
        if yhigh > (3*ymax):
            yhigh = round_to_n(3*ymax, 1)
        plt.ylim(0.5, yhigh)
        
        if legend:
            plt.legend(loc="upper right", fontsize = fontsize)
        plt.xlabel('Significance')
        plt.ylabel('Number of Bins')
        
    def plotSingleFigure(self, plot = "all", title = None,
                         plotFit = True, **kwargs):
        '''
        Plot the signficance distributions on a single axes.
        
        inputs:
        -------
        plot = all| list of ['excNone', 'excStars', 'excSource', 'excAll']
        '''
        fig = plt.figure(figsize=self.figsize)
        
        if plot == "all":
            self.plot = ['excNone', 'excStars', 'excSource', 'excAll']
        else:
            self.plot = plot
            
        for i,p in enumerate(self.plot):
            if p == "excNone":
                plt.step(self.sigmas, self.countsAll, color = self.colors[i], label = "All Bins")
            elif p == "excStars":
                plt.step(self.sigmas, self.countsExcStars, color = self.colors[i], label = "Exc. Stars")
            elif p == "excSource":
                plt.step(self.sigmas, self.countsExcSource, color = self.colors[i], label = "Exc. Source")
            elif p == "excAll":
                plt.step(self.sigmas, self.countsExcAll, color = self.colors[i], label = "Exc. Source & Stars")
            else:
                print ("Unknown distribution to plot {0:s}").format(p)
        
        self._plotCommon(**kwargs)
        if not title is None:
            plt.title(title)

        if plotFit:
            self.fitSigDist(self.countsExcAll, **kwargs)

    def plotFourFigures(self, **kwargs):
        '''
        Plot the signficance distributions on a series of subplots.
        '''
        fig = plt.figure(figsize=self.figsize)

        plt.subplot(2,2,1)
        plt.step(self.sigmas, self.countsAll, color = self.colors[0])
        self._plotCommon(legend=False, **kwargs)
        plt.title("All Bins")
        
        plt.subplot(2,2,2)
        plt.step(self.sigmas, self.countsExcStars, color = self.colors[1])
        self._plotCommon(legend=False, **kwargs)
        plt.title("Exc. Stars")
        
        plt.subplot(2,2,3)
        plt.step(self.sigmas, self.countsExcSource, color = self.colors[2])
        self._plotCommon(legend=False, **kwargs)
        plt.title("Exc. Source")
        
        plt.subplot(2,2,4)
        plt.step(self.sigmas, self.countsExcAll, color = self.colors[3])
        self._plotCommon(legend=False, **kwargs)
        plt.title("Exc. Source & Stars")

        plt.tight_layout()

    def _printGausFit(self):
        '''Prints the parameters of the Guassian fit in a nice format'''
        self.err = np.sqrt(np.diag(self.pcov))
        text1 = "Mean    = {0:.3f} +/- {1:.3f} \n".format(self.popt[1], self.err[1])
        text2 = "Std Dev = {0:.3f} +/- {1:.3f}".format(self.popt[2], self.err[2])
        return text1 + text2

    def fitSigDist(self, counts, 
                   horizontalalignment="right", verticalalignment = "center", 
                   fontsize = 8, **kwargs):
        '''
        Add fit to existing plot.
        kwargs are for an axes.text object
        
        '''
        binCenters = (self.sigmas[0:-1] + self.sigmas[1::])/2
        self.popt, self.pcov = curve_fit(_gaus, self.sigmas, counts, p0=[self.totExcAll, 0., 1.])
        text = self._printGausFit()
        bbox = dict(boxstyle='square', facecolor='white')
        ax = plt.gca()
        ax.text(self.fitxloc, self.fityloc, text, transform=ax.transAxes, 
                horizontalalignment = horizontalalignment, verticalalignment = verticalalignment, 
                bbox=bbox, fontsize = fontsize)

def round_to_n(x,n=3):
    '''rounds float to n significant figures
    returns as int if there are no decimals'''
    val = round(x, n-1-int(np.floor(np.log10(abs(x)))))
    if val.is_integer():
        return int(val)
    else:
        return val

class spectrumPlotter(object):
    '''
    At the moment this is setup to read in a VEGAS log file, ROOT file, or CSV file and plot out the spectrum. 
    In time I would like to get the data saved into fits files so it can plot them instead but hey ho!
    New spectrumPlotter instances should be made for each new spectrum
    '''
    
    # define a custom physical type for units
    u.def_physical_type(u.TeV**-1*u.cm**-2*u.s**-1, 'differential flux density')
    u.def_physical_type(u.TeV*u.cm**-2*u.s**-1, 'E2 flux density')
    
    # define our line fitting function
    fitfunc = staticmethod( lambda p, x: p[0] + p[1] * (x) ) 
    errfunc = staticmethod( lambda p, x, y, err: (y - spectrumPlotter.fitfunc(p, x)) / err ) 

    # define our () fitting function; np.log is natural log 
    fitfuncECPL = staticmethod( lambda p, x: p[0] + p[1] * np.log(x) - (x) / p[2] ) 
    errfuncECPL = staticmethod( lambda p, x, y, err: (np.log(y) - spectrumPlotter.fitfuncECPL(p, x)) / (err) )
    fitfuncECPL_CF = staticmethod( lambda N0, gamma, beta, E: N0 + gamma*E - 1.*np.exp(E) / beta )

    #these are just copied from http://fermi.gsfc.nasa.gov/ssc/data/analysis/scitools/python_tutorial.html
    f = staticmethod( lambda E, N0, E0, gamma: N0*(E/E0)**(-1.*gamma) )
    ferr = staticmethod( lambda E, F, N0, N0err, E0, cov_gg: \
                    F*np.sqrt(N0err**2/N0**2 + ((np.log(E/E0))**2)*cov_gg) )

    f_ecpl = staticmethod( lambda E,N0,E0,gamma,beta: N0*(E/E0)**(-1.*gamma)*np.exp(-1.*E/beta) )
    ferr_ecpl = staticmethod( lambda E, F, N0, N0err, E0, cov_gg, b, cov_bb: \
                F*np.sqrt(N0err**2/N0**2 + ((np.log(E/E0))**2) * cov_gg + (E/E0)**2 / b**4 * cov_bb) )

    
    def __init__(self, **kwargs):
        """initialize spectrum, setting defaults for units, energy power, etc"""
        
        self.energyUnits = u.TeV
        self.sedUnits = self.energyUnits**-1 * u.s**-1 * u.cm**-2
        self.e2fluxUnits = self.energyUnits * u.s**-1 * u.cm**-2
        self.unitDict = {
                            self.energyUnits.physical_type : self.energyUnits , 
                            self.sedUnits.physical_type : self.sedUnits,
                            self.e2fluxUnits.physical_type : self.e2fluxUnits
        }

        self.energyBinMinSignificance = 2.
        self.energyBinMinExcess       = 5.
        
        self.energyPower = 2
        self.fontsize = 20 
        
        self.c = 'red' # will be overwritten by kwargs if provided 
        
        self.kwargs = kwargs 
        for key, value in kwargs.items():
            setattr(self, key, value)
            
    # init 
            
    
    def printAttr(self):
        '''
        This simply dumps all of the attributes that are currently set, 
        useful to see what is going on "under the hood" and give ideas for
        variables that can be changed'''
        pprint (vars(self))
    
    def readVEGASLog(self, logfileName):
        infile = open(logfileName)

        # The below variables are used to control the text file read in.
        copy      = False
        specFit   = True
        covMat    = False
        outstring = ""
        for line in infile:
            if "STATUS=PROBLEMS" in line:
                print "There was an issue with the spectrum.  Diagnose the issue and rerun."
                print line
                specFit = False
            elif line.startswith("  Bin"):
                copy = True
                spec = True
            elif line.startswith(" FCN"):
                copy = False
            elif line.startswith("Error in <TAxis::TAxis::Set>"):
                copy = False
            elif line.startswith("Calculating upper limit at the central"):
                copy = False
            elif line.startswith("+++ SP: found non-signal"):
                copy = False
            elif line.startswith("+++ SP: ERROR:"):
                print "There was an issue with the spectrum.  Diagnose the issue and rerun."
                copy = False
                specFit = False
            elif "SP: W" in line:
                print "There was a warning.  It way not be terminal but please check."
                print line
                copy = False
            elif copy:
                outstring += line
            elif line.startswith("   1  Norm") or line.startswith("   1  Parameter0"):
                if specFit:
                    N0    = (float(line.split()[2])/u.TeV/u.m/u.m/u.s).to(self.sedUnits).value
                    N0err = (float(line.split()[3])/u.TeV/u.m/u.m/u.s).to(self.sedUnits).value
                    self.norm  = np.array([N0, N0err])
            elif line.startswith("   2  Index") or line.startswith("   2  Parameter1"):
                if specFit:
                    I     = np.abs(float(line.split()[2]))
                    Ierr  = float(line.split()[3])
                    self.index = [I, Ierr]
            elif line.startswith("   3  Parameter2"):
                if specFit:
                    b     = float(line.split()[2])
                    berr  = float(line.split()[3])
                    self.beta = [b, berr]
            elif line.startswith("   3  E_{0}"):
                if specFit:
                    self.E0 = [(float(line.split()[2])*u.TeV).to(self.energyUnits).value, 0.]
            elif line.startswith("EA: fitFunction initialized"):
                if specFit:
                    self.E0 = [0., 0.]#[(float(line.split("x/")[1].split(",")[0])*u.TeV).to(self.energyUnits).value, 0]
            elif "Covariance Matrix:" in line:
                covMat = True
                self.cov = []
            elif (line.startswith("Parameter0  ")  or line.startswith("Norm")) and covMat:
                self.cov.append((float(line.split()[2])/u.TeV/u.m/u.m/u.s).to(self.sedUnits).value) #cov ab

            # this needs a check for spectra other than PL for now
            # elif (line.startswith("Parameter2")  or line.startswith("Index")) and covMat:
            #     self.cov.append((float(line.split()[1])/u.TeV/u.m/u.m/u.s).to(self.sedUnits).value) # cov ac
            #     self.cov.append(float(line.split()[2])) # cov bc - note these are both powers- no scale factor
            elif line.startswith("Correlation Matrix:"):
                covMat = False
            elif line.startswith("Chi2                      ="):
                self.chi2 = float(line.split()[2])
            elif line.startswith("NDf                       ="):
                self.NDF  = float(line.split()[2]) 
            elif line.startswith("* Upper limit"):
                temp = line.split()
                UL0 = (float(temp[3])/u.TeV/u.m/u.m/u.s).to(self.sedUnits).value
                UL1 = (float(temp[8])*u.TeV).to(self.energyUnits).value
                self.UL = [UL0, UL1]
                
        if spec:
            outstring = outstring.split('\n') 
            numSkip=0
            t = ascii.read(outstring, Reader=ascii.FixedWidthNoHeader, 
                           col_starts=(3, 7, 15, 24, 34, 43, 48, 55, 63, 72, 79, 85, 95),
                           names=['Bin', 'Energy', 'Eerror', 'Flux', 'Ferror', \
                                  'Non', 'Noff', 'Nexcess', 'RawOff', 'Alpha', \
                                  'Sig',  'LowEdge', 'HighEdge'])
            self.t = t
            t['Energy'] = (t['Energy']*u.TeV).to(self.energyUnits).value
            t['Flux']   = (t['Flux']/u.TeV/u.m/u.m/u.s).to(self.sedUnits).value
            t['Ferror'] = (t['Ferror']/u.TeV/u.m/u.m/u.s).to(self.sedUnits).value
            t['LowEdge']  = (t['LowEdge']*u.TeV).to(self.energyUnits).value
            t['HighEdge'] = (t['HighEdge']*u.TeV).to(self.energyUnits).value

            t['LowEdge'] = [round_to_n(i,n=3) for i in t['LowEdge']]
            t['HighEdge'] = [round_to_n(i,n=3) for i in t['HighEdge']]
            
            self.t = t
            
            cond = (t['Sig'] > self.energyBinMinSignificance) & (t['Nexcess'] > self.energyBinMinExcess)
            
            self.fluxPoints   = [t['Energy'][cond], t['Flux'][cond], t['Ferror'][cond]]
            self.energyRange  = [t['LowEdge'][cond][0], t['HighEdge'][cond][-1]]
            
            cond = Column(cond, name='Plot')
            self.t.add_column(cond, index=0)
            
            return self.t
    # readVEGASLog
            
    def readVEGASs6Root(self, rootfilename):
        """Extracts the spectral information from a VEGAS ROOT stage 6 file
        Sets the spectral points and the fit parameter, including the covariance matrix"""

        verbose = False # set to true to include 
        loadRootVegas()
        
        # open the file 
        s6F = TFile(rootfilename, "read")
        if not s6F.IsOpen():
            print "Could not open file! ", rootfilename
        specAn = s6F.Get("Spectrum/VASpectrumAnl")
        specGraph = specAn.GetSpectrumGraph()
        xaxis = specGraph.GetXaxis()
        #specHist = specAn.GetSpectrumHist()
        specHist = specAn.GetRebinnedSpectrumHist()
        
        alpha = specAn.GetRebinnedAlphaHist()
        sig = specAn.GetSigmaHist() # empty, this is calculated in MakeSpectrumGraph()
        
        # other spectral analysis objects 
        #hMM = s6F.Get("Spectrum/hMigrationMatrix")
        #hFEH = s6F.Get("Spectrum/hFullExcessHist")


        # extract the energy points, flux, errors
        npoints = specGraph.GetN()
        E, flux = [], []
        flux_err_low, flux_err_high = [], []
        Elow, Ehigh = [], []
        alpha = root_numpy.hist2array(alpha)
        for i in range(npoints):
            tmpE, tmpF = ROOT.Double(0), ROOT.Double(0)
            specGraph.GetPoint(i+1, tmpE, tmpF)
            
            if not tmpE > 0:
                continue 
            E.append(tmpE)
            flux.append(tmpF)
            flux_err_low.append(specGraph.GetErrorYlow(i+1))
            flux_err_high.append(specGraph.GetErrorYhigh(i+1))
            Elow.append(np.power(10, specHist.GetBinLowEdge(i)))
            #Ewidth.append(np.power(10, specHist.GetBinWidth(i)))
            Ehigh.append(np.power(10, specHist.GetBinLowEdge(i)+specHist.GetBinWidth(i)))
    
        # put into preferred units
        E = (np.array(E)*u.TeV).to(self.energyUnits).value
        Elow = (np.array(Elow)*u.TeV).to(self.energyUnits).value
        Ehigh = (np.array(Ehigh)*u.TeV).to(self.energyUnits).value
        flux = (np.array(flux)/u.TeV/u.m**2/u.s).to(self.sedUnits).value
        flux_err_low = (np.array(flux_err_low)/u.TeV/u.m**2/u.s).to(self.sedUnits).value
        flux_err_high = (np.array(flux_err_high)/u.TeV/u.m**2/u.s).to(self.sedUnits).value
        
        flux_err = np.asarray((flux_err_low, flux_err_high))
        
        #cond = (t['Sig'] > self.energyBinMinSignificance) & (t['Nexcess'] > self.energyBinMinExcess)
        #self.fluxPoints   = [t['Energy'][cond], t['Flux'][cond], t['Ferror'][cond]]
        #self.energyRange  = [t['LowEdge'][cond][0], t['HighEdge'][cond][-1]]
        #cond = Column(cond, name='Plot')
        #self.t.add_column(cond, index=0)
 
                
        self.fluxPoints = [E, flux, flux_err]
        self.energyRange = (Elow[0], Ehigh[-1])
                

        # now get the fit parameters 
        
        tf1 = specGraph.GetFunction("fFitFunction")
        fitnorm = tf1.GetParameter(0)
        fitindex = tf1.GetParameter(1)
        normenergy = tf1.GetParameter(2)

        r = specGraph.Fit(tf1, "S") #TFitResultPtr
        cov = r.GetCovarianceMatrix() #TMatrixTSym<double>

        # the variances - errors are the sigma = sqrt(var)
        var_norm = cov(0, 0)
        var_index = cov(1, 1)
        cov_normindex = cov(0, 1) # == (1, 0)
        
        N0    = (fitnorm/u.TeV/u.m**2/u.s).to(self.sedUnits).value
        N0err = (np.sqrt(var_norm)/u.TeV/u.m**2/u.s).to(self.sedUnits).value
        self.norm  = np.array([N0, N0err])
        
        self.E0 = [(normenergy*u.TeV).to(self.energyUnits).value, 0.]
        
        self.index = [np.abs(fitindex), np.sqrt(var_index)]
        self.cov = [(cov_normindex/u.TeV/u.m**2/u.s).to(self.sedUnits).value]

        if verbose != False:
            print len(Elow)
            print self.E0
            print self.index
            print E
            print Elow
        
        #self.s6F = s6F
        s6F.Close()
        
    # ReadVEGASs6Root
    
    def readCSV(self, filename):
        """Creates an astropy ascii table from a TAB-separated variable file
        The top row should specify the names and the units, separated by a space
        The variable name should generally follow those found in VEGAS log files
        The units must be in a format parseable by astropy.units
        Example:
        Energy TeV	LowEdge TeV	HighEdge TeV	Flux TeV/(cm2.s)	Ferror_low TeV/(cm2.s)	Ferr_up TeV/(cm2.s)	E2F TeV/(m2.s)	E2Ferr_low TeV/(m2.s)	E2Ferr_up TeV/(m2.s)
        The values should come below in the standard tsv format
        
        Units will be automatically converted to your preferred type 
        """

        self.t = ascii.read(filename)

        for n in self.t.colnames:
            # parse and adjust units for consistency 
            ns = n.split()
            if len(ns) > 1: # unit is present 
                try: 
                    unit = u.Unit(ns[1])
                    #self.t[n].unit = unit 
                    if unit.physical_type in self.unitDict:
                        self.t[n] = (self.t[n]*unit).to(self.unitDict[unit.physical_type]).value
                    else:
                        print "Could not convert unit in ", ns
                        
                except ValueError:
                    print "No unit parseable in ", ns
                    #continue
                #else:
                #finally:

            # parse out column name, would be nice to have a way to display units in table though
            self.t.rename_column(n, ns[0]) 
    
        # could look for fit params 
        
        # set points 
        if 'Ferror_low' in self.t.colnames and 'Ferror_up' in self.t.colnames:
            flux_err = np.asarray((self.t['Ferror_low'], self.t['Ferror_up']))
        elif 'Ferror' in self.t.colnames:
            flux_err = np.asarray(self.t['Ferror'], self.t['Ferror'])
        else:
            flux_err = np.zeros(shape=(2,len(self.t['Energy'])))
            
        self.fluxPoints   = [self.t['Energy'], self.t['Flux'], flux_err]
        
        if 'LowEdge' in self.t.colnames and 'HighEdge' in self.t.colnames:
            self.energyRange = (self.t['LowEdge'][0], self.t['HighEdge'][-1])
        else:
            self.energyRange = (self.t['Energy'][0], self.t['Energy'][-1])
        
        return self.t
    # readCSV
    
    
    def calcPowerLawFluxes(self):
        self.energies = np.linspace(self.energyRange[0], self.energyRange[1], num=1000)
        self.calcPowerLawFlux()
        self.calcPowerLawFluxError()
        self.calcDecorrelationEnergy()
        
        
    def _plotCommon(self, pltLeg=True, **kwargs):
        '''Common configuration commands for setting up spectral plots'''
        
        plt.loglog(nonposy="clip")

        plt.xlabel("Energy[%s]" % self.energyUnits.to_string())
        plt.ylabel("E^%s Flux %s" % (self.energyPower,(self.energyUnits**self.energyPower*self.sedUnits).to_string()))
        
        if pltLeg: # plot legend 
            plt.legend(loc="best", fontsize=self.fontsize,
               **{key: kwargs[key] for key in kwargs if (key in plt.errorbar.__code__.co_varnames)})


    # _plotCommon 
 
    
    def plotSpectrum(self, pltPts=True, pltFit=True, norm=[1.00, 0.], label="", marker="+", ls="--",  
                     facecolor="none", ncol=1, numpoints=1, **kwargs):
        '''
        This plots the spectrum, at the moment I havent set up kwargs as they need to check to
        pass the correct kwargs to the correct plotting function.
        '''
        
        # handle arguments 
        pltLeg = False
        if label != "":
            pltLeg = True
                                
        v = vars(self)
        if 'c' in kwargs:
            c = kwargs['c']
        else:
            c = v['c'] 
        
        if "norm" in v and "index" in v:
            #label = label + "  N0={0:.2e} G={1:.2f}".format(self.norm[0], self.index[0])
            label = (label + ' - N0= {0:.2e} +- {2:.2e}, '\
                        'gam= {1:.2f} +- {3:.2f}, '\
                        'E0= {4:.2f}').format(float(self.norm[0]), float(self.index[0]), 
                                              float(self.norm[1]), self.index[1], self.E0[0])

        #else: pltFit = False # cannot plot fit without these params unless fitting is done 
            

        if pltPts: # plot the points 
    
            p = plt.errorbar(x = self.fluxPoints[0], 
                         y = self.fluxPoints[1]*self.fluxPoints[0]**self.energyPower, 
                         yerr = self.fluxPoints[2]*self.fluxPoints[0]**self.energyPower, 
                         marker=marker, ls="", label=label, c=c, 
                         **{key: kwargs[key] for key in kwargs 
                                        if (key in plt.errorbar.__code__.co_varnames)})
            label = "" # this prevents two labels appearing for same plot
        

        if pltFit: # plot the fit 
            self.calcPowerLawFluxes()
            
            p = plt.plot(self.energies, self.energies**self.energyPower*self.flux, 
                     c=self.c, ls=ls, label=label)

            plt.fill_between(self.energies, 
                             (self.energies**self.energyPower*(self.flux+self.fluxError)), 
                             (self.energies**self.energyPower*(self.flux-self.fluxError)), 
                             edgecolor=self.c, facecolor=facecolor)
            
            
            minRatio = self.fluxError[0] / self.flux[0]
            minE = self.energies[0]
            for i in xrange(1, len(self.energies)):
                iRatio = self.fluxError[i] / self.flux[i]
                if iRatio < minRatio:
                    minRatio = iRatio
                    minE = self.energies[i]
                
            print "energy that minimizes ratio of error to flux for fit: ", minE


            
        plt.loglog(nonposy="clip")

        plt.xlabel("Energy[%s]" % self.energyUnits.to_string())
        plt.ylabel("E^%s Flux %s" % (self.energyPower,(self.energyUnits**self.energyPower*self.sedUnits).to_string()))


        if pltLeg: # plot legend 
            plt.legend(loc="best", ncol=ncol, numpoints=numpoints, fontsize=self.fontsize,
                        **{key: kwargs[key] for key in kwargs 
                            if (key in plt.errorbar.__code__.co_varnames)})

        #return p 
    # plotSpectrum 


    def calcDecorrelationEnergy(self):
        '''
        set the decorrelation energy of a power law fit
        Requires the covariance matrix

        from FERMI OBSERVATIONS OF TeV-SELECTED ACTIVE GALACTIC NUCLEI
        '''
        if "cov" in vars(self):
            self.decorrelationEnergy = self.E0[0] * np.exp(self.cov[0]/(self.norm[0] * self.index[1]**2))
            
            if np.abs(self.E0[0] - self.decorrelationEnergy)/self.decorrelationEnergy > 0.05:
                print ("You are giving the normalization at {0:.3f}").format(self.E0[0])
                print ("Yet the decorrelation energy is at  {0:.3f}").format(self.decorrelationEnergy)
                print ("You might consider updating your normalization energy and rerunning.")
        else:
            print ("You have attempted to calculate the decorrelation energy but you don't ")
            print ("have a covariance matrix - rerun to produce this.")
        
        
        energy = np.asarray(self.fluxPoints[0])
        flux = np.asarray(self.fluxPoints[1]) #*self.fluxPoints[0]**self.energyPower
        flux_err = np.asarray(self.fluxPoints[2]) #*self.fluxPoints[0]**self.energyPower

        if flux_err.shape[0] == 2: 
            # take the average of up and down errors 
            flux_err = (flux_err[0] + flux_err[1]) / 2 

        
        # find the energy at which flux error / flux is minimum 

        minRatio = flux_err[0] / flux[0]
        minE = energy[0]
        for i in xrange(1, len(energy)):
            iRatio = flux_err[i] / flux[i]
            if iRatio < minRatio:
                minRatio = iRatio
                minE = energy[i]
                
        print "energy that minimizes ratio of error to flux: ", minE
            
        #return self.decorrelationEnergy

    #these are just copied from http://fermi.gsfc.nasa.gov/ssc/data/analysis/scitools/python_tutorial.html
    def calcPowerLawFlux(self):
        '''
        calculate the flux at given positions 
        '''
        self.flux = self.norm[0] * (self.energies/self.E0[0])**(-1.*self.index[0])
        
        return self.flux 
    #


    def calcPowerLawFluxError(self): 
        '''
        from FERMI OBSERVATIONS OF TeV-SELECTED ACTIVE GALACTIC NUCLEI
        I also redid the calculation myself.
        '''
        dFdN = 1./self.norm[0]
        dFda = -1. * np.log(self.energies/self.E0[0])

        Ferr = np.square(self.norm[1] * dFdN)
        if "cov" in vars(self):
            # note in paper -= but have the minus in dFda here
            Ferr += 2 * self.cov[0] * dFdN * dFda
        Ferr += np.square(self.index[1] * dFda)
        Ferr  = np.sqrt(Ferr) 
        
        if not "flux" in vars(self):
            self.calcPowerLawFlux()
        self.fluxError = self.flux * Ferr

        return self.fluxError 
        
    
    def fitPlot(self, name, energyRange=[], ECPL=False, pltPts=False, ls="--", **kwargs):
        """fit flux points to a curve then plot
        returns the plt plot object """
        
        # use the class member if not provided 
        if not energyRange:
            energyRange = self.energyRange

        def points( fp, erange=(float('-inf'),float('inf')) ):
            """generator of individual points in flux points within energy range"""
            if len(fp) <=2 or len(fp[0]) != len(fp[1]):
                print fp
                raise ValueError("flux points do not have the proper shape!")
             
            n = 0 
            N = len(fp[0])
            # yield only points that fit in energy range 
            while n < N:
                if fp[0][n] > erange[0] and fp[0][n] < erange[1]:
                    yield (fp[0][n], fp[1][n], fp[2][0][n],fp[2][1][n])
                n += 1

        fluxPoints = ( [], [], ([], []) )
        for point in points(self.fluxPoints, energyRange):
            for i in xrange(2):
                fluxPoints[i].append(point[i])
                fluxPoints[2][i].append(point[2+i])
        
        #fluxPoints = np.asarray(fluxPoints)
        #print fluxPoints
        #fluxPoints = [point for point in self.fluxPoints if point[0] > energyRange[0] and point[0] < energyRange[1] ]
        
        # pull old params from spectrumPlotter 
        power = self.energyPower 
        energy = np.asarray(fluxPoints[0])
        flux = np.asarray(fluxPoints[1]) #*self.fluxPoints[0]**self.energyPower
        flux_err = np.asarray(fluxPoints[2]) #*self.fluxPoints[0]**self.energyPower
        
        if "E0" in vars(self):
            E0 = self.E0[0]
        else:
            E0 = 1.0 * u.TeV.to(self.energyUnits)

        
        if 'c' in kwargs:
            c = kwargs['c']
        else:
            c = self.c
        
        # should find a general solution for allowing args / overrides 
        #E0=self.E0, power 
        #**{key: kwargs[key] for key in kwargs 
            #if (key in plt.errorbar.__code__.co_varnames)}

        logx = np.log(energy/E0)
        logy = np.log(flux)
        #logyerr = np.log(flux_err)


        if flux_err.shape[0] == 2: 
            # take the average of up and down errors 
            flux_err = (flux_err[0] + flux_err[1]) / 2 
        elif flux_err.shape[0] != 1:
            raise ValueError("Flux error must be present to perform fit!")

        logyerr = flux_err / flux 

        if ECPL: # power law with exponential cutoff 
            pinit = [-26, -2.25, 10]
            out = leastsq(spectrumPlotter.errfuncECPL, pinit,
                                   args=(energy/E0, flux, flux_err / flux), 
                                   full_output=1)

        else:

            pinit = [-26, -2.25] # nb ln

            out = leastsq(spectrumPlotter.errfunc, pinit,
                                   args=(logx, logy, logyerr), 
                                   full_output=1)
        # end if else ECPL 

        pfinal = out[0]
        covar  = out[1]
        print "parameters:"
        print pfinal
        print "covariance matrix"
        print covar

        N0    = np.exp(pfinal[0])
        gamma = pfinal[1]
        E     = np.linspace(energyRange[0], energyRange[-1], num=100)

        if ECPL:
            beta = pfinal[2]

            F    = spectrumPlotter.f_ecpl(E, N0, E0, -1.*gamma, beta)
            chi2 = np.sum((flux - spectrumPlotter.f_ecpl(energy, N0, E0, -1.*gamma, beta))**2/flux_err**2) / (len(energy) - 3)
            print "chi^2: "+str(chi2)+'\n'
            beta_err  = np.sqrt( covar[2][2] ) * chi2 #* N0  
            gamma_err = np.sqrt( covar[0][0] ) * chi2
            N0_err    = np.sqrt( covar[1][1] ) * N0 * chi2
            cov_gg = gamma_err**2
            cov_bb = beta_err**2
            Ferr = spectrumPlotter.ferr_ecpl(E, F, N0, N0_err, E0, cov_gg, beta, cov_bb)

            fitTitle = (name + ' - N0: {0:.2e} +- {2:.2e}, '\
                        'G: {1:.2f} +- {3:.2f}, '\
                        'Ec: {4:.2f} +- {5:.2f}, '
                        'E0: {6:.0f}').format(float(N0), float(gamma),
                                              float(N0_err), float(gamma_err),
                                              float(beta), float(beta_err), float(E0))

        else:
            F    = spectrumPlotter.f(E, N0, E0, -1.*gamma)
            chi2 = np.sum((flux - spectrumPlotter.f(energy, N0, E0, -1.*gamma))**2 / flux_err**2) / (len(energy) - 2)
            print chi2 
            gamma_err = np.sqrt( covar[0][0] ) * chi2
            N0_err    = np.sqrt( covar[1][1] ) * N0 * chi2
            cov_gg = gamma_err**2
            Ferr = spectrumPlotter.ferr(E, F, N0, N0_err, E0, cov_gg)

            fitTitle = (name + ' - N0= {0:.2e} +- {2:.2e}, '\
                        'gam= {1:.2f} +- {3:.2f}, '\
                        'E0= {4:.2f}').format(float(N0), float(gamma),
                                              float(N0_err), float(gamma_err), float(E0))

        
        p = plt.plot(E, F * (E)**power, color=c, ls=ls, marker="", label=fitTitle)

        plt.fill_between(E, (E)**power*(F+Ferr), (E)**power*(F-Ferr), color=c, alpha='0.25')
        if pltPts:
            plt.errorbar(energy, flux*energy**power, flux_err*energy**power, 
                    color=c, ls='', marker='_') # ,label=name
  
        self._plotCommon(**kwargs)

        return p 
        
    # fitPlot 
        
        
# class spectrumPlotter 
