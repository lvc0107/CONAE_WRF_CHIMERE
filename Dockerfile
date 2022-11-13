#
#FROM centos:latest - some users reported problems with yum
FROM centos:7
MAINTAINER Miguel Vargas <lvc0107@proton.me>

# Set up base OS environment

RUN yum -y update
RUN yum -y install scl file gcc gcc-gfortran gcc-c++ glibc.i686 libgcc.i686 libpng-devel jasper \
  jasper-devel hostname m4 make perl tar bash tcsh time wget which zlib zlib-devel \
  openssh-clients openssh-server net-tools fontconfig libgfortran libXext libXrender \
  ImageMagick sudo epel-release git autoconf automake libtool

# Newer version of GNU compiler, required for WRF 2003 and 2008 Fortran constructs

RUN yum -y install centos-release-scl \
 && yum -y install devtoolset-8 \
 && yum -y install devtoolset-8-gcc devtoolset-8-gcc-gfortran devtoolset-8-gcc-c++ \
 && scl enable devtoolset-8 bash \
 && scl enable devtoolset-8 tcsh

RUN groupadd wrf -g 9999
RUN useradd -u 9999 -g wrf -G wheel -M -d /wrf wrfuser
RUN mkdir /wrf \
 &&  chown -R wrfuser:wrf /wrf \
 &&  chmod 6755 /wrf

# Build the libraries with a parallel Make
ENV J 4

ARG CHIMERE_USER
ENV CHIMERE_USER=$CHIMERE_USER
ARG CHIMERE_PASS
ENV CHIMERE_PASS=$CHIMERE_PASS

# TODO install in BUILD_DIR
# Build OpenMPI
RUN mkdir -p /wrf/libs/openmpi/BUILD_DIR
RUN source /opt/rh/devtoolset-8/enable \
 && cd /wrf/libs/openmpi/BUILD_DIR \
 && curl -L -O https://download.open-mpi.org/release/open-mpi/v2.0/openmpi-2.0.4.tar.gz \
 && tar -xf openmpi-2.0.4.tar.gz \
 && cd openmpi-2.0.4 \
 && ./configure CC=/usr/bin/gcc CXX=/usr/bin/g++ FC=/usr/bin/gfortran CFLAGS=-m64 CXXFLAGS=-m64 FCFLAGS=-m64 --prefix=/usr/local &> /wrf/libs/build_log_openmpi_config \
 && make all install &> /wrf/libs/build_log_openmpi_make \
 && cd / \
 && rm -rf /wrf/libs/openmpi/BUILD_DIR

# TODO install in BUILD_DIR
# Build HDF5 libraries
RUN mkdir -p /wrf/libs/hdf5/BUILD_DIR
RUN source /opt/rh/devtoolset-8/enable \
 && cd /wrf/libs/hdf5/BUILD_DIR \
 && curl -L -O https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-1.8/hdf5-1.8.20/src/hdf5-1.8.20.tar.gz \
 && tar -xvf hdf5-1.8.20.tar.gz \
 && cd hdf5-1.8.20 \
 && make clean \
 && ./configure CC=/usr/local/bin/mpicc FC=/usr/local/bin/mpif90 CPPFLAGS=-I/usr/local/include/openmpi LDFLAGS=-L/usr/local/lib/openmpi/ --enable-fortran --enable-parallel --prefix=/usr/local/ &> /wrf/libs/build_log_hdf5_config \
 && make install &> /wrf/libs/build_log_hdf5_make \
 && rm -rf /wrf/libs/hdf5/BUILD_DIR
ENV LD_LIBRARY_PATH /usr/local/lib

# TODO install in BUILD_DIR
# Build netCDF C and Fortran libraries
RUN yum -y install libcurl-devel zlib-devel
ENV NETCDF /wrf/libs/netcdf
RUN mkdir -p ${NETCDF}/BUILD_DIR
RUN source /opt/rh/devtoolset-8/enable \
 && cd ${NETCDF}/BUILD_DIR \
 && curl -L -O https://github.com/Unidata/netcdf-c/archive/v4.6.0.tar.gz \
 && curl -L -O https://github.com/Unidata/netcdf-fortran/archive/v4.4.4.tar.gz \
 && tar -xf v4.6.0.tar.gz \
 && cd netcdf-c-4.6.0 \
 && ./configure CC=/usr/local/bin/mpicc CPPFLAGS="-I/usr/local/include/openmpi -I/usr/local/include" LDFLAGS="-L/usr/local/lib/openmpi/ -L/usr/local/lib" --prefix=${NETCDF} &> /wrf/libs/build_log_ncc_config \
 && make install &> /wrf/libs/build_log_ncc_make
RUN source /opt/rh/devtoolset-8/enable \
 && env \
 && cd ${NETCDF}/BUILD_DIR \
 && tar -xf v4.4.4.tar.gz \
 && cd netcdf-fortran-4.4.4/ \
 && export LD_LIBRARY_PATH=${NETCDF}/lib:${LD_LIBRARY_PATH} \
 && ./configure CC=/usr/local/bin/mpicc FC=/usr/local/bin/mpif90 CPPFLAGS="-I/usr/local/include/openmpi -I/usr/local/include -I/wrf/libs/netcdf/include" LDFLAGS="-L/usr/local/lib/openmpi/ -L/usr/local/lib -L/wrf/libs/netcdf/lib" --prefix=${NETCDF} &> /wrf/libs/build_log_ncf_config \
 && make install &> /wrf/libs/build_log_ncf_make


COPY --chown=wrfuser blitz-0.10.tar.gz  .
RUN mkdir -p /wrf/libs/blitz/BUILD_DIR  \
  && cp blitz-0.10.tar.gz /wrf/libs/blitz \
  && cd /wrf/libs/blitz \
  && tar -xvzf blitz-0.10.tar.gz  \
  && cd blitz-0.10 \
  && autoreconf -i  \
  && ./configure --prefix=/wrf/libs/blitz/BUILD_DIR  \
  && make lib &> /wrf/libs/blitz/build_log_blitz \
  && make install \
  && cd ..; rm blitz-0.10.tar.gz \
  && cd

COPY --chown=wrfuser jasper-1.900.1.zip  .
RUN mkdir -p /wrf/libs/jasper/BUILD_DIR  \
  && cp jasper-1.900.1.zip /wrf/libs/jasper \
  && cd /wrf/libs/jasper \
  && unzip jasper-1.900.1.zip \
  && cd jasper-1.900.1 \
  && ./configure --prefix=/wrf/libs/jasper/BUILD_DIR  \
  && make \
  && make check\
  && make install &> /wrf/libs/jasper/build_log_jasper \
  && cd ..; rm jasper-1.900.1.zip \
  && cd

COPY --chown=wrfuser cmake-3.13.4.tar.gz .
RUN mkdir -p /wrf/libs/cmake/BUILD_DIR  \
  && cp cmake-3.13.4.tar.gz /wrf/libs/cmake \
  && cd /wrf/libs/cmake \
  && tar -xvzf cmake-3.13.4.tar.gz \
  && cd cmake-3.13.4 \
  && ./bootstrap \
  && make \
  && make install \
  && cd ..; rm cmake-3.13.4.tar.gz \
  && cd


COPY --chown=wrfuser eccodes-2.19.1-Source.tar.gz .
RUN mkdir -p /wrf/libs/eccodes/BUILD_DIR  \
  && cp eccodes-2.19.1-Source.tar.gz /wrf/libs/eccodes \
  && cd /wrf/libs/eccodes \
  && tar -xvzf eccodes-2.19.1-Source.tar.gz \
  && mkdir build \
  && cd build \
  && cmake  ../eccodes-2.19.1-Source -DCMAKE_INSTALL_PREFIX=/wrf/libs/eccodes/BUILD_DIR \
  && make \
  && ctest \
  && make install \
  && cd ..; rm eccodes-2.19.1-Source.tar.gz \
  && cd

#CHIMERE
COPY --chown=wrfuser mychimere-gfortran .
RUN cd /wrf \
  && wget --no-check-certificate --user $CHIMERE_USER --password $CHIMERE_PASS https://www.lmd.polytechnique.fr/chimdata/chimere_v2020r3.tar.gz \
  && tar -xvzf chimere_v2020r3.tar.gz  \
  && cp ../mychimere-gfortran chimere_v2020r3/mychimere \
  && cd chimere_v2020r3 \
  && ./build-chimere.sh --arch gfortran &> /wrf/chimere_v2020r3/build_log_chimere \
  && ./build-wrf.sh &> /wrf/chimere_v2020r3/build_log_wrf \
  && cd /wrf ; rm chimere_v2020r3.tar.gz \
  && cd


# TODO REVIEW these commands
RUN mkdir -p /var/run/sshd \
    && ssh-keygen -A \
    && sed -i 's/#PermitRootLogin yes/PermitRootLogin yes/g' /etc/ssh/sshd_config \
    && sed -i 's/#RSAAuthentication yes/RSAAuthentication yes/g' /etc/ssh/sshd_config \
    && sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/g' /etc/ssh/sshd_config

# TODO REVIEW these commands
RUN mkdir -p  /wrf/WPS_GEOG /wrf/wrfinput /wrf/wrfoutput \
 &&  chown -R wrfuser:wrf /wrf /wrf/WPS_GEOG /wrf/wrfinput /wrf/wrfoutput /usr/local \
 &&  chmod 6755 /wrf /wrf/WPS_GEOG /wrf/wrfinput /wrf/wrfoutput /usr/local

# TODO REVIEW this commands
# Download NCL
#RUN curl -SL https://ral.ucar.edu/sites/default/files/public/projects/ncar-docker-wrf/nclncarg-6.3.0.linuxcentos7.0x8664nodapgcc482.tar.gz | tar zxC /usr/local
# from here: https://www.earthsystemgrid.org/dataset/ncl.630.2/file.html
RUN curl -SL  https://www.earthsystemgrid.org/api/v1/dataset/ncl.630.2/file/ncl_ncarg-6.3.0.tar.gz | tar zxC /usr/local
ENV NCARG_ROOT /usr/local

# TODO REVIEW this commands
# Set environment for interactive container shells
RUN echo export LDFLAGS="-lm" >> /etc/bashrc \
 && echo export NETCDF=${NETCDF} >> /etc/bashrc \
 && echo export JASPERINC=/wrf/libs/jasper/BUILD_DIR/include/ >> /etc/bashrc \
 && echo export JASPERLIB=/wrf/libs/jasper/BUILD_DIR/lib/ >> /etc/bashrc \
 && echo export LD_LIBRARY_PATH="/opt/rh/devtoolset-8/root/usr/lib/gcc/x86_64-redhat-linux/8:/usr/lib64/openmpi/lib:${NETCDF}/lib:${LD_LIBRARY_PATH}" >> /etc/bashrc  \
 && echo export PATH=".:/opt/rh/devtoolset-8/root/usr/bin:/usr/lib64/openmpi/bin:${NETCDF}/bin:$PATH" >> /etc/bashrc

# TODO REVIEW this commands
RUN echo setenv LDFLAGS "-lm" >> /etc/csh.cshrc \
 && echo setenv NETCDF "${NETCDF}" >> /etc/csh.cshrc \
 && echo setenv JASPERINC "/wrf/libs/jasper/BUILD_DIR/include/" >> /etc/csh.cshrc \
 && echo setenv JASPERLIB "/wrf/libs/jasper/BUILD_DIR/lib/" >> /etc/csh.cshrc \
 && echo setenv LD_LIBRARY_PATH "/opt/rh/devtoolset-8/root/usr/lib/gcc/x86_64-redhat-linux/8:/usr/lib64/openmpi/lib:${NETCDF}/lib:${LD_LIBRARY_PATH}" >> /etc/csh.cshrc \
 && echo setenv PATH ".:/opt/rh/devtoolset-8/root/usr/bin:/usr/lib64/openmpi/bin:${NETCDF}/bin:$PATH" >> /etc/csh.cshrc

# TODO REVIEW these commands
RUN mkdir /wrf/.ssh ; echo "StrictHostKeyChecking no" > /wrf/.ssh/config
COPY default-mca-params.conf /wrf/.openmpi/mca-params.conf
RUN mkdir -p /wrf/.openmpi
RUN chown -R wrfuser:wrf /wrf/

# all root steps completed above, now below as regular userID wrfuser
USER wrfuser
WORKDIR /wrf

# TODO REVIEW these commands
ENV JASPERINC /wrf/libs/jasper/BUILD_DIR/include
ENV JASPERLIB /wrf/libs/jasper/BUILD_DIR/lib
ENV NETCDF_classic 1
ENV LD_LIBRARY_PATH /opt/rh/devtoolset-8/root/usr/lib/gcc/x86_64-redhat-linux/8:/usr/lib64/openmpi/lib:${NETCDF}/lib:${LD_LIBRARY_PATH}
ENV PATH  .:/opt/rh/devtoolset-8/root/usr/bin:/usr/lib64/openmpi/bin:${NETCDF}/bin:$PATH

RUN ssh-keygen -f /wrf/.ssh/id_rsa -t rsa -N '' \
    && chmod 600 /wrf/.ssh/config \
    && chmod 700 /wrf/.ssh \
    && cp /wrf/.ssh/id_rsa.pub /wrf/.ssh/authorized_keys

VOLUME /wrf
CMD ["/bin/tcsh"]
#
