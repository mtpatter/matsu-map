"""
Demonstration of creating an Atom feed for layer data from an image.

Given a GeoTIFF or a PNG with geo-referencing metadata (it should have a
.png.aux.xml file), output an Atom feed containing the important image
metadata. The script should also work with other geo-referenced image
types. A bunch of hard coded values are used for demonstration purposes.

Usage:
$ python atomfeed.py [image name]
"""

import xml.etree.cElementTree as ET
import xml.dom.minidom
from osgeo import gdal, osr
import sys

__author__ = "Nikolas Anderson"
__version__ = "0.2"

def prettify(xmlString):
    """Return XML string with proper whitespace."""
    return xml.dom.minidom.parseString(xmlString).toprettyxml()

def makeFeed():
    """Print an Atom feed entry based on an example file."""

    if len(sys.argv) != 2:
        print "USAGE: python atomfeed.py [image name]"
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
    bbox = ','.join([str(f) for f in coords])

    data = {
        "workspace": "nyc_roads",
        "layer": "nyc_roads",
        "srs": epsg,
        "bbox": bbox,
        "time": "1403729313",
        "width": "500",
        "height": "500",
        "format": "application/openlayers"
    }

    feed = ET.Element("feed")
    feed.set("xmlns", "http://www.w3.org/2005/Atom")
    feed.set("xmlns:georss", "http://www.georss.org/georss")

    # http://www.atomenabled.org/developers/syndication/#requiredFeedElements
    tag = ET.SubElement(feed, "id")
    tag.text = "http://matsu-tiling.opensciencedatacloud.org:8080/geoserver/"
    tag = ET.SubElement(feed, "title")
    tag.text = "Layer Feed"
    tag = ET.SubElement(feed, "updated")
    tag.text = data["time"]

    entry = ET.SubElement(feed, "entry")

    # http://www.atomenabled.org/developers/syndication/#requiredEntryElements
    tag = ET.SubElement(entry, "id")
    tag.text = "http://matsu-tiling.opensciencedatacloud.org:8080/geoserver/" + data["layer"]
    tag = ET.SubElement(entry, "title")
    tag.text = data["layer"]
    tag = ET.SubElement(entry, "updated")
    tag.text = data["time"]

    # Create entry tags
    for parameter in ["workspace", "layer", "srs", "bbox",
                      "time", "width", "height", "format"]:
        child = ET.SubElement(entry, parameter)
        child.text = data[parameter]

    print prettify(ET.tostring(feed))

if __name__ == '__main__':
    main()
