#BootStrap: docker
#From: ubuntu:latest
BootStrap: debootstrap
OSVersion: trusty
MirrorURL: http://us.archive.ubuntu.com/ubuntu/

%environment
    PATH=/app/mash/scripts:/app/rakudobrew/bin:/app/mash/bin:$PATH

%runscript
    exec /app/mash/bin/mash "$@"

%post
    apt-get update
    apt-get install -y locales git build-essential wget curl libcurl4-openssl-dev libssl-dev 
    #
    # Put everything into $APP_DIR
    #
    export APP_DIR=/app
    mkdir -p $APP_DIR
    cd $APP_DIR

    #
    # bioconda code
    #
    cd $APP_DIR
	#change this for pytho3	
	wget https://repo.continuum.io/miniconda/Miniconda2-latest-Linux-x86_64.sh
    bash Miniconda2-latest-Linux-x86_64.sh -b -p /apps/miniconda
    rm Miniconda2-latest-Linux-x86_64.sh
    sudo ln -s /apps/miniconda/bin/python2.7 /usr/bin/python
    PATH="/apps/miniconda/bin:$PATH"

    conda update --prefix /apps/miniconda conda
    conda config --prepend channels conda-forge
    conda config --prepend channels bioconda

    conda install -y -c geopy numpy pandas python-dateutil pytz scipy six

    #so we dont get those stupid perl warnings
    locale-gen en_US.UTF-8
    #cleanup
    conda clean -a -y

    #
    # Mash binary
    #
    wget -O mash.tar https://github.com/marbl/Mash/releases/download/v2.0/mash-Linux64-v2.0.tar
    BIN=/app/mash/bin
    mkdir -p "$BIN"
    tar -xvf mash.tar -C "$BIN" --strip-components=1

    #
    # R setup
    #
    gpg --keyserver keyserver.ubuntu.com --recv-key E084DAB9
    gpg -a --export E084DAB9 | apt-key add -
    echo "deb http://cran.rstudio.com/bin/linux/ubuntu xenial/" | \
        tee -a /etc/apt/sources.list
    apt-get install -y r-base r-base-dev

    cat << EOF > .Rprofile
local({
  r = getOption("repos")
  r["CRAN"] = "http://mirrors.nics.utk.edu/cran/"
 options(repos = r)
})
EOF

    /usr/bin/Rscript /app/mash/scripts/install.r

    #
    # Mount points for TACC directories
    #
    mkdir /home1
    mkdir /scratch
    mkdir /work
