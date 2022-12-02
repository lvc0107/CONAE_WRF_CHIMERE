# Docker container for CHIMERE

### This docker image is based on
https://www.lmd.polytechnique.fr/chimere/docs/CHIMEREdoc_v2020r3.pdf

The docker image is set in a Centos.7 OS.
Chimere is ready to build using the gfortran compiler.

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

### Requirements in the host: Docker.20.10.13 or greater

`docker --version`


1) Get the docker image:
   1) Option 1: Get the *chimere_conae* image from docker hub (This is a public repository,
   but it's convenient for security reasons to store it in a private one, and change lvc0107 to conae_user).
      1) `docker pull lvc0107/chimere_conae:latest`
      2) `mkdir CONAE_WRF_CHIMERE`
   3) Option 2: Build the image from the source code.
      1) `git clone git@github.com:lvc0107/CONAE_WRF_CHIMERE.git` (SSH)
         or `git clone https://github.com/lvc0107/CONAE_WRF_CHIMERE.git` (HTTPS)
      2) `cd CONAE_WRF_CHIMERE`
      3) Set environment variables for Chimere credentials in order to download the Chimere source code.
         1) `export CHIMERE_USER=****`
         2) `export CHIMERE_PASS=****`
      4) `DOCKER_BUILDKIT=1 docker build -t chimere_conae:<new_tag> --secret id=secret_user,env=CHIMERE_USER --secret id=secret_pass,env=CHIMERE_PASS .` where <new_tag> identify the latest change
         
      5) Push the new image to docker hub (assuming a private docker repository already exists with a <conae_user>).
         1) `docker tag chimere_conae <conae_user>/chimere_conae`
         2) `docker login --username <conae_user>`
         3) `docker push <conae_user>/chimere_conae`
2) Create and enter the container:
   1) `cd CONAE_WRF_CHIMERE`
   2) `docker run -v $(pwd)/INPUT:/wrf/wrfinput -v $(pwd)/OUTPUT:/wrf/wrfoutput -it --name chimere_container lvc0107/chimere_conae /bin/tcsh`
   You can verify that Chimere, WRF and WPS have been successfully compiled by doing the following:
   3) `cat ./chimere_v2020r3/build_log*`
   4) If there are changes on the docker container we can create a new docker image from the updated container
   5) `COMPLETE HERE`
   6) `exit`

3) Download from Chimere page all the required DB.
   1) `cd CONAE_WRF_CHIMERE` 
      1) get TestCase2020r3.tar.gz, `tar -xvzf TestCase2020r3.tar.gz`
      2) get BIGFILES2020.tar.gz, `tar -xvzf BIGFILES2020.tar.gz`
      3) get MEGAN_30s.tar.gz, `tar -xvzf MEGAN_30s.tar.gz`
   2) Copy DB into INPUT folder. TODO COMPLETE
   
4) Run the model: TODO COMPLETE
   1) `docker start chimere_container`
   2) `docker exec -it chimere_container /bin/tcsh`
   3) `./chimere_v2020r3/chimere.sh` TODO COMPLETE
   4) Get the results from the output_chimere folder.

# TODO 
1) check Chimere in online mode.
2) Check multiples instances of the container in the host.
   1) Docker compose or K8
3) openmpi in the host in order to link multiples containers.
