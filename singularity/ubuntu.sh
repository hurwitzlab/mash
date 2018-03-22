#BootStrap: docker
#From: ubuntu:latest
BootStrap: debootstrap
OSVersion: xenial
MirrorURL: http://us.archive.ubuntu.com/ubuntu/

%environment
    PATH=/app/mash/scripts:/app/rakudobrew/bin:/app/mash/bin:$PATH
    CONDA="/apps/miniconda"
    PYTHONPATH="$CONDA/pkgs"
    PYTHONBIN="$CONDA/bin"
    PYTHON="$CONDABIN/python"
    PATH="$PYTHONBIN:$PATH"

%runscript
    exec /app/mash/bin/mash "$@"

%post
    apt-get update
    apt-get install -y locales git build-essential wget curl libcurl4-openssl-dev libssl-dev sudo
    #
    # Put everything into $APP_DIR
    #
    export APP_DIR=/app
    mkdir -p $APP_DIR
    cd $APP_DIR
    git clone https://github.com/hurwitzlab/mash.git

    #
    # bioconda code
    #
    cd $APP_DIR
	#change this for pytho3	
	wget https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh
    bash Miniconda3-latest-Linux-x86_64.sh -b -p /apps/miniconda
    rm Miniconda3-latest-Linux-x86_64.sh
    sudo ln -s /apps/miniconda/bin/python3.6 /usr/bin/python
    PATH="/apps/miniconda/bin:$PATH"

    conda update --prefix /apps/miniconda conda
    conda config --prepend channels conda-forge
    conda config --prepend channels bioconda

    conda install -y geopy numpy pandas python-dateutil pytz scipy six

    #so we dont get those stupid perl warnings
    locale-gen en_US.UTF-8


    #
    # Mash binary
    #
    wget -O mash.tar https://github.com/marbl/Mash/releases/download/v2.0/mash-Linux64-v2.0.tar
    BIN=/app/mash/bin
    mkdir -p "$BIN"

    tar -xvf mash.tar -C /tmp
    mv /tmp/mash-Linux64-v2.0/mash /app/mash/bin

    #
    # R setup
    #
    conda install -y r-base r-devtools 

    cat << EOF > .Rprofile
local({
  r = getOption("repos")
  r["CRAN"] = "http://mirrors.nics.utk.edu/cran/"
 options(repos = r)
})
EOF

    Rscript /app/mash/scripts/install.r

    #cleanup
    conda clean -a -y
    #
    # Mount points for TACC directories
    #
    mkdir /home1
    mkdir /scratch
    mkdir /work
