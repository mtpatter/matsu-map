#!/bin/bash
# gsload - Given a list of GeoTIFFs as arguments, upload them to your GeoServer
#
# All filenames must match this example's format:
#           YYYYDDD      INSTRUM ANALYTIC.......
# EO1A0640452014065110KC_ALI_L1G_CLASSIFIEDCOLOR.tif,
#
# Usage:
# $ gsload [GEOTIFF]...
# For example,
# $ gsload mygeotiffs/*.tif

# Be sure to hide the password somehow if you change it from the default!
username="admin"
password='geoserver'

gsdata="/var/lib/tomcat7/webapps/geoserver/data/data"
workspace="eo1"

if [ ! -d $gsdata ]; then
    echo "Error: GeoServer data directory '$gsdata' not found."
    exit 1
fi

sudo -u tomcat7 mkdir -p $gsdata/$workspace/

for file in "$@"; do
    if [[ ! -f "$file" ]]; then
        continue
    fi

    name=`basename "$file"`

    # Given EO1A0640452014065110KC_ALI_L1G_CLASSIFIEDCOLOR.tif,
    # set layer=EO1A0640452014065110KC_ALI_L1G_CLASSIFIEDCOLOR,
    # instr=ali_l1g, and analytic=classifiedcolor
    shopt -s nocasematch
    if [[ ! $name =~ ^([^_]+_([^_]+_[^_]+)_([^_]+))\.tiff?$ ]]; then
        echo "Ignoring $name; didn't match *_*_*_*.tif"
        continue
    fi
    shopt -u nocasematch
    layer=${BASH_REMATCH[1]}  # Just drops the file extension.
    instr=${BASH_REMATCH[2],,}  # E.g., ali_l1g. (The ,, lowercases it.)
    analytic=${BASH_REMATCH[3],,}  # E.g., classifiedcolor.

    yyyy=${name:10:4}
    ddd=${name:14:3}
    # Trick from http://superuser.com/a/232106
    month=`date -d "$yyyy-01-01 +$ddd days -1 day" "+%Y-%m"`

    location="$gsdata/$workspace/$instr/$analytic/$month/$layer/"

    # Move files (if they aren't already in place).
    sudo -u tomcat7 mkdir -p "$location"
    sudo -u tomcat7 rsync "$file" "$location"

    # Upload files.
    curl -u $username:$password -XPOST -H 'Content-Type: application/xml' -d "<coverageStore><name>$layer</name><workspace>$workspace</workspace><enabled>true</enabled></coverageStore>" http://localhost:8080/geoserver/rest/workspaces/$workspace/coveragestores
    curl -u $username:$password -v -XPUT -H 'Content-type: text/plain' -d "file:$location" http://localhost:8080/geoserver/rest/workspaces/$workspace/coveragestores/$layer/external.imagemosaic
done
