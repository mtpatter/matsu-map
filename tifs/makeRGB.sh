#!/bin/bash
# makeRGB.sh - Make RGB images and place them in GeoServer data directory
#
# Run the RGB analytic on scenes from the past 2 months, then put them in
# the Geoserver data directory according to our organizational scheme.
# Meant for testing purposes; probably not useful for production.
#
# Usage:
# $ ./makeRGB.sh
# Make sure that you run it in a directory with createRGB.py and gsload.sh

analytic="rgb"  # Name of the analytic; used in output filename and path.

gsdata="/var/lib/tomcat7/webapps/geoserver/data/data"
workspace="eo1"

if [ ! -d $gsdata ]; then
    echo "Error: GeoServer data directory '$gsdata' not found."
    exit 1
fi

sudo -u tomcat7 mkdir -p $gsdata/$workspace/

trap "exit" INT
for scene in /glusterfs/osdc_public_data/eo1/*_l1g/2014/{121..128}/*
do
    name=`basename $scene`

    if [[ ! $name =~ ^([^_]+)_([^_]+_[^_]+)$ ]]; then
        echo "Ignoring '$name'; name didn't match *_*_*"
        continue
    fi
    id=${BASH_REMATCH[1]}  # E.g., EO1A0640452014065110KC, used by createRGB.py
    instr=${BASH_REMATCH[2],,}  # E.g., ali_l1g. (The ,, lowercases it.)

    yyyy=${name:10:4}
    ddd=${name:14:3}
    # Trick from http://superuser.com/a/232106
    month=`date -d "$yyyy-01-01 +$ddd days -1 day" "+%Y-%m"`

    layer=${name}_${analytic^^}  # The ^^ converts to uppercase.
    location="$gsdata/$workspace/$instr/$analytic/$month/$layer"
    sudo -su tomcat7 mkdir -p "$location"
    sudo -su tomcat7 python createRGB.py $id $location/$layer.tif 2
    if [[ $? -eq 0 ]]; then
        ./gsload.sh $location/$layer.tif
    fi
done
