# header utilities

from astropy.io import fits

def verify_header(Hin):
    if Hin['CTYPE1'] == 'GLON---TAN':
        print("Changing CTYPE1 ..")
        Hin['CTYPE1'] = 'GLON-TAN'
        print(Hin['CTYPE1'])
    if Hin['CTYPE2'] == 'GLAT--TAN':
        print("Changing CTYPE2 ..")
        Hin['CTYPE2'] = 'GLAT-TAN'
        print(Hin['CTYPE2'])
    if Hin['RADECSYS'] != '':
        print(Hin['RADECSYS'])
        Hin.append(('RADESYSa', Hin['RADECSYS']))
        #Hin.append(('RADESYSa','FK5'))
        Hin.remove('RADECSYS')
        print("changing RADECYS to RADESYSa")

def main():
    print("main main");
    exit

if __name__ == '__main__':
    main()

