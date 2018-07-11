#!/bin/sh

set -e

CONF_FILE=/usr/local/etc/binfmt.conf
BASEDIR=/proc/sys/fs/binfmt_misc
KERNEL=$(cat /proc/sys/kernel/osrelease)
REQUIREDMAJOR=4
REQUIREDMINOR=8

if [ ! -d $BASEDIR ]; then
    echo "No binfmt support in the kernel."
    echo "  Try: '/sbin/modprobe binfmt_misc' from the host"
    exit 1
fi


if [ ! -f ${BASEDIR}/register ]; then
    mount binfmt_misc -t binfmt_misc $BASEDIR
fi

# figure out if we have a high enough kernel number to support F flag or not
kernelmajor=${KERNEL%%.*}
remainder=${KERNEL#${kernelmajor}.}
kernelminor=${remainder%%.*}

validkernel=

if [ $kernelmajor -gt $REQUIREDMAJOR ]; then
    validkernel=true
elif [ $kernelmajor -lt $REQUIREDMAJOR ]; then
    validkernel=
elif [ $kernelminor -ge $REQUIREDMINOR ]; then
    validkernel=true
else
    validkernel=
fi

fixflag=

# which mode do we run in?
case "$MODE" in
    registration)
        if [ -n "$validkernel" ]; then
            echo "Kernel version $KERNEL does not support registration mode. Exiting."
            exit 1
        fi
        fixflag=F
    ;;
    execution)
        fixflag=
    ;;
    "")
        if [ -n "$validkernel" ]; then
            fixflag=F
        fi
    ;;
    *)
        echo "Unknown mode $MODE" >&2
        exit 1
    ;;
esac

for i in $(cat ${CONF_FILE}); do
    # what is the name of the file?
    filename=$(echo $i | awk -F: '{print $2}')
    if [ -f ${BASEDIR}/${filename} ]; then
        if [ -z "$REPLACE" ]; then
            echo "${filename} already registered; ignoring"
        else
            echo "${filename} already registered; replacing"
            echo -1 > ${BASEDIR}/${filename}
            # if relevant, add fix flag "F"
            echo ${i}${fixflag} > ${BASEDIR}/register
        fi
    else
        echo "${filename} does not exist, registering"
        # if relevant, add fix flag "F"
        echo ${i}${fixflag} > ${BASEDIR}/register
    fi 
done

