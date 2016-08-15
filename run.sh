#!/bin/bash
#DEVELOPER's startup script - only used for container development
#Created by chaplocal on Mon Aug 17 23:41:27 UTC 2015

IMAGE="misasin/docker-keybox"
INTERACTIVE_SHELL="/bin/bash"

# Uncomment to include port settings
#PORTOPT="-p x:y"

EXT_HOSTNAME=localhost

usage() {
  echo "Usage: run.sh [-d] [-p port#] [-h] [extra-chaperone-options]"
  echo "       Run $IMAGE as a daemon or interactively (the default)."
  echo "       First available port will be remapped to $EXT_HOSTNAME if possible."
  exit
}

if [ "$CHAP_SERVICE_NAME" != "" ]; then
  echo run.sh should be executed on your docker host, not inside a container.
  exit
fi

cd ${0%/*} # go to directory of this file
APPS=$PWD
cd ..

options="-t -i -e TERM=$TERM --rm=true"
shellopt="/bin/bash --rcfile $APPS/bash.bashrc"

while getopts ":-dp:" o; do
  case "$o" in
    d)
      options="-d"
      shellopt=""
      ;;
    p)
      PORTOPT="-p $OPTARG"
      ;;      
    -) # first long option terminates
      break
      ;;
    *)
      usage
      ;;
  esac
done
shift $((OPTIND-1))

# remap ports according to the image, and tell the container about the lowest numbered
# port used.

if [ "$PORTOPT" == "" ]; then
  exposed=`docker inspect $IMAGE | sed -ne 's/^ *"\([0-9]*\)\/tcp".*$/\1/p' | sort -u`
  ncprog=`which nc`
  if [ "$exposed" != "" -a "$ncprog" != "" ]; then
    PORTOPT=""
    for PORT in $exposed; do
      if ! $ncprog -z $EXT_HOSTNAME $PORT; then
	 [ "$PORTOPT" == "" ] && PORTOPT="--env CONFIG_EXT_PORT=$PORT"
         PORTOPT="$PORTOPT -p $PORT:$PORT"
	 echo "Port $PORT available at $EXT_HOSTNAME:$PORT ..."
      fi
    done
  else
    if [ "$exposed" != "" ]; then
      echo "Note: '/bin/nc' not installed, so cannot detect port usage on this system."
      echo "      Use '$0 -p x:y' to expose ports."
    fi
  fi
fi

# Run the image with this directory as our local apps dir.
# Create a user with a uid/gid based upon the file permissions of the chaperone.d
# directory.

MOUNT=${PWD#/}; MOUNT=/${MOUNT%%/*} # extract user mountpoint
docker run $options -v $MOUNT:$MOUNT $PORTOPT -e CONFIG_EXT_HOSTNAME=$EXT_HOSTNAME -e CONFIG_LOGGING=file \
   -e EMACS=$EMACS \
   $IMAGE \
   --create $USER:$APPS/chaperone.d --config $APPS/chaperone.d $* $shellopt
