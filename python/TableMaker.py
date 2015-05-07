import os
from numpy import array_split
import VGlobal

def createLookupTable(array,atmosphere,cutsFile=produceLTCutsFile,zenithList=fullZenithList,azimuthList=fullAzimuthList,offsetList=fullOffsetList,noiseList=fullNoiseList,configFile=produceLTConfigFile,method=std,telIDList=[0,1,2,3]):
    
    zenithChunks = numpy.array_split(zenithList,(len(zenithList))/2)
    azimuthChunks = numpy.array_split(azimuthList,(len(azimuthList))/2)
    offsetChunks = numpy.array_split(offsetList,(len(offsetList))/2)
    noiseChunks = numpy.array_split(noiseList,(len(noiseList))/2)
    
    for zenithChunk in zenithChunks:
        for azimuthChunk in azimuthChunks:
            for offsetChunk in offsetChunks:
                offsetChunk = [str(int(x*100)).zfill(3) for offset in offsetChunk]
                for noiseChunk in noiseChunks:


                    with open(
#    simFilename = getSimFileName(array,atmosphere,zenith,offset,noise,method)
