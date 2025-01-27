#!/bin/bash
# gsload.sh - Given GeoTIFFs as arguments, upload them to your GeoServer
#
# All filenames must match this example's format:
#
# EO1A0640452014065110KC_ALI_L1G_CLASSIFIED.tif
# ??????????YYYYDDD?????_INSTRUM_-ANALYTIC-.tif
#
# Usage:
# $ gsload [GEOTIFF]...
# For example,
# $ gsload mygeotiffs/*.tif

gsdata="/var/lib/tomcat7/webapps/geoserver/data/data"

# Import credentials from config.sh
if [[ ! -f ${BASH_SOURCE%/*}/config.sh ]]; then
    echo "ERROR: Could not find config.sh! Try 'cp config.sh.sample config.sh'"
    exit 1
fi
source ${BASH_SOURCE%/*}/config.sh

if [ ! -d $gsdata ]; then
    echo "Error: GeoServer data directory '$gsdata' not found."
    exit 1
fi

# If workspace doesn't exist, create it.
sudo -u tomcat7 mkdir -p $gsdata/$workspace/
curl -sf -u $username:$password -XPOST -H "Content-type: text/xml" -d "<workspace><name>$workspace</name></workspace>" http://localhost:8080/geoserver/rest/workspaces > /dev/null

for file in "$@"; do
    if [[ ! -f "$file" ]]; then
        continue
    fi
    name=$(basename "$file")

    # Given EO1A0640452014065110KC_ALI_L1G_CLASSIFIED.tif,
    # set layer=EO1A0640452014065110KC_ALI_L1G_CLASSIFIED,
    # instr=ali_l1g, and analytic=classified
    shopt -s nocasematch
    if [[ ! $name =~ ^(([^_]+)_([^_]+_[^_]+)_([^_]+))\.tiff?$ ]]; then
        echo "Ignoring $name; didn't match *_*_*_*.tif"
        continue
    fi
    shopt -u nocasematch
    layer=${BASH_REMATCH[1]}  # Just drops the file extension.
    id=${BASH_REMATCH[2]}  # E.g., EO1A0640452014065110KC.
    instr=$(echo ${BASH_REMATCH[3],,} | sed "s/hyp/hyperion/")  # E.g., ali_l1g.
    analytic=${BASH_REMATCH[4],,}  # E.g., classified.

    yyyy=${name:10:4}
    ddd=${name:14:3}
    # Trick from http://superuser.com/a/232106
    month=$(date -d "${yyyy}-01-01 +${ddd} days -1 day" "+%Y-%m")

    location="${gsdata}/${workspace}/${instr}/${instr}_${analytic}/${month}/${layer}"

    # Move the image and reproject it.
    sudo -u tomcat7 mkdir -p "${location}"
    sudo -u tomcat7 rsync "${file}" "${location}/${layer}.origproj" 
    sudo -u tomcat7 rm -f "${location}/${layer}.tif"
    sudo -u tomcat7 gdalwarp -t_srs EPSG:4326 "${location}/${layer}.origproj" "${location}/${layer}.tif"
    sudo -u tomcat7 rm "${location}/${layer}.origproj"

    # This was a failed attempt at only copying and reprojecting if changed.
    #if [[ $(sudo -u tomcat7 rsync -ci "$file" "$location/$layer.badprojection" | wc -l) -ne 0 ]]; then
        # My version of gdalwarp lacks -overwrite, so rm instead...
        #sudo -u tomcat7 rm "$location/$layer.tif"
        #sudo -u tomcat7 gdalwarp -t_srs EPSG:4326 "$location/$layer.badprojection" "$location/$layer.tif"
    #fi

    meta=$(echo /glusterfs/osdc_public_data/eo1/$instr/$yyyy/$ddd/meta/daily_* \
             | sed "s/_l1g/_l0/")
    description=$(grep ${id:0:3}${id:4} $meta)

    # Upload files.
    curl -sSf -u $username:$password -XPUT -H 'Content-type: text/plain' -d "file://$location" http://localhost:8080/geoserver/rest/workspaces/$workspace/coveragestores/$layer/external.imagemosaic > /dev/null

    # If all went well, post to the Atom feed
    if [[ $? -eq 0 ]]; then
        curl -sSf -u $feeduser:$feedpass -XPOST -H 'Content-Type: application/atom+xml' -d "$(python ${BASH_SOURCE%/*}/feedEntry.py "$file" "$description")" http://localhost:8080/atomhopper/geoserver/feed.xml > /dev/null
    fi

    # Set description of image (came from meta/daily_yyyy_ddd)
    curl -sSf -u $username:$password -XPUT -H 'Content-type: application/xml' -d "<coverage><title>$description</title><enabled>true</enabled></coverage>" http://localhost:8080/geoserver/rest/workspaces/$workspace/coveragestores/$layer/coverages/$layer.xml > /dev/null

    # Set style of image. (If it doesn't exist, it will remain the default.)
    curl -sSf -u $username:$password -XPUT -H 'Content-type: text/xml' -d "<layer><defaultStyle><name>$analytic</name></defaultStyle></layer>" http://localhost:8080/geoserver/rest/layers/$workspace:$layer > /dev/null
done

# Rebuild ImageMosaic of all images from this instrument and analytic.
# NOTE: If you include multiple analytics in a single gsload, only one updates.
sudo -u tomcat7 rm -f ${gsdata}/${workspace}/${instr}/${instr}_${analytic}/${instr}_${analytic}.shp

curl -sSf -u $username:$password -XPUT -H 'Content-type: text/plain' -d "file://$gsdata/$workspace/${instr}/${instr}_$analytic" http://localhost:8080/geoserver/rest/workspaces/$workspace/coveragestores/${instr}_${analytic}_raster/external.imagemosaic?coverageName=${instr}_${analytic}_raster > /dev/null

curl -sSf -u $username:$password -XPUT -H 'Content-type: text/xml' -d "<layer><defaultStyle><name>$analytic</name></defaultStyle></layer>" http://localhost:8080/geoserver/rest/layers/$workspace:${instr}_${analytic}_raster > /dev/null

# Build vector data from ImageMosaic shapefile
curl -sSf -u "${username}:${password}" -XPUT -H "Content-type: text/plain" -d "file://${gsdata}/${workspace}/${instr}/${instr}_${analytic}/${instr}_${analytic}.shp" "http://localhost:8080/geoserver/rest/workspaces/${workspace}/datastores/${instr}_${analytic}/external.shp" #> /dev/null

# We have to recalculate the bbox because of this:  https://github.com/geoserver/geoserver/blob/2.5.x/src/restconfig/src/main/java/org/geoserver/catalog/rest/DataStoreFileResource.java#L411
curl -sSf -u "${username}:${password}" -XPUT -H "Content-type: application/xml" -d "<featureType><name>${instr}_${analytic}</name><enabled>true</enabled></featureType>" "http://localhost:8080/geoserver/rest/workspaces/${workspace}/datastores/${instr}_${analytic}/featuretypes/${instr}_${analytic}.xml?recalculate=nativebbox,latlonbbox" > /dev/null

# Mysteriously, the bbox fails to update even after that. It does not change
# unless I enter the GUI and save the layer with no changes (!). I have no idea
# why it's necessary, but this REST call fixes it.
curl -sSf -u $username:$password -XPUT -H 'Content-type: text/xml' -d "<layer></layer>" http://localhost:8080/geoserver/rest/layers/$workspace:${instr}_${analytic} > /dev/null

#curl -v -u $username:$password -XPOST -H "Content-type: application/xml" -d @featuretype.xml "http://localhost:8080/geoserver/rest/workspaces/$workspace/datastores/${instr}_${analytic}_vector/featuretypes.shp&recalculate=nativebbox,latlonbbox" #> /dev/null
#<title>Vector data</title><enabled>true</enabled>
#curl -v -u $username:$password -XPOST -H "Content-type: application/xml" -d "<featureType><name>${instr}_${analytic}_vector</name><attributes><attribute><name>the_geom</name><binding>com.vividsolutions.jts.geom.Point</binding></attribute><attribute><name>description</name><binding>java.lang.String</binding></attribute><attribute><name>timestamp</name><binding>java.util.Date</binding></attribute></attributes></featureType>" http://localhost:8080/geoserver/rest/workspaces/$workspace/datastores/${instr}_${analytic}_vector/featuretypes.shp #> /dev/null
#curl -v -u $username:$password -XPUT -H 'Content-type: application/xml' -d "<featureType><title>Vector data</title><enabled>true</enabled></featureType>" http://localhost:8080/geoserver/rest/workspaces/$workspace/datastores/${instr}_${analytic}_vector/featuretypes/${instr}_${analytic}_vector.xml #> /dev/null
#curl -v -u $username:$password -XPOST -H "Content-type: application/xml" -d "<featureType datastore=\"${instr}_${analytic}_vector\"><name>${instr}_${analytic}_vector</name><nativeName>${instr}_${analytic}_vector</nativeName><namespace><name>eo1</name></namespace><store class=\"dataStore\"><name>${instr}_${analytic}_vector</name></store><abstract>Vector data</abstract><title>Vector data</title><enabled>true</enabled></featureType>" http://localhost:8080/geoserver/rest/workspaces/$workspace/datastores/${instr}_${analytic}_vector/featuretypes.shp #> /dev/null
#curl -v -u $username:$password -XPUT -H "Content-type: text/plain" -d "file://$gsdata/$workspace/$instr/$analytic/$analytic.shp" http://localhost:8080/geoserver/rest/workspaces/$workspace/datastores/${instr}_${analytic}_vector/featuretypes/${instr}_${analytic}_vector/external.shp #> /dev/null
