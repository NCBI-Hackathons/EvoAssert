FROM ubuntu:18.04 as base
MAINTAINER Phillip Rak <phillip.rak@northwestern.edu>

# Update the container
RUN apt-get update && apt-get upgrade -y

RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true

# Install tzdata
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y tzdata

# Install utilities
RUN apt-get update && \
    apt-get install locales wget python3-pip git curl libxml2-dev libcurl4-openssl-dev libssl-dev -y

# Configure the default locale for r-base install
RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

RUN ln -fs /usr/share/zoneinfo/US/Pacific-New /etc/localtime && dpkg-reconfigure -f noninteractive tzdata

# Install r-base and project dependencies
RUN apt-get install r-base -y
RUN Rscript -e "install.packages('readr')" -e "install.packages('dplyr')" -e "install.packages('stringr')" -e "install.packages('RCurl')" -e "install.packages('XML')" -e "install.packages('httr')"

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
   libfftw3-dev \
   gcc && apt-get clean \
 && rm -rf /var/lib/apt/lists/*
RUN Rscript -e 'source("http://bioconductor.org/biocLite.R")' -e 'biocLite("biomaRt")'

# Install python dependencies
RUN pip3 install pandas requests

# Clone the repo so that we can run our scripts
RUN git clone -b feature/container https://github.com/NCBI-Hackathons/OrthoGrasp.git

# Create data dir to house data
WORKDIR /OrthoGrasp
RUN mkdir data
WORKDIR /OrthoGrasp/data

# Get data from omabrowser
RUN wget https://omabrowser.org/All/oma-ensembl.txt.gz && \
    gunzip oma-ensembl.txt.gz

# Download the eggnog data
RUN wget http://eggnogdb.embl.de/download/eggnog_4.5/data/meNOG/meNOG.members.tsv.gz \
    && gunzip meNOG.members.tsv.gz

# Run python script to copy data from omabrowser
WORKDIR /OrthoGrasp/scripts
RUN python3 oma-download.py -o /OrthoGrasp/data/
    # TODO: Make an init script that will docker exec this script

# Run perl script to parse data downloaded in last step and generated by python script
RUN chmod +x parseAllOMA.sh && \
    ./parseAllOMA.sh
    # TODO: Make an init script that will docker exec this script

# Run processing script for eggnog data
COPY scripts/findbiomartdataset.R /OrthoGrasp/scripts
WORKDIR /OrthoGrasp/scripts
RUN Rscript eggnog_species_filter.R
RUN Rscript findbiomartdataset.R

# TODO: Make an init script that will docker exec this script

# TODO: We need to install R; Any R dependencies?
# TODO: We need to install Jupyter Notebook
# TODO: We need to launch Jupyter Notebook
