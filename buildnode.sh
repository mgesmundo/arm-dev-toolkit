#!/bin/bash

# This script build a working release of Node JS for Aria G25 device
# and prepare a tarball for deploying in the real device
# Works from Node 0.10.0 version
# Reference:
# https://github.com/itwars/Nodejs-ARM-builder/blob/master/cross-compiler.sh
# https://github.com/creationix/nvm/blob/master/nvm.sh 

help() {
  echo
  echo "Build Node for Aria G25"
  echo
  echo "Usage: buildnode <version> 	Build Node JS <version> from source code"
}

download() {
  echo "-> Download source code..."

  if [ "`curl -Is "http://nodejs.org/dist/$VERSION/node-$VERSION.tar.gz" | \grep '200 OK'`" != '' ]; then
    tarball="http://nodejs.org/dist/$VERSION/node-$VERSION.tar.gz"
  elif [ "`curl -Is "http://nodejs.org/dist/node-$VERSION.tar.gz" | \grep '200 OK'`" != '' ]; then
    tarball="http://nodejs.org/dist/node-$VERSION.tar.gz"
  fi
  if (
    [ ! -z $tarball ] && \
      curl -L --progress-bar $tarball -o "$tmptarball" && \
      tar -xzf "$tmptarball" -C "$srcdir"
    )
  then
    echo "-> Download $VERSION complete"
  else
    echo "-> Download $VERSION failed!"
    return 1
  fi
}

build() {
  export TOOL_PREFIX="arm-linux-gnueabi"
  export CC="${TOOL_PREFIX}-gcc"
  export CXX="${TOOL_PREFIX}-g++"
  export AR="${TOOL_PREFIX}-ar"
  export RANLIB="${TOOL_PREFIX}-ranlib"
  export LINK="${CXX}"
  export CCFLAGS="-march=armv5te -mfpu=softfp -marm"
  export CXXFLAGS="-march=armv5te -mno-unaligned-access"
  export OPENSSL_armcap=5
  export GYPFLAGS="-Darmeabi=soft -Dv8_can_use_vfp_instructions=false -Dv8_can_use_unaligned_accesses=false -Darmv7=0"
  export VFP3=off
  export VFP2=off

  echo "-> Compile source code..."

  if (
    cd "$srcdir/node-$VERSION" && \
    ./configure --without-snapshot --dest-cpu=arm --dest-os=linux --prefix="$tmpdir/$VERSION" && \
    make -j 4 && \	# set j according your cpu cores
    rm -f "$tmpdir/$VERSION" 2>/dev/null && \
    make install
    )
  then
    echo "-> Compile $VERSION complete"
  else
    echo "-> Compile $VERSION failed!"
    return 1
  fi

  echo "-> Build tarball..."

  local osarch="linux-armv5"
  local tarball="$tmpdir/node-${VERSION}-${osarch}.tar.gz"

  if (
    cd "$tmpdir" && \
    cp "$srcdir/node-$VERSION/LICENSE" "$VERSION" && \
    cp "$srcdir/node-$VERSION/README.md" "$VERSION" && \
    cp "$srcdir/node-$VERSION/ChangeLog" "$VERSION" && \
    tar -czf "$tarball" "$VERSION"
    )
  then
    echo "-> Build node $VERSION tarball complete"
  else
    echo "-> Build node $VERSION tarball failed!"
    return 1
  fi
}

# main

if [ $# -lt 1 ]; then
  help
  exit 1
fi

# required version
VERSION=$1

# set the absolute path of nvm in your board
# otherwise npm will not work
tmpdir="/root/.nvm"
srcdir="$tmpdir/src"
tmptarball="$srcdir/node-$VERSION.tar.gz"

# create tmp directory
mkdir -p "$srcdir"

download && build
