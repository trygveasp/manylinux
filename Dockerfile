FROM quay.io/pypa/manylinux2014_x86_64

RUN /bin/bash
RUN yum install -y flex libaec-devel liblas-devel lapack64-devel ksh openmpi-devel wget curl-devel less vi perl-Digest-SHA libxml2-devel

ENV FC="/opt/rh/devtoolset-10/root/usr/bin/gfortran"
ENV CC="/opt/rh/devtoolset-10/root/usr/bin/gcc"
ENV PATH="${PATH}:/usr/lib64/openmpi/bin/"     

# Install zlib 
WORKDIR /data/build-zlib
RUN wget http://www.zlib.net/zlib-1.3.tar.gz
RUN tar -xzvf zlib-1.3.tar.gz
WORKDIR /data/build-zlib/zlib-1.3
ENV ZDIR=/usr/local
RUN ./configure --prefix=${ZDIR}
RUN make check
RUN make install

# Install hdf5
WORKDIR /data/build-hdf5
RUN wget https://github.com/HDFGroup/hdf5/releases/download/hdf5-1_14_3/hdf5-1_14_3.tar.gz
RUN tar -xzvf hdf5-1_14_3.tar.gz
WORKDIR /data/build-hdf5/hdfsrc/
ENV H5DIR=/usr/local
RUN ./configure --enable-fortran --with-zlib=${ZDIR} --prefix=${H5DIR} --enable-hl
RUN make check
RUN make install

# Install netcdf-c
WORKDIR /data/build-netcdf-c
RUN wget https://github.com/Unidata/netcdf-c/archive/refs/tags/v4.9.2.tar.gz
RUN tar -xzvf v4.9.2.tar.gz
WORKDIR /data/build-netcdf-c/netcdf-c-4.9.2
ENV LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${H5DIR}/lib
ENV NCDIR=/usr/local
RUN CPPFLAGS='-I${H5DIR}/include -I${ZDIR}/include' LDFLAGS='-L${H5DIR}/lib -L${ZDIR}/lib' ./configure --prefix=${NCDIR}
RUN make check
RUN make install

# Install netcdf-fortran
WORKDIR /data/build-fortran
RUN wget https://github.com/Unidata/netcdf-fortran/archive/refs/tags/v4.6.1.tar.gz
RUN tar -xzvf v4.6.1.tar.gz
WORKDIR /data/build-fortran/netcdf-fortran-4.6.1
ENV LD_LIBRARY_PATH=${NCDIR}/lib:${LD_LIBRARY_PATH}
ENV NFDIR=/usr/local
RUN CPPFLAGS='-I${NCDIR}/include' LDFLAGS='-L${NCDIR}/lib' ./configure --prefix=${NFDIR}
RUN make
RUN make install

# Install eccodes
WORKDIR /data/build-eccodes
RUN wget https://confluence.ecmwf.int/download/attachments/45757960/eccodes-2.32.1-Source.tar.gz
RUN tar -xzf  eccodes-2.32.1-Source.tar.gz
WORKDIR /data/build-eccodes/build
RUN cmake -DCMAKE_INSTALL_PREFIX=/usr/local ../eccodes-2.32.1-Source
RUN make
RUN make install

# Install Harmonie
ENV hm_rev="/data/Harmonie/"
ENV CMAKE_CONFIG="${hm_rev}/util/cmake/config/config.manylinux.GNU.json"
ENV INSTALL_DIR="/data/harmonie-install/"
ENV BUILD_DIR="/data/harmonie-build/"
ENV PATH="${INSTALL_DIR}:${PATH}"

ENV NPROC=8
ENV FP_PRECISION=double

# Install bufr
WORKDIR ${BUILD_DIR}/bufr_405
RUN cmake $hm_rev/util/auxlibs/bufr_405 -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR -DCONFIG_FILE=${CMAKE_CONFIG}
RUN cmake --build . -- -j$NPROC
RUN cmake --build . --target install

# Install gribex_370 
WORKDIR ${BUILD_DIR}/gribex_370
RUN cmake $hm_rev/util/auxlibs/gribex_370 -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR -DCONFIG_FILE=${CMAKE_CONFIG}
RUN cmake --build . -- -j$NPROC
RUN cmake --build . --target install

# Install rgb_001
WORKDIR ${BUILD_DIR}/rgb_001
RUN cmake $hm_rev/util/auxlibs/rgb_001 -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR -DCONFIG_FILE=${CMAKE_CONFIG}
RUN cmake --build . -- -j$NPROC
RUN cmake --build . --target install

# Install dummies_006/mpidummy
WORKDIR ${BUILD_DIR}/dummies_006-mpidummy
RUN cmake $hm_rev/util/auxlibs/dummies_006/mpidummy -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR -DCONFIG_FILE=${CMAKE_CONFIG}
RUN cmake --build . -- -j$NPROC
RUN cmake --build . --target install

# Configure Harmonie
WORKDIR ${BUILD_DIR}
RUN cmake $hm_rev/src -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} -DCMAKE_INSTALL_RPATH_USE_LINK_PATH=YES -DCONFIG_FILE=${CMAKE_CONFIG}

# Build Harmonie
RUN cmake --build . -- -j$NPROC

# Install Harmonie
RUN cmake --build . --target install -- -j$NPROC
ENV BINDIR="${INSTALL_DIR}/bin"
ENV PATH="${BINDIR}:${PATH}"
RUN cp -p ${BINDIR}/ioassign ${BINDIR}/IOASSIGN
RUN cp -p ${BINDIR}/ODBTOOLS ${BINDIR}/shuffle
RUN cp -p ${BINDIR}/dcagen   ${BINDIR}/dcagen.x
RUN cp -p ${BINDIR}/OFFLINE  ${BINDIR}/SURFEX

WORKDIR ${BUILD_DIR}/build-gl
ENV PATH="${PATH}:/usr/lib64/openmpi/bin/"
RUN cmake $hm_rev/util/gl -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} -DCMAKE_INSTALL_RPATH_USE_LINK_PATH=YES -DCONFIG_FILE=${hm_rev}/util/gl/config/config.manylinux.GNU.json -Dharmonie_DIR=$INSTALL_DIR/lib/cmake/harmonie
RUN cmake --build . -v
RUN cmake --build . --target install

WORKDIR /data
