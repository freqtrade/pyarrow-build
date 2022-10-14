FROM python:3.9.15-slim-bullseye as base

# Setup env
ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8
# start pyarrow build
ARG ARROW_VERSION=9.0.0

RUN apt-get update \
    && apt-get -y install \
        sudo \
        autoconf \
        bison \
        ca-certificates \
        cmake \
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
        libssl-dev \
        make \
        ninja-build \
        pkg-config \
        rapidjson-dev \
        tzdata \
        liblz4-dev \
        libsnappy-dev \
        libzstd-dev \
 && rm -rf /var/lib/apt/lists/*

RUN echo "[global]\nextra-index-url=https://www.piwheels.org/simple" > /etc/pip.conf \
  && python -m pip install -U pip \
  && python -m pip install wheel setuptools numpy pandas==1.4.3 psutil Cython \
  && which python

WORKDIR /build/arrow
RUN curl --silent --show-error --fail --location \
      https://github.com/apache/arrow/archive/apache-arrow-${ARROW_VERSION}.tar.gz \
  | tar --strip-components=1 -xz

ENV ARROW_HOME=/dist
ENV CMAKE_BUILD_PARALLEL_LEVEL=3

WORKDIR /build/arrow/cpp/release
RUN cmake \
    -DPYTHON_EXECUTABLE=/usr/local/bin/python3 \
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
    -DARROW_PLASMA=ON \
          .. \
 && make -j ${CMAKE_BUILD_PARALLEL_LEVEL} \
 && make install

ENV PYARROW_CMAKE_GENERATOR=Ninja
ENV PYARROW_CMAKE_OPTIONS="-DARROW_USE_LD_GOLD=ON"
ENV PYARROW_WITH_PLASMA=1
ENV PYARROW_WITH_PARQUET=1
ENV PYARROW_BUNDLE_ARROW_CPP=1


WORKDIR /build/arrow/python
RUN pip install -r requirements-wheel-build.txt \
  && python3 setup.py build_ext --build-type="release" --bundle-arrow-cpp bdist_wheel \
  && ls -l /build/arrow/python/dist

# COPY --from=pyarrow-deps /build/arrow/python/dist/pyarrow-*.whl .
