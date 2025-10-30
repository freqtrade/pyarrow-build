ARG PYTHON_VERSION="3.11"
FROM python:${PYTHON_VERSION}-slim-bookworm AS base

# Setup env
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
# start pyarrow build
ARG ARROW_VERSION=21.0.0

RUN echo "deb http://deb.debian.org/debian bookworm-backports main" >> /etc/apt/sources.list \
    && apt-get update \
    && apt-get -y install \
        sudo \
        autoconf \
        bison \
        ca-certificates \
        curl \
        flex \
        g++ \
        gcc \
        libatlas-base-dev \
        libgfortran5 \
        libboost-dev \
        libboost-filesystem-dev \
        libboost-regex-dev \
        libboost-system-dev \
        libgflags-dev \
        libutf8proc-dev\
        libjemalloc-dev \
        libopenblas-dev \
        libssl-dev \
        make \
        ninja-build \
        pkg-config \
        rapidjson-dev \
        tzdata \
        liblz4-dev \
        libsnappy-dev \
        libzstd-dev \
        # cmake from debian-backports
        && apt-get -t bookworm-backports install -y \
        cmake \
 && rm -rf /var/lib/apt/lists/*

RUN echo "[global]\nextra-index-url=https://www.piwheels.org/simple" > /etc/pip.conf \
  && python -m pip install -U pip \
  && python -m pip install wheel setuptools numpy pandas psutil cython \
  && which python

WORKDIR /build/arrow
RUN curl --silent --show-error --fail --location \
      https://github.com/apache/arrow/archive/apache-arrow-${ARROW_VERSION}.tar.gz \
  | tar --strip-components=1 -xz

ENV ARROW_HOME=/dist
ENV CMAKE_BUILD_PARALLEL_LEVEL=3

WORKDIR /build/arrow/cpp/release
RUN cmake \
    -DPYTHON_EXECUTABLE=/usr/local/bin/python \
    -DCMAKE_INSTALL_PREFIX=$ARROW_HOME \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DARROW_WITH_BZ2=ON \
    -DARROW_WITH_ZLIB=ON \
    -DARROW_WITH_ZSTD=ON \
    -DARROW_WITH_LZ4=ON \
    -DARROW_WITH_SNAPPY=ON \
    -DARROW_PARQUET=ON \
    -DARROW_PYTHON=ON \
    -DARROW_BUILD_TESTS=OFF \
    -DARROW_DATASET=ON \
    -DARROW_PLASMA=ON \
          .. \
 && make -j ${CMAKE_BUILD_PARALLEL_LEVEL} \
 && make install

ENV PYARROW_CMAKE_GENERATOR=Ninja
ENV PYARROW_CMAKE_OPTIONS="-DARROW_USE_LD_GOLD=ON"
ENV PYARROW_WITH_PLASMA=1
ENV PYARROW_WITH_PARQUET=1
ENV PYARROW_BUNDLE_ARROW_CPP=1
ENV LD_LIBRARY_PATH=$ARROW_HOME
ENV CMAKE_PREFIX_PATH=$ARROW_HOME/lib:$LD_LIBRARY_PATH
ENV Arrow_DIR=$ARROW_HOME
ENV Parquet_DIR=$ARROW_HOME
ENV Plasma_DIR=$ARROW_HOME


WORKDIR /build/arrow/python
RUN pip install -r requirements-wheel-build.txt cython \
  && python setup.py build_ext --build-type="release" --bundle-arrow-cpp bdist_wheel \
  && ls -l /build/arrow/python/dist

# COPY --from=pyarrow-deps /build/arrow/python/dist/pyarrow-*.whl .
