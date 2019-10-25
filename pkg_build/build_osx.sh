#!/bin/sh
#set -e -o pipefail
wdir=`pwd`

OUTDIR=`pwd`
MAKEOPTS=" -j8 "
WRAP_DIR=`pwd`/osx_wrapped
HOSTS="x86_64-apple-darwin11"
CONFIGFLAGS="--enable-reduce-exports --disable-bench --disable-gui-tests LDFLAGS=-static-libstdc++ --disable-tests --enable-wallet GENISOIMAGE=$WRAP_DIR/genisoimage"
FAKETIME_HOST_PROGS=""
FAKETIME_PROGS="ar ranlib date dmg genisoimage"

export QT_RCC_TEST=0
export QT_RCC_SOURCE_DATE_OVERRIDE=1
export GZIP="-9n"
export TAR_OPTIONS="--mtime="$REFERENCE_DATE\\\ $REFERENCE_TIME""
export TZ="UTC"
export BUILD_DIR=`pwd`
mkdir -p ${WRAP_DIR}
if test -n "$GBUILD_CACHE_ENABLED"; then
  export SOURCES_PATH=${GBUILD_COMMON_CACHE}
  export BASE_CACHE=${GBUILD_PACKAGE_CACHE}
  mkdir -p ${BASE_CACHE} ${SOURCES_PATH}
fi

export ZERO_AR_DATE=1

# Create global faketime wrappers
for prog in ${FAKETIME_PROGS}; do
  echo '#!/bin/bash' > ${WRAP_DIR}/${prog}
  echo "REAL=\`which -a ${prog} | grep -v ${WRAP_DIR}/${prog} | head -1\`" >> ${WRAP_DIR}/${prog}
  echo 'export LD_PRELOAD=/usr/lib/x86_64-linux-gnu/faketime/libfaketime.so.1' >> ${WRAP_DIR}/${prog}
  echo "export FAKETIME=\"${REFERENCE_DATETIME}\"" >> ${WRAP_DIR}/${prog}
  echo "\$REAL \$@" >> $WRAP_DIR/${prog}
  chmod +x ${WRAP_DIR}/${prog}
done

# Create per-host faketime wrappers
for i in $HOSTS; do
  for prog in ${FAKETIME_HOST_PROGS}; do
      echo '#!/bin/bash' > ${WRAP_DIR}/${i}-${prog}
      echo "REAL=\`which -a ${i}-${prog} | grep -v ${WRAP_DIR}/${i}-${prog} | head -1\`" >> ${WRAP_DIR}/${i}-${prog}
      echo 'export LD_PRELOAD=/usr/lib/x86_64-linux-gnu/faketime/libfaketime.so.1' >> ${WRAP_DIR}/${i}-${prog}
      echo "export FAKETIME=\"${REFERENCE_DATETIME}\"" >> ${WRAP_DIR}/${i}-${prog}
      echo "\$REAL \$@" >> $WRAP_DIR/${i}-${prog}
      chmod +x ${WRAP_DIR}/${i}-${prog}
  done
done
export PATH=${WRAP_DIR}:${PATH}

if [ ! -d $HOSTS ]; then
  tar -xf $HOSTS.tbz
  cd $HOSTS
  find . -name '*.la' -exec sed -i "s#/root/diskcoin/osx_depends#${BUILD_DIR}#g" {} \;
  find . -name '*.pc' -exec sed -i "s#/root/diskcoin/osx_depends#${BUILD_DIR}#g" {} \;
  find . -name '*.h' -exec sed -i "s#/root/diskcoin/osx_depends#${BUILD_DIR}#g" {} \;
  find . -name '*.site' -exec sed -i "s#/root/diskcoin/osx_depends#${BUILD_DIR}#g" {} \;
  cd ..
fi

cd $wdir/../
BASEPREFIX=$wdir

if [ ! -d ${BASEPREFIX}/SDKs ]; then
  mkdir -p ${BASEPREFIX}/SDKs
  tar -C ${BASEPREFIX}/SDKs -xf ${BUILD_DIR}/MacOSX10.11.sdk.tar.gz
fi

# Build dependencies for each host
# for i in $HOSTS; do
#   make ${MAKEOPTS} -C ${BASEPREFIX} HOST="${i}"
# done

# Create the release tarball using (arbitrarily) the first host
./autogen.sh
./configure $CONFIGFLAGS --prefix=${BASEPREFIX}/`echo "${HOSTS}" | awk '{print $1;}'`
make dist
# mv bitcoinUnlimited-*.tar.gz Diskcoin-1.1.0.tar.gz
SOURCEDIST=`echo Diskcoin-*.tar.gz`
DISTNAME=`echo ${SOURCEDIST} | sed 's/.tar.*//'`

# Correct tar file order
# mkdir -p temp
# cd temp
# tar xf ../$SOURCEDIST
# find Diskcoin* | sort | tar --no-recursion --mode='u+rw,go+r-w,a+X' --owner=0 --group=0 -c -T - | gzip -9n > ../$SOURCEDIST
# cd ..
mv $SOURCEDIST $wdir/

ORIGPATH="$PATH"
# Extract the release tarball into a dir for each host and build
for i in ${HOSTS}; do
  export PATH=${BASEPREFIX}/${i}/native/bin:${ORIGPATH}
  mkdir -p $BASEPREFIX/distsrc-${i}
  rm -fr $BASEPREFIX/distsrc-${i}/*
  cd $BASEPREFIX/distsrc-${i}
  INSTALLPATH=`pwd`/installed/${DISTNAME}
  mkdir -p ${INSTALLPATH}
  tar --strip-components=1 -xf $wdir/$SOURCEDIST

  ./configure --prefix=${BASEPREFIX}/${i} --bindir=${INSTALLPATH}/bin --includedir=${INSTALLPATH}/include --libdir=${INSTALLPATH}/lib --disable-ccache --disable-maintainer-mode --disable-dependency-tracking ${CONFIGFLAGS}
  make ${MAKEOPTS}
  make install-strip

  make osx_volname
  make deploydir
  OSX_VOLNAME="$(cat osx_volname)"
  # mkdir -p unsigned-app-${i}
  # cp osx_volname unsigned-app-${i}/
  # cp contrib/macdeploy/detached-sig-apply.sh unsigned-app-${i}
  # cp contrib/macdeploy/detached-sig-create.sh unsigned-app-${i}
  # cp ${BASEPREFIX}/${i}/native/bin/dmg ${BASEPREFIX}/${i}/native/bin/genisoimage unsigned-app-${i}
  # cp ${BASEPREFIX}/${i}/native/bin/${i}-codesign_allocate unsigned-app-${i}/codesign_allocate
  # cp ${BASEPREFIX}/${i}/native/bin/${i}-pagestuff unsigned-app-${i}/pagestuff
  # mv dist unsigned-app-${i}
  # cd unsigned-app-${i}
  # find . | sort | tar --no-recursion --mode='u+rw,go+r-w,a+X' --owner=0 --group=0 -c -T - | gzip -9n > ${OUTDIR}/${DISTNAME}-osx-unsigned.tar.gz
  # cd ..

  make deploy
  ${WRAP_DIR}/dmg dmg "${OSX_VOLNAME}.dmg" ${OUTDIR}/diskcoin-osx.dmg

  #cd installed
  #find . -name "lib*.la" -delete
  #find . -name "lib*.a" -delete
  #rm -rf ${DISTNAME}/lib/pkgconfig
  #find ${DISTNAME} | sort | tar --no-recursion --mode='u+rw,go+r-w,a+X' --owner=0 --group=0 -c -T - | gzip -9n > ${OUTDIR}/${DISTNAME}-${i}.tar.gz
  #cd ../../
done
rm -f $wdir/$SOURCEDIST
#mkdir -p $OUTDIR/src
#mv $SOURCEDIST $OUTDIR/src
#mv ${OUTDIR}/${DISTNAME}-x86_64-*.tar.gz ${OUTDIR}/${DISTNAME}-osx64.tar.gz
