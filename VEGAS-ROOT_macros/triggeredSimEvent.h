// data structure containing relevant variables for individual telescope image parameters 

#ifndef TRIGGEREDSIMEVENT_H
#define TRIGGEREDSIMEVENT_H

// set up struct for branch 
class triggeredSimEvent : public TObject {
    //typedef struct {
 public: // do not use for struct 
    //triggeredSimEvent();
    //triggeredSimEvent() = default ;
    Float_t fEnergyGeV;
    Float_t fPrimaryZenithDeg;
    Float_t fPrimaryAzimuthDeg;
    
    Float_t fLength;
    Float_t fWidth;
    Float_t fSize;
    Float_t fTimeGradient;
    Float_t fLoss;
    Float_t fDist;
    
}; // triggeredSimEvent
// struct triggeredSimEvent {};
// above form does not work for some reason 

#endif // TRIGGEREDSIMEVENT_H
