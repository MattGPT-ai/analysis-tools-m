#ifndef LOAD_CHAIN_MACRO
#define LOAD_CHAIN_MACRO

//#include <Riostream.h>

using namespace std;

TChain* loadChain()
{
	cout << "A simple function which returns a chain" << endl;
	cout << "The inputs are first a filename containing all the files in the chain" << endl;
	cout << "The second input is the full treename (including directory)" << endl;
	cout << "TChain *loadChain(const char * filelist, string treeName)" << endl;
	return nullptr;
}

// if fileList is a .root file, just load it 
TChain* loadChain(const char * fileList, const char * treeName)
{
	TChain* ch = new TChain(treeName);

	// if file ends in .root just add it
	string fileString = string(fileList);
	string extension = ".root";
	if(fileString.length() >= extension.length()
	   && !fileString.compare(fileString.length()-extension.length(), extension.length(), extension))
	  {
	    ch->Add(fileList);
	  }

	// else add every file in list 
	else {

	    std::ifstream infile;
	infile.open(fileList, std::ifstream::in);
	if(!infile.is_open())
	{
		cerr << "Couldn't load " << fileList << endl;
		return nullptr;
	}
	while(!infile.eof())
	{
		char buffer[1024];
		infile.getline(buffer, 1024);
		char testBufferSize[1024];

		int ss = sscanf(buffer, "%s", testBufferSize);

		if(ss != 1)
		{
			cerr << "wrong format of ascii file!" << endl;
			return nullptr;
		}

		cout << "Adding " << buffer << endl;
		ch->Add(buffer);
	} // while loop over lines in list file 
	} // else 
	return ch;
} // loadChain

#endif // LOAD_CHAIN_MACRO
