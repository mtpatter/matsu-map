#!/bin/bash
# gsload.sh - Given GeoTIFFs as arguments, upload them to your GeoServer
#
# All filenames must match this example's format:
#
# EO1A0640452014065110KC_ALI_L1G_CLASSIFIEDCOLOR.tif
# ??????????YYYYDDD?????_INSTRUM_THEANALYTICNAME.tif
#
# Usage:
# $ gsload [GEOTIFF]...
# For example,
# $ gsload mygeotiffs/*.tif

username="admin"
# Be sure to hide the password somehow if you change it from the default!
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
    if [[ ! $name =~ ^(([^_]+)_([^_]+_[^_]+)_([^_]+))\.tiff?$ ]]; then
        echo "Ignoring $name; didn't match *_*_*_*.tif"
        continue
    fi
    shopt -u nocasematch
    layer=${BASH_REMATCH[1]}  # Just drops the file extension.
    id=${BASH_REMATCH[2]}  # E.g., EO1A0640452014065110KC.
    instr=$(echo ${BASH_REMATCH[3],,} | sed "s/hyp/hyperion/")  # E.g., ali_l1g.
    analytic=${BASH_REMATCH[4],,}  # E.g., classifiedcolor.

    yyyy=${name:10:4}
    ddd=${name:14:3}
    # Trick from http://superuser.com/a/232106
    month=`date -d "$yyyy-01-01 +$ddd days -1 day" "+%Y-%m"`

    location="$gsdata/$workspace/$instr/$analytic/$month/$layer/"

    # Move files (if they aren't already in place).
    sudo -u tomcat7 mkdir -p "$location"
    sudo -u tomcat7 rsync "$file" "$location"

    meta=$(echo /glusterfs/osdc_public_data/eo1/$instr/$yyyy/$ddd/meta/daily_* \
             | sed "s/_l1g/_l0/")
    description=$(grep ${id:0:3}${id:4} $meta)
    # Upload files.
    curl -sf -u $username:$password -XPOST -H 'Content-Type: application/xml' -d "<coverageStore><name>$layer</name><workspace>$workspace</workspace><enabled>true</enabled><description>$description</description></coverageStore>" http://localhost:8080/geoserver/rest/workspaces/$workspace/coveragestores > /dev/null
    curlerr1=$?

    curl -sSf -u $username:$password -XPUT -H 'Content-type: text/plain' -d "file:$location" http://localhost:8080/geoserver/rest/workspaces/$workspace/coveragestores/$layer/external.imagemosaic > /dev/null
    curlerr2=$?

    curl -sSf -u $username:$password -XPUT -H 'Content-type: application/xml' -d "<coverage><title>$description</title><enabled>true</enabled></coverage>" http://localhost:8080/geoserver/rest/workspaces/$workspace/coveragestores/$layer/coverages/$layer.xml

    if [[ $curlerr1 -eq 0 && $curlerr2 -eq 0 ]]; then
        echo "$workspace,$layer,$(date --iso-8601=seconds --utc)" \
          | sudo -su tomcat7 tee -a $gsdata/$workspace/loaded.csv > /dev/null
    fi
done
