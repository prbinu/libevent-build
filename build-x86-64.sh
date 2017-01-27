#!/bin/bash
# Environment variables
#  TS_BUILDDIR : Build root directory. Default to current working directory
#  TS_INSTALLDIR : Installation directory. Default to ${TS_BUILDDIR}
#
set -e
CD=`pwd`
OS=`uname`

if [ "${OS}" != "Darwin" ] && [ "${OS}" != "Linux" ]; then
  echo "Error: ${OS} is not a currently supported platform."
  exit 1
fi

[[ -z "${TS_BUILDDIR}" ]] && BUILDDIR="${CD}" || BUILDDIR="${TS_BUILDDIR}"

echo ">>> Build DIR: ${BUILDDIR}"
BUILDDIR=${BUILDDIR}/ts-build-root

test -z ${BUILDDIR} || /bin/mkdir -p ${BUILDDIR}
test -z ${BUILDDIR}/downloads || /bin/mkdir -p ${BUILDDIR}/downloads
test -z ${BUILDDIR}/build || /bin/mkdir -p ${BUILDDIR}/build

[[ -z "${TS_INSTALLDIR}" ]] && OUTDIR="${BUILDDIR}" || OUTDIR="${TS_INSTALLDIR}"

echo ">>> Install DIR: ${OUTDIR}"
export PKG_CONFIG_PATH=${OUTDIR}/lib/pkgconfig

OPENSSL_VERSION="1.0.2-chacha"
LIBEVENT_VERSION="release-2.1.7-rc"
ZLIB_VERSION="zlib-1.2.11"

FILE="${BUILDDIR}/downloads/${OPENSSL_VERSION}.zip"
if [ ! -f $FILE ]; then
  echo "Downloading $FILE.."
  cd ${BUILDDIR}/downloads
  curl -OL https://github.com/PeterMosmans/openssl/archive/${OPENSSL_VERSION}.zip
fi

cd ${BUILDDIR}/build
unzip ${BUILDDIR}/downloads/${OPENSSL_VERSION}.zip
mv openssl-${OPENSSL_VERSION} openssl-x86_64

cd openssl-x86_64

if [ "${OS}" == "Darwin" ]; then
  ./Configure darwin64-x86_64-cc enable-static-engine enable-ec_nistp_64_gcc_128 enable-gost enable-idea enable-md2 enable-rc2 enable-rc5 enable-rfc3779 enable-ssl-trace enable-ssl2 enable-ssl3 enable-zlib experimental-jpake --prefix=${OUTDIR} --openssldir=${OUTDIR}/ssl
else
  cd ${BUILDDIR}/downloads
  curl -OL http://www.zlib.net/${ZLIB_VERSION}.tar.gz

  cd ${BUILDDIR}/build
  tar -zxvf ${BUILDDIR}/downloads/${ZLIB_VERSION}.tar.gz
  mv ${ZLIB_VERSION} zlib-x86_64
  cd zlib-x86_64

  ./configure  --prefix=${OUTDIR} --static -64
  make
  make install

  echo ">>> ZLIB complete"
  cd ${BUILDDIR}/build/openssl-x86_64
  ./config enable-static-engine enable-ec_nistp_64_gcc_128 enable-gost enable-idea enable-md2 enable-rc2 enable-rc5 enable-rfc3779 enable-ssl-trace enable-ssl2 enable-ssl3 enable-zlib experimental-jpake --prefix=${OUTDIR} --openssldir=${OUTDIR}/ssl -I${OUTDIR}/include -L${OUTDIR}/lib --with-zlib-lib=${OUTDIR}/lib --with-zlib-include=${OUTDIR}/include
fi

make
make install prefix=${OUTDIR}

FILE="${BUILDDIR}/downloads/${LIBEVENT_VERSION}.tar.gz"
if [ ! -f $FILE ]; then
  echo "Downloading $FILE.."
  cd ${BUILDDIR}/downloads
  curl -OL https://github.com/libevent/libevent/archive/${LIBEVENT_VERSION}.tar.gz
fi

cd ${BUILDDIR}/build
tar -zxvf ${BUILDDIR}/downloads/${LIBEVENT_VERSION}.tar.gz
mv libevent-${LIBEVENT_VERSION} libevent-x86_64

cd libevent-x86_64
./autogen.sh

if [ "${OS}" == "Darwin" ]; then
  ./configure --enable-shared=no --enable-static CFLAGS="-I${OUTDIR}/include -arch x86_64" LIBS="-L${OUTDIR}/lib -lssl -lcrypto -ldl -lz"
else
  ./configure --enable-shared=no OPENSSL_CFLAGS=-I${OUTDIR}/include OPENSSL_LIBS="-L${OUTDIR}/lib -lssl -L${OUTDIR}/lib -lcrypto"  CFLAGS="-I${OUTDIR}/include" LIBS="-L${OUTDIR}/lib -ldl -lz"


fi

make
make install prefix=${OUTDIR}
echo '>>> Complete'
