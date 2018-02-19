FROM ubuntu:14.04
MAINTAINER Lea Vinokur <lea.vinokur@gmail.com>
ARG DEBIAN_FRONTEND=noninteractive
# Core system capabilities required
RUN apt-get update && apt-get install -y git python libeigen3-dev zlib1g-dev wget bsdtar software-properties-common

# Now that we have software-properties-common, can use add-apt-repository to get to g++ version 5, which is required by JSON for Modern C++
RUN add-apt-repository ppa:ubuntu-toolchain-r/test
RUN apt-get update && apt-get install -y g++-5

# Neurodebian
RUN wget -O- http://neuro.debian.net/lists/trusty.au.full | tee /etc/apt/sources.list.d/neurodebian.sources.list
RUN apt-key adv --recv-keys --keyserver hkp://pgp.mit.edu:80 0xA5D32F012649A5A9 && apt-get update

# fsl
RUN apt-get install -y fsl-5.0-core
RUN apt-get install -y fsl-first-data

# Eddy
RUN rm -f `which eddy`
RUN wget -qO- https://fsl.fmrib.ox.ac.uk/fsldownloads/patches/eddy-patch-fsl-5.0.9/centos6/eddy_openmp > /usr/share/fsl/5.0/bin/eddy_openmp
RUN wget -qO- https://fsl.fmrib.ox.ac.uk/fsldownloads/patches/eddy-patch-fsl-5.0.9/centos6/eddy_cuda7.5 > /usr/share/fsl/5.0/bin/eddy_cuda
RUN chmod 775 /usr/share/fsl/5.0/bin/eddy_openmp
RUN chmod 775 /usr/share/fsl/5.0/bin/eddy_cuda

# Freesurfer
RUN wget -qO- ftp://surfer.nmr.mgh.harvard.edu/pub/dist/freesurfer/5.3.0/freesurfer-Linux-centos4_x86_64-stable-pub-v5.3.0.tar.gz | tar zx -C /opt \
    --exclude='freesurfer/trctrain' \
    --exclude='freesurfer/subjects/fsaverage_sym' \
    --exclude='freesurfer/subjects/fsaverage3' \
    --exclude='freesurfer/subjects/fsaverage4' \
    --exclude='freesurfer/subjects/fsaverage5' \
    --exclude='freesurfer/subjects/fsaverage6' \
    --exclude='freesurfer/subjects/cvs_avg35' \
    --exclude='freesurfer/subjects/cvs_avg35_inMNI152' \
    --exclude='freesurfer/subjects/bert' \
    --exclude='freesurfer/subjects/V1_average' \
    --exclude='freesurfer/average/mult-comp-cor' \
    --exclude='freesurfer/lib/cuda' \
    --exclude='freesurfer/lib/qt'
RUN /bin/bash -c 'touch /opt/freesurfer/.license'

#HCP Pipelines other prerequisites:
RUN apt-get install -y connectome-workbench
RUN apt-get install -y python-numpy
RUN apt-get install -y python-scipy
RUN apt-get install -y python-pip
RUN pip install nibabel
RUN git clone https://github.com/Washington-University/gradunwarp.git && cd gradunwarp && git checkout v1.0.3 && python setup.py install

#Pipelines
RUN git clone https://github.com/Washington-University/Pipelines.git && cd Pipelines && git checkout v3.22.0

#MRtrix3 setup
ENV CXX=/usr/bin/g++-5
RUN git clone https://github.com/MRtrix3/mrtrix3.git mrtrix3 && cd mrtrix3 && git checkout 3.0_RC2 && python configure -nogui && NUMBER_OF_PROCESSORS=1 python build
#RUN echo $'FailOnWarn: 1\n' > /etc/mrtrix.conf


# Environment variables setup
ENV FSLDIR=/usr/share/fsl/5.0
ENV FSL_DIR="${FSLDIR}"
ENV FSLOUTPUTTYPE=NIFTI_GZ
ENV FSLMULTIFILEQUIT=TRUE
ENV LD_LIBRARY_PATH=/usr/lib/fsl/5.0
ENV PATH=/opt/freesurfer/bin:/opt/freesurfer/mni/bin:/usr/lib/fsl/5.0:/usr/lib/ants:/mrtrix3/bin:/opt/eddy:$PATH
ENV PYTHONPATH=/mrtrix3/lib

# Make FreeSurfer happy
ENV OS Linux
ENV SUBJECTS_DIR=/opt/freesurfer/subjects
ENV FSF_OUTPUT_FORMAT=nii.gz
ENV MNI_DIR=/opt/freesurfer/mni
ENV LOCAL_DIR=/opt/freesurfer/local
ENV FREESURFER_HOME=/opt/freesurfer
ENV FSFAST_HOME=/opt/freesurfer/fsfast
ENV MINC_BIN_DIR=/opt/freesurfer/mni/bin
ENV MINC_LIB_DIR=/opt/freesurfer/mni/lib
ENV MNI_DATAPATH=/opt/freesurfer/mni/data
ENV FMRI_ANALYSIS_DIR=/opt/freesurfer/fsfast
ENV PERL5LIB=/opt/freesurfer/mni/lib/perl5/5.8.5
ENV MNI_PERL5LIB=/opt/freesurfer/mni/lib/perl5/5.8.5

# HCP Pipelines  environment variables
# RUN . /Pipelines/Examples/Scripts/SetUpHCPPipeline.sh
ENV HCPPIPEDIR=/Pipelines
ENV CARET7DIR=/usr/bin

ENV HCPPIPEDIR_Templates=${HCPPIPEDIR}/global/templates
ENV HCPPIPEDIR_Bin=${HCPPIPEDIR}/global/binaries
ENV HCPPIPEDIR_Config=${HCPPIPEDIR}/global/config

ENV HCPPIPEDIR_PreFS=${HCPPIPEDIR}/PreFreeSurfer/scripts
ENV HCPPIPEDIR_FS=${HCPPIPEDIR}/FreeSurfer/scripts
ENV HCPPIPEDIR_PostFS=${HCPPIPEDIR}/PostFreeSurfer/scripts
ENV HCPPIPEDIR_fMRISurf=${HCPPIPEDIR}/fMRISurface/scripts
ENV HCPPIPEDIR_fMRIVol=${HCPPIPEDIR}/fMRIVolume/scripts
ENV HCPPIPEDIR_tfMRI=${HCPPIPEDIR}/tfMRI/scripts
ENV HCPPIPEDIR_dMRI=${HCPPIPEDIR}/DiffusionPreprocessing/scripts
ENV HCPPIPEDIR_dMRITract=${HCPPIPEDIR}/DiffusionTractography/scripts
ENV HCPPIPEDIR_Global=${HCPPIPEDIR}/global/scripts
ENV HCPPIPEDIR_tfMRIAnalysis=${HCPPIPEDIR}/TaskfMRIAnalysis/scripts
ENV MSMBin=${HCPPIPEDIR}/MSMBinaries



RUN mkdir /hcp_input
RUN mkdir /bids_output
RUN mkdir /hsm
RUN mkdir /scratch
RUN mkdir /vlsci

COPY coeff_SC72C_Skyra.grad /Pipelines/global/config/coeff_SC72C_Skyra.grad
COPY HCP_preproc.py /code/run.py
RUN chmod 775 /code/run.py

ENTRYPOINT ["/code/run.py"]
