"""
Create a GeoTIFF Atom feed entry with everything needed for GetMap.

Given a GeoTIFF, or a PNG with geo-referencing metadata (it should have
a .png.aux.xml file), output an Atom feed entry containing the important
image metadata needed to form a GetMap request. The script should also
work with other geo-referenced image types.

Usage:
$ python feedEntry.py [image]
Example:
$ python feedEntry.py /var/lib/tomcat7/webapps/geoserver/data/data/eo1/ali_l1g/rgb/2014-05/EO1A0240362014122110KF_ALI_L1G_RGB/EO1A0240362014122110KF_ALI_L1G_RGB.tif
"""

import xml.etree.cElementTree as ET
import xml.dom.minidom
from osgeo import gdal, osr
import sys
import os

__author__ = "Nikolas Anderson"
__version__ = "0.2"

workspace = "eo1"

def prettify(xmlString):
    """Return XML string with proper whitespace."""
    return xml.dom.minidom.parseString(xmlString).toprettyxml()

def makeEntry():
    """Print an Atom feed entry based on the supplied georeferenced file."""

    if len(sys.argv) != 2:
        print "USAGE: python %s [image]" % sys.argv[0]
        exit(2)

    image = gdal.Open(sys.argv[1])

    # Identify the srs EPSG number
    srs = osr.SpatialReference()
    srs.ImportFromWkt(image.GetProjectionRef())
    srs.AutoIdentifyEPSG()
    epsg = "EPSG:" + srs.GetAuthorityCode(None)

    # Determine bbox (upper-left corner is easy; bottom-right requires math)
    width = image.RasterXSize
    height = image.RasterYSize
    gt = image.GetGeoTransform()
    coords = [gt[0], gt[3], gt[0] + width*gt[1] + height*gt[2],
                            gt[3] + width*gt[4] + height*gt[5]]
    bbox = ",".join([str(f) for f in coords])

    data = {
        "workspace": workspace,
        "layer": os.path.splitext(os.path.basename(sys.argv[1]))[0],
        "srs": epsg,
        "bbox": bbox,
        "width": str(image.RasterXSize),
        "height": str(image.RasterYSize),
        "format": "application/openlayers"
    }

    entry = ET.Element("entry")

    # http://www.atomenabled.org/developers/syndication/#requiredEntryElements
    # tag = ET.SubElement(entry, "id")
    # tag.text = "http://matsu-tiling.opensciencedatacloud.org:8080/geoserver/" + data["layer"]
    tag = ET.SubElement(entry, "title")
    tag.text = data["layer"]

    # Create entry tags
    for parameter in ["workspace", "layer", "srs", "bbox",
                      "width", "height", "format"]:
        child = ET.SubElement(entry, parameter)
        child.text = data[parameter]

    # print prettify(ET.tostring(entry))
    print ET.tostring(entry)

if __name__ == '__main__':
    makeEntry()
