# Docker container for CHIMERE

### This docker image is based on
https://www.lmd.polytechnique.fr/chimere/docs/CHIMEREdoc_v2020r3.pdf

TODO: UNFORK this repository by doing (Since we are not using WRF implemented by NCAR)
https://stackoverflow.com/questions/29326767/unfork-a-github-fork-without-deleting/41486339#41486339


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


1) Set environment variables for Chimere credentials in order to download the Chimere resources. 
   1) `export CHIMERE_USER=****`
   2) `export CHIMERE_PASS=****`
2) Get the docker image:
   1) Option 1: Get the *chimere_conae* image from docker hub (This is a public repository, https://hub.docker.com/repository/docker/lvc0107/chimere_conae,
   but it's convenient for security reasons to store it in a private one, and change lvc0107 to conae_user).
      1) `docker pull lvc0107/chimere_conae:master` or `docker pull lvc0107/chimere_conae:v1.<build_number>` where <build_number> identify a specific build.
      2) `mkdir -p CONAE_WRF_CHIMERE/INPUT`
      3) `mkdir -p CONAE_WRF_CHIMERE/OUTPUT`
   2) Option 2: Build the image from the source code.
      1) `git clone git@github.com:lvc0107/CONAE_WRF_CHIMERE.git` (SSH)
         or `git clone https://github.com/lvc0107/CONAE_WRF_CHIMERE.git` (HTTPS)
      2) `cd CONAE_WRF_CHIMERE`
      3) `DOCKER_BUILDKIT=1 docker build -t chimere_conae:<new_tag> --secret id=secret_user,env=CHIMERE_USER --secret id=secret_pass,env=CHIMERE_PASS .` 
      where <new_tag> identify the latest change.
      4) After running locally and checking all tests are ok, if there are any changes over any versioned file, 
      it should be pushed to GitHub. (develop branch).This will trigger a GitHub action that creates a new docker image in 
      the development environment. If the docker image is build successfully on the development branch, 
      the next step is to rebase the development branch into the master branch via pull request process in Github.
      If the rebase process is successful, a new Github action is triggered in order to build and push the docker image 
      to the docker hub registry with a master and v1.<build_number> tags.

3) Download the emiSURF anthropogenic emissions pre-processor
   1) get emiSURF2020r4.tar.gz
      1) `wget --user $CHIMERE_USER --password $CHIMERE_PASS https://www.lmd.polytechnique.fr/chimdata/emisurf2020r4.tar.gz`
      2) `tar -xvzf emisurf2020r4.tar.gz`
      3) `rm emisurf2020r4.tar.gz`
         
4) Download from Chimere page all the required DB.
   1) `cd CONAE_WRF_CHIMERE/INPUT`
      1) get TestCase2020r3.tar.gz 
         1) `wget --user $CHIMERE_USER --password $CHIMERE_PASS https://www.lmd.polytechnique.fr/chimdata/TestCase2020r3.tar.gz`
         2) `tar -xvzf TestCase2020r3.tar.gz`
         3) `rm TestCase2020r3.tar.gz`
      2) get BIGFILES2020.tar.gz
         1) `wget --user $CHIMERE_USER --password $CHIMERE_PASS https://www.lmd.polytechnique.fr/chimdata/BIGFILES2020.tar.gz`
         2) `tar -xvzf BIGFILES2020.tar.gz`
         3) `rm BIGFILES2020.tar.gz`
      3) get MEGAN_30s.tar.gz
         1) `wget --user $CHIMERE_USER --password $CHIMERE_PASS https://www.lmd.polytechnique.fr/chimdata/MEGAN_30s.tar.gz`
         2) `tar -xvzf MEGAN_30s.tar.gz`
         3) `rm MEGAN_30s.tar.gz`
      4) get databases for emiSURF
         1) `wget --user $CHIMERE_USER --password $CHIMERE_PASS https://www.lmd.polytechnique.fr/chimdata/emisurf_data.tar.gz`
         2) `tar -xvzf emisurf_data.tar.gz`
         3) `rm emisurf_data.tar.gz`
        
5) Create chimere.par file. TODO COMPLETE 
6) Create and enter the container:
   1) `cd CONAE_WRF_CHIMERE`
   2) `docker run -v $(pwd)/INPUT/BIGFILES2020:/chim/chimere_v2020r3/...<TODO COMPLETE HERE path in Chimere>/ \
   -v $(pwd)/OUTPUT:/chim/chimere_v2020r3/...<TODO COMPLETE HERE path in Chimere> \
   -it --name chimere_container lvc0107/chimere_conae /bin/tcsh`
   You can verify that Chimere, WRF and WPS have been successfully compiled by doing the following:
`cat ./chimere_v2020r3/build_log*`.
   3) If there are changes on the docker container we can create a new docker image from the updated container.
      1) TODO think how to keep these new changes in Github
   4) `exit`

7) Run the model: TODO COMPLETE
   1) `docker start chimere_container`
   2) Copy the chimere.par file from host into the container
      1) `cd CONAE_WRF_CHIMERE`
      2) `docker cp chimere.par chimere_container:/chim/chimere_v2020r3/...TOOD COMPLETE this path /chimere.par`
      3) Execute the run_simulation.sh script providing parameters
         1) `docker exec -it chimere_container sh -c "./chimere_v2020r3/run_simulation.sh firstdate=2013061500 lastdate=2013083100 incday=5 parfile=chimere.par"`
      4) Get the results from the output_chimere folder.

# TODO 
1) check Chimere in online mode.
2) Check multiples instances of the container in the host.
   1) Docker compose or K8
3) openmpi in the host in order to link multiples containers.
