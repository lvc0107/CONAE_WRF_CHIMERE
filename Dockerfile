#
#FROM centos:latest - some users reported problems with yum
FROM centos:7
MAINTAINER Miguel Vargas <lvc0107@protonmail.com>

ENV WRF_VERSION 3.7.1
ENV WPS_VERSION 3.6.1
ENV NML_VERSION 4.0.2

# Set up base OS environment

RUN yum -y update
RUN yum -y install scl file gcc gcc-gfortran gcc-c++ glibc.i686 libgcc.i686 libpng-devel jasper \
  jasper-devel hostname m4 make perl tar bash tcsh time wget which zlib zlib-devel \
  openssh-clients openssh-server net-tools fontconfig libgfortran libXext libXrender \
  ImageMagick sudo epel-release git

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

# Build OpenMPI
RUN mkdir -p /wrf/libs/openmpi/BUILD_DIR
RUN source /opt/rh/devtoolset-8/enable \
 && cd /wrf/libs/openmpi/BUILD_DIR \
 && curl -L -O https://download.open-mpi.org/release/open-mpi/v2.0/openmpi-2.0.4.tar.gz \
 && tar -xf openmpi-2.0.4.tar.gz \
 && cd openmpi-2.0.4 \
 && ./configure --prefix=/usr/local &> /wrf/libs/build_log_openmpi_config \
 && make all install &> /wrf/libs/build_log_openmpi_make \
 && cd / \
 && rm -rf /wrf/libs/openmpi/BUILD_DIR

# Build HDF5 libraries
RUN mkdir -p /wrf/libs/hdf5/BUILD_DIR
RUN source /opt/rh/devtoolset-8/enable \
 && cd /wrf/libs/hdf5/BUILD_DIR \
 && curl -L -O https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-1.8/hdf5-1.8.20/src/hdf5-1.8.20.tar.gz \
 && tar -xvf hdf5-1.8.20.tar.gz \
 && cd hdf5-1.8.20 \
 && make clean \
 && ./configure --enable-fortran --enable-cxx --prefix=/usr/local/ &> /wrf/libs/build_log_hdf5_config \
 && make install &> /wrf/libs/build_log_hdf5_make \
 && rm -rf /wrf/libs/hdf5/BUILD_DIR
ENV LD_LIBRARY_PATH /usr/local/lib

# Build netCDF C and Fortran libraries
RUN yum -y install libcurl-devel zlib-devel
ENV NETCDF /wrf/libs/netcdf
RUN mkdir -p ${NETCDF}/BUILD_DIR
RUN source /opt/rh/devtoolset-8/enable \
 && cd ${NETCDF}/BUILD_DIR \
 && curl -L -O https://github.com/Unidata/netcdf-c/archive/v4.6.2.tar.gz \
 && curl -L -O https://github.com/Unidata/netcdf-fortran/archive/v4.4.5.tar.gz \
 && tar -xf v4.6.2.tar.gz \
 && cd netcdf-c-4.6.2 \
 && ./configure --prefix=${NETCDF} &> /wrf/libs/build_log_ncc_config \
 && make install &> /wrf/libs/build_log_ncc_make
RUN source /opt/rh/devtoolset-8/enable \
 && env \
 && cd ${NETCDF}/BUILD_DIR \
 && tar -xf v4.4.5.tar.gz \
 && cd netcdf-fortran-4.4.5/ \
 && export LD_LIBRARY_PATH=${NETCDF}/lib:${LD_LIBRARY_PATH} \
 && CPPFLAGS=-I${NETCDF}/include LDFLAGS=-L${NETCDF}/lib ./configure --prefix=${NETCDF} &> /wrf/libs/build_log_ncf_config \
 && make install &> /wrf/libs/build_log_ncf_make

RUN mkdir -p /var/run/sshd \
    && ssh-keygen -A \
    && sed -i 's/#PermitRootLogin yes/PermitRootLogin yes/g' /etc/ssh/sshd_config \
    && sed -i 's/#RSAAuthentication yes/RSAAuthentication yes/g' /etc/ssh/sshd_config \
    && sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/g' /etc/ssh/sshd_config

RUN mkdir -p  /wrf/WPS_GEOG /wrf/wrfinput /wrf/wrfoutput \
 &&  chown -R wrfuser:wrf /wrf /wrf/WPS_GEOG /wrf/wrfinput /wrf/wrfoutput /usr/local \
 &&  chmod 6755 /wrf /wrf/WPS_GEOG /wrf/wrfinput /wrf/wrfoutput /usr/local

# Download NCL
#RUN curl -SL https://ral.ucar.edu/sites/default/files/public/projects/ncar-docker-wrf/nclncarg-6.3.0.linuxcentos7.0x8664nodapgcc482.tar.gz | tar zxC /usr/local
# from here: https://www.earthsystemgrid.org/dataset/ncl.630.2/file.html
RUN curl -SL  https://www.earthsystemgrid.org/api/v1/dataset/ncl.630.2/file/ncl_ncarg-6.3.0.tar.gz | tar zxC /usr/local
ENV NCARG_ROOT /usr/local

# Set environment for interactive container shells
RUN echo export LDFLAGS="-lm" >> /etc/bashrc \
 && echo export NETCDF=${NETCDF} >> /etc/bashrc \
 && echo export JASPERINC=/usr/include/jasper/ >> /etc/bashrc \
 && echo export JASPERLIB=/usr/lib64/ >> /etc/bashrc \
 && echo export LD_LIBRARY_PATH="/opt/rh/devtoolset-8/root/usr/lib/gcc/x86_64-redhat-linux/8:/usr/lib64/openmpi/lib:${NETCDF}/lib:${LD_LIBRARY_PATH}" >> /etc/bashrc  \
 && echo export PATH=".:/opt/rh/devtoolset-8/root/usr/bin:/usr/lib64/openmpi/bin:${NETCDF}/bin:$PATH" >> /etc/bashrc

RUN echo setenv LDFLAGS "-lm" >> /etc/csh.cshrc \
 && echo setenv NETCDF "${NETCDF}" >> /etc/csh.cshrc \
 && echo setenv JASPERINC "/usr/include/jasper/" >> /etc/csh.cshrc \
 && echo setenv JASPERLIB "/usr/lib64/" >> /etc/csh.cshrc \
 && echo setenv LD_LIBRARY_PATH "/opt/rh/devtoolset-8/root/usr/lib/gcc/x86_64-redhat-linux/8:/usr/lib64/openmpi/lib:${NETCDF}/lib:${LD_LIBRARY_PATH}" >> /etc/csh.cshrc \
 && echo setenv PATH ".:/opt/rh/devtoolset-8/root/usr/bin:/usr/lib64/openmpi/bin:${NETCDF}/bin:$PATH" >> /etc/csh.cshrc

RUN mkdir /wrf/.ssh ; echo "StrictHostKeyChecking no" > /wrf/.ssh/config
COPY default-mca-params.conf /wrf/.openmpi/mca-params.conf
RUN mkdir -p /wrf/.openmpi
RUN chown -R wrfuser:wrf /wrf/

# all root steps completed above, now below as regular userID wrfuser
USER wrfuser
WORKDIR /wrf

# Download data
ARG argname=tutorial
RUN echo DAVE $argname
RUN if [ "$argname" = "tutorial" ] ; then curl -SL http://www2.mmm.ucar.edu/wrf/src/wps_files/geog_low_res_mandatory.tar.gz | tar -xzC /wrf/WPS_GEOG ; fi
#RUN if [ "$argname" = "tutorial" ] ; then curl -SL http://www2.mmm.ucar.edu/wrf/TUTORIAL_DATA/colorado_march16.new.tar.gz | tar -xzC /wrf/wrfinput ; fi
RUN if [ "$argname" = "tutorial" ] ; then curl -SL https://www2.mmm.ucar.edu/wrf/TUTORIAL_DATA/colorado_march16.tar.gz | tar -xzC /wrf/wrfinput ; fi
RUN if [ "$argname" = "tutorial" ] ; then curl -SL http://www2.mmm.ucar.edu/wrf/src/namelists_v$NML_VERSION.tar.gz  | tar -xzC /wrf/wrfinput ; fi
#RUN if [ "$argname" = "tutorial" ] ; then curl -SL http://www2.mmm.ucar.edu/wrf/TUTORIAL_DATA/WRF_NCL_scripts.tar.gz | tar -xzC /wrf ; fi
RUN if [ "$argname" = "regtest" ]  ; then curl -SL http://www2.mmm.ucar.edu/wrf/dave/DATA/Data_small/data_SMALL.tar.gz | tar -xzC /wrf ; fi
RUN if [ "$argname" = "regtest" ]  ; then curl -SL http://www2.mmm.ucar.edu/wrf/dave/nml.tar.gz | tar -xzC /wrf ; fi
RUN if [ "$argname" = "regtest" ]  ; then curl -SL http://www2.mmm.ucar.edu/wrf/dave/script.tar | tar -xC /wrf ; fi

# Download wps source
RUN if [ "$argname" = "tutorial" ] ; then git clone https://github.com/wrf-model/WPS.git WPS ; fi

RUN echo _HERE1_
RUN git clone https://github.com/davegill/WRF.git davegill/WRF \
  && cd davegill/WRF \
  && git fetch origin +refs/pull/4/merge: \
  && git checkout -qf FETCH_HEAD \
  && cd .. \
  && mv WRF /wrf/WRF
RUN echo _HERE2_

ENV JASPERINC /usr/include/jasper
ENV JASPERLIB /usr/lib64
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
