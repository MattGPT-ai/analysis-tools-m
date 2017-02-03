
# Use Ubuntu base image
FROM ubuntu:latest 
# could try something more minimal like ubuntu server or debian 

# I am the maintainer
MAINTAINER hughd@iastate.edu

# Arguments for VEGAS git repo
ARG gituser
ARG gitpassword
ARG veritaspassword

# Make a software directory
RUN mkdir software

# Install ROOT prerequisites using apt-get
RUN apt-get -y update 

RUN apt-get install -y git dpkg-dev make g++ gcc libx11-dev libxpm-dev \
libxft-dev libxext-dev cmake wget autotools-dev libtool automake autoconf \
autoconf-archive doxygen bc binutils mysql-client 

# change mirror to fix problem with download
RUN sed -i 's/http:\/\/us./http:\/\//g' /etc/apt/sources.list

RUN apt-get install -y gfortran libssl-dev libpcre3-dev \
xlibmesa-glu-dev libglew1.5-dev libftgl-dev \
libmysqlclient-dev libfftw3-dev libcfitsio3-dev \
graphviz-dev libavahi-compat-libdnssd-dev \
libldap2-dev python-dev libxml2-dev libkrb5-dev \
libgsl0-dev libqt4-dev libgsl0-dev libgsl0-dbg \ 
libc6-dev-i386 
# cfitsio-dev -> cfitsio3-dev 

# Do the remaining work in the software directory
WORKDIR /software

# Install ROOT from git

RUN git clone http://root.cern.ch/git/root.git ROOT && cd ROOT && git checkout -b v5-34-34 v5-34-34 && git branch
# should stay in /software for each RUN 
RUN mkdir ROOT_build && cd ROOT_build && cmake -Dgsl_shared=YES -Droofit=YES ../ROOT && make

# Initialize ROOT environment variables
# RUN ["/bin/bash", "-c", "source /software/ROOT_build/bin/thisroot.sh"]
ENV ROOTSYS "/software/ROOT_build"
ENV PATH "${PATH}:${ROOTSYS}/bin"
ENV LD_LIBRARY_PATH "${LD_LIBRARY_PATH}:${ROOTSYS}/lib"
RUN echo ${ROOTSYS}; echo ${PATH}; echo ${LD_LIBRARY_PATH}

# Download and install VEGAS dependencies
RUN mkdir tarballs 
RUN mkdir install

# BOOST
RUN wget --directory-prefix=tarballs https://sourceforge.net/projects/boost/files/boost/1.61.0/boost_1_61_0.tar.gz
RUN tar -zxvf tarballs/boost_1_61_0.tar.gz

# VBF
RUN wget --directory-prefix=tarballs --http-user=veritas --http-password=$veritaspassword http://romulus.ucsc.edu/downloads/VBF-0.3.4.tar.gz
RUN tar -zxvf tarballs/VBF-0.3.4.tar.gz
RUN cd VBF-0.3.4 && ./configure --prefix=/software/install
RUN cd VBF-0.3.4 && make && make install && ls /software

# VDB
RUN wget --directory-prefix=tarballs --http-user=veritas --http-password=$veritaspassword http://romulus.ucsc.edu/downloads/VDB-4.3.2.tar.gz 
RUN tar -zxvf tarballs/VDB-4.3.2.tar.gz  
RUN cd VDB-4.3.2 && ./configure --prefix=/software/install --with-boost-incdir=/software/boost_1_61_0
RUN cd VDB-4.3.2 && make && make install

# Update paths again
ENV PATH "${PATH}:/software/install/bin"
ENV LD_LIBRARY_PATH "${LD_LIBRARY_PATH}:/software/install/lib"


# Clone VEGAS, checkout tag, build
RUN git clone https://$gituser:$gitpassword@github.com/VERITAS-Observatory/VEGAS.git vegas

# Change working directory to the cloned VEGAS repo
WORKDIR vegas

# Checkout the appropriate tag 
#RUN git pull 
RUN git checkout beta/v2_5_5_rc4 # -b beta/v2_5_5_rc1 

# Link the boost include directory into the vegas source tree
RUN ln -s /software/boost_1_61_0/boost .

# Try the build
RUN make VERITASBASE=/software/vegas VBFSYS=/software/install all
RUN make VERITASBASE=/software/vegas VBFSYS=/software/install install

RUN cat /software/vegas/validation/docker_shifter/bashrc >> $HOME/.bashrc
RUN git status > git_hash.txt 
RUN git describe --always >> git_hash.txt  


# compile ROOT macros 
RUN cd macros && root -l -b -q 
RUN cd showerReconstruction2/macros && root -l -b -q 
RUN cd resultsExtractor/macros && root -l -b -q 


# remove VERITAS source files 
RUN find /software/VBF-0.3.4/ -name "*.cpp" -exec rm {} \; && find /software/VBF-0.3.4/ -name "*.h" -exec rm {} \;
RUN find /software/VDB-4.3.2/ -name "*.cpp" -exec rm {} \; && find /software/VDB-4.3.2/ -name "*.h" -exec rm {} \;
RUN find /software/vegas/ -name "*.cpp" -exec rm {} \; #&& find /software/vegas/ -name "*.h" -exec rm {} \;
RUN rm -rf /software/vegas/.git*

# Set environment variables
ENV VEGAS /software/vegas
ENV PATH "${PATH}:${VEGAS}/bin"

# command 
CMD /bin/bash 

# Some test entry points (arguments can be passed to docker on the command line)
#ENTRYPOINT vaStage1
#ENTRYPOINT vaStage2
#ENTRYPOINT vaStage4.2
#ENTRYPOINT vaStage5
#ENTRYPOINT vaStage6
# VEGAS stages 

# bbftp 
WORKDIR /software
RUN wget --directory-prefix=tarballs http://doc.in2p3.fr/bbftp/dist/bbftp-client-3.2.1.tar.gz
RUN tar -zxvf tarballs/bbftp-client-3.2.1.tar.gz
WORKDIR bbftp-client-3.2.1/bbftpc
RUN ./configure 
RUN make
RUN make install 

# Make directories to be used as external mount points so that the VEGAS 
# executables can read and write data. Since we probably want to bind-mount
# host volumes, the -v flag to docker run must be used rather than the VOLUME
# directive in this Dockerfile.
# Note on OSX the host mount points must be somewhere under /Users
WORKDIR /
RUN mkdir external_data
RUN mkdir external_output

# Expose the MySQL port
EXPOSE 3306

# cleanup 
RUN apt-get purge 
RUN apt-get clean autoclean 
RUN apt-get autoremove -y 
RUN rm -rf /var/lib/{apt,dpkg,cache,log}/
RUN rm -rf /software/tarballs/ 
