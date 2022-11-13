# Docker Container for CHIMERE.

### This docker image is based on
https://www.lmd.polytechnique.fr/chimere/docs/CHIMEREdoc_v2020r3.pdf

The docker image is set in a Centos.7 OS.
Chimere is ready to build using the gfortran compiler

Chimere and its dependencies installed in the docker image are:

* Chimere https://www.lmd.polytechnique.fr/chimere/2020_getcode.php chimere_v2020r3.tar.gz
* GNU https://gcc.gnu.org/ GCC 4.7.2
* Open MPI https://www.open-mpi.org/software/ompi/ openmpi-2.0.4
* HDF5 https://support.hdfgroup.org/ftp/HDF5/releases/ HDF5 1.8.20
* Unidata NetCDF-C https://github.com/Unidata/netcdf-c/releases netCDF-C 4.6.0
* Unidata NetCDF-Fortran https://github.com/Unidata/netcdf-fortran/releases netCDF-Fortran 4.4.4
* Blitz https://sourceforge.net/projects/blitz blitz-0.10
* ecCodes https://confluence.ecmwf.int/display/ECC eccodes-2.19.1
* Jasper https://www.ece.uvic.ca/~frodo/jasper/#download JasPer 1.900.1
* Cmake https://github.com/Kitware/CMake/releases/download/v3.13.4/cmake-3.13.4.tar.gz cmake-3.13.4

###Requirements in the host: Docker.20.10.13


1) Get the docker image:
   1) Option 1: Get the *chimere_conae* image from docker hub
      1) `docker pull lvc0107/chimere_conae:latest` 
   2) Option 2: Build the image from the source code
      1) `git clone git@github.com:lvc0107/CONAE_WRF_CHIMERE.git` (SSH)
         or `git clone https://github.com/lvc0107/CONAE_WRF_CHIMERE.git` (HTTPS)
      2) `cd CONAE_WRF_CHIMERE`
      3) `docker build -t chimere_conae`
2) Create container:
   1) `docker run -it --name chimere_container chimere_conae /bin/tcsh`
      1) Inside the docker container, build Chimere # TODO probably not needed
      2) `cd chimere` # TODO probably not needed
      3) `./build-chimere.sh --arch gfortran`# TODO probably not needed
      4) `./build-wrf.sh` # TODO probably not needed
   2) Run tests
   3) Get the results from the output_chimere folder


# TODO 
1) output volumes
2) check Chimere in online mode
3) Check multiples instances of the container in the host
   1) Docker compose or K8
4) openmpi in the host in order to link multiples containers
