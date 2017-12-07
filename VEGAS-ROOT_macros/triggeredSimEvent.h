// data structure containing relevant variables for individual telescope image parameters 

// set up struct for branch 
typedef struct {
    Float_t fEnergyGeV;
    Float_t fPrimaryZenithDeg;
    Float_t fPrimaryAzimuthDeg;
    
    Float_t fLength;
    Float_t fWidth;
    Float_t fSize;
    Float_t fTimeGradient;
    Float_t fLoss;
    Float_t fDist;
    
} triggeredSimEvent;
// struct triggeredSimEvent {};
// alternative is to create TObject 
