# syntax = docker/dockerfile:1.3
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

RUN groupadd chim -g 9999
RUN useradd -u 9999 -g chim -G wheel -M -d /chim chimuser
RUN mkdir /chim \
 &&  chown -R chimuser:chim /chim \
 &&  chmod 6755 /chim

# Build the libraries with a parallel Make.
# TODO probabbly J 4 is not working with buildx
ENV J 1

# Build OpenMPI
RUN mkdir -p /chim/libs/openmpi/BUILD_DIR
ENV OPENMPI_LIB /chim/libs/openmpi
RUN source /opt/rh/devtoolset-8/enable \
 && cd /chim/libs/openmpi/BUILD_DIR \
 && curl -L -O https://download.open-mpi.org/release/open-mpi/v2.0/openmpi-2.0.4.tar.gz \
 && tar -xf openmpi-2.0.4.tar.gz \
 && cd openmpi-2.0.4 \
 && ./configure CC=/usr/bin/gcc CXX=/usr/bin/g++ FC=/usr/bin/gfortran CFLAGS=-m64 CXXFLAGS=-m64 FCFLAGS=-m64 --prefix=/chim/libs/openmpi/BUILD_DIR\
 && make all install \
 && cd ..; rm openmpi-2.0.4.tar.gz

# Build HDF5 libraries
RUN mkdir -p /chim/libs/hdf5/BUILD_DIR
ENV HDF5_LIB /chim/libs/hdf5
RUN source /opt/rh/devtoolset-8/enable \
 && cd /chim/libs/hdf5/BUILD_DIR \
 && curl -L -O https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-1.8/hdf5-1.8.20/src/hdf5-1.8.20.tar.gz \
 && tar -xvf hdf5-1.8.20.tar.gz \
 && cd hdf5-1.8.20 \
 && make clean \
 && ./configure CC=/chim/libs/openmpi/BUILD_DIR/bin/mpicc FC=/chim/libs/openmpi/BUILD_DIR/bin/mpif90 CPPFLAGS=-I/chim/libs/openmpi/BUILD_DIR/include/openmpi LDFLAGS=-L/chim/libs/openmpi/BUILD_DIR/lib/openmpi --enable-fortran --enable-parallel --prefix=/chim/libs/hdf5/BUILD_DIR \
 && make install \
 && cd ..; rm hdf5-1.8.20.tar.gz \
 && export LD_LIBRARY_PATH=${HDF5_LIB}/lib:${LD_LIBRARY_PATH}

# TODO install in BUILD_DIR
# Build netCDF C and Fortran libraries
RUN yum -y install libcurl-devel zlib-devel
ENV NETCDF /chim/libs/netcdf
RUN mkdir -p ${NETCDF}/BUILD_DIR
RUN source /opt/rh/devtoolset-8/enable \
 && cd ${NETCDF}/BUILD_DIR \
 && curl -L -O https://github.com/Unidata/netcdf-c/archive/v4.6.0.tar.gz \
 && curl -L -O https://github.com/Unidata/netcdf-fortran/archive/v4.4.4.tar.gz \
 && tar -xf v4.6.0.tar.gz \
 && cd netcdf-c-4.6.0 \
 && ./configure CC=/chim/libs/openmpi/BUILD_DIR/bin/mpicc CPPFLAGS="-I/chim/libs/openmpi/BUILD_DIR/include/openmpi -I/chim/libs/hdf5/BUILD_DIR/include" LDFLAGS="-L/chim/libs/openmpi/BUILD_DIR/lib/openmpi -L/chim/libs/hdf5/BUILD_DIR/lib" --prefix=${NETCDF} \
 && make install
RUN source /opt/rh/devtoolset-8/enable \
 && env \
 && cd ${NETCDF}/BUILD_DIR \
 && tar -xf v4.4.4.tar.gz \
 && cd netcdf-fortran-4.4.4/ \
 && export LD_LIBRARY_PATH=${NETCDF}/lib:${LD_LIBRARY_PATH} \
 && ./configure CC=/chim/libs/openmpi/BUILD_DIR/bin/mpicc FC=/chim/libs/openmpi/BUILD_DIR/bin/mpif90 CPPFLAGS="-I/chim/libs/openmpi/BUILD_DIR/include/openmpi -I/chim/libs/hdf5/BUILD_DIR/lib -I/chim/libs/netcdf/include" LDFLAGS="-L/chim/libs/openmpi/BUILD_DIR/lib/openmpi -L/chim/libs/hdf5/BUILD_DIR/lib -L/chim/libs/netcdf/lib" --prefix=${NETCDF} \
 && make install

# Build BLITZ
COPY blitz-0.10.tar.gz  .
RUN mkdir -p /chim/libs/blitz/BUILD_DIR  \
  && cp blitz-0.10.tar.gz /chim/libs/blitz \
  && cd /chim/libs/blitz \
  && tar -xvzf blitz-0.10.tar.gz  \
  && cd blitz-0.10 \
  && autoreconf -i  \
  && ./configure --prefix=/chim/libs/blitz/BUILD_DIR  \
  && make lib &> /chim/libs/blitz/build_log_blitz \
  && make install \
  && cd ..; rm blitz-0.10.tar.gz \
  && cd

# Build JASPER
COPY jasper-1.900.1.zip  .
RUN mkdir -p /chim/libs/jasper/BUILD_DIR  \
  && cp jasper-1.900.1.zip /chim/libs/jasper \
  && cd /chim/libs/jasper \
  && unzip jasper-1.900.1.zip \
  && cd jasper-1.900.1 \
  && ./configure --prefix=/chim/libs/jasper/BUILD_DIR  \
  && make \
  && make check\
  && make install &> /chim/libs/jasper/build_log_jasper \
  && cd ..; rm jasper-1.900.1.zip \
  && cd

# Build CMAKE
COPY cmake-3.13.4.tar.gz .
RUN mkdir -p /chim/libs/cmake/BUILD_DIR  \
  && cp cmake-3.13.4.tar.gz /chim/libs/cmake \
  && cd /chim/libs/cmake \
  && tar -xvzf cmake-3.13.4.tar.gz \
  && cd cmake-3.13.4 \
  && ./bootstrap \
  && make \
  && make install \
  && cd ..; rm cmake-3.13.4.tar.gz \
  && cd

# Build ECCODES
COPY eccodes-2.19.1-Source.tar.gz .
RUN mkdir -p /chim/libs/eccodes/BUILD_DIR  \
  && cp eccodes-2.19.1-Source.tar.gz /chim/libs/eccodes \
  && cd /chim/libs/eccodes \
  && tar -xvzf eccodes-2.19.1-Source.tar.gz \
  && mkdir build \
  && cd build \
  && cmake  ../eccodes-2.19.1-Source -DCMAKE_INSTALL_PREFIX=/chim/libs/eccodes/BUILD_DIR \
  && make \
  && ctest \
  && make install \
  && cd ..; rm eccodes-2.19.1-Source.tar.gz \
  && cd

# Build CHIMERE
COPY mychimere-gfortran .
RUN --mount=type=secret,id=secret_user --mount=type=secret,id=secret_pass cd /chim \
  && export CHIMERE_USER=$(cat /run/secrets/secret_user) \
  && export CHIMERE_PASS=$(cat /run/secrets/secret_pass) \
  && wget --no-check-certificate --user $CHIMERE_USER --password $CHIMERE_PASS https://www.lmd.polytechnique.fr/chimdata/chimere_v2020r3.tar.gz \
  && tar -xvzf chimere_v2020r3.tar.gz  \
  && cp ../mychimere-gfortran chimere_v2020r3/mychimere \
  && cd chimere_v2020r3 \
  && ./build-chimere.sh --arch gfortran &> /chim/chimere_v2020r3/build_log_chimere \
  && ./build-wrf.sh &> /chim/chimere_v2020r3/build_log_wrf \
  && cd /chim ; rm chimere_v2020r3.tar.gz \
  && cd


# TODO REVIEW these commands
RUN mkdir -p /var/run/sshd \
    && ssh-keygen -A \
    && sed -i 's/#PermitRootLogin yes/PermitRootLogin yes/g' /etc/ssh/sshd_config \
    && sed -i 's/#RSAAuthentication yes/RSAAuthentication yes/g' /etc/ssh/sshd_config \
    && sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/g' /etc/ssh/sshd_config


RUN mkdir -p /chim/chim_input /chim/chim_output \
 &&  chmod 6755 /chim /chim/chim_input /chim/chim_output /usr/local


# TODO REVIEW these commands
# Set environment for interactive container shells
RUN echo export LDFLAGS="-lm" >> /etc/bashrc \
 && echo export NETCDF=${NETCDF} >> /etc/bashrc \
 && echo export JASPERINC=/chim/libs/jasper/BUILD_DIR/include/ >> /etc/bashrc \
 && echo export JASPERLIB=/chim/libs/jasper/BUILD_DIR/lib/ >> /etc/bashrc \
 && echo export LD_LIBRARY_PATH="/opt/rh/devtoolset-8/root/usr/lib/gcc/x86_64-redhat-linux/8:/usr/lib64/openmpi/lib:${NETCDF}/lib:${LD_LIBRARY_PATH}" >> /etc/bashrc  \
 && echo export PATH=".:/opt/rh/devtoolset-8/root/usr/bin:/usr/lib64/openmpi/bin:${NETCDF}/bin:$PATH" >> /etc/bashrc

# TODO REVIEW these commands
RUN echo setenv LDFLAGS "-lm" >> /etc/csh.cshrc \
 && echo setenv NETCDF "${NETCDF}" >> /etc/csh.cshrc \
 && echo setenv JASPERINC "/chim/libs/jasper/BUILD_DIR/include/" >> /etc/csh.cshrc \
 && echo setenv JASPERLIB "/chim/libs/jasper/BUILD_DIR/lib/" >> /etc/csh.cshrc \
 && echo setenv LD_LIBRARY_PATH "/opt/rh/devtoolset-8/root/usr/lib/gcc/x86_64-redhat-linux/8:/usr/lib64/openmpi/lib:${NETCDF}/lib:${LD_LIBRARY_PATH}" >> /etc/csh.cshrc \
 && echo setenv PATH ".:/opt/rh/devtoolset-8/root/usr/bin:/usr/lib64/openmpi/bin:${NETCDF}/bin:$PATH" >> /etc/csh.cshrc

# TODO REVIEW these commands
RUN mkdir /chim/.ssh ; echo "StrictHostKeyChecking no" > /chim/.ssh/config
RUN mkdir -p /chim/.openmpi
RUN chown -R chimuser:chim /chim/

# all root steps completed above, now below as regular userID chimuser
USER chimuser
WORKDIR /chim

# TODO REVIEW these commands
ENV JASPERINC /chim/libs/jasper/BUILD_DIR/include
ENV JASPERLIB /chim/libs/jasper/BUILD_DIR/lib
ENV NETCDF_classic 1
ENV LD_LIBRARY_PATH /opt/rh/devtoolset-8/root/usr/lib/gcc/x86_64-redhat-linux/8:/usr/lib64/openmpi/lib:${NETCDF}/lib:${LD_LIBRARY_PATH}
ENV PATH  .:/opt/rh/devtoolset-8/root/usr/bin:/usr/lib64/openmpi/bin:${NETCDF}/bin:$PATH

RUN ssh-keygen -f /chim/.ssh/id_rsa -t rsa -N '' \
    && chmod 600 /chim/.ssh/config \
    && chmod 700 /chim/.ssh \
    && cp /chim/.ssh/id_rsa.pub /chim/.ssh/authorized_keys

VOLUME /chim
CMD ["/bin/tcsh"]

