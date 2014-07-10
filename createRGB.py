"""
This Python program will create a compressed RGB GeoTIFF from 3 spectral
bands of an Earth Observing-1 ALI or Hyperion scene.

History:
Jul 2014: Adapted from makeRGB.py

Usage:
For use on the Open Science Data Cloud public data commons.
$ python createRGB.py IMAGEID OUTFILE.tif [SCALEFACTOR]
For example, make an image of the Italian coast from Jan 29, 2014 with a
brightening scale factor=2:
$ python createRGB.py EO1A1930292014029110PZ italy.tif 2
"""

from osgeo import gdal
import numpy as np
import argparse

__author__ = "Jake Bruggemann, Maria Patterson, and Nikolas Anderson"
__version__ = "0.1"

def saveRGB(files, outfile, scaleFactor):
    """Take already-opened EO-1 TIFFs and merge them into a RGB image."""
    driver = gdal.GetDriverByName("GTiff")
    driver.Register()
    datatype = gdal.GDT_Byte
    dest = driver.Create(outfile, files[0].RasterXSize, files[0].RasterYSize,
                         3, datatype, ["PHOTOMETRIC=RGB", "COMPRESS=DEFLATE"])

    # Carry over all georeferencing.
    dest.SetGeoTransform(files[0].GetGeoTransform())
    dest.SetProjection(files[0].GetProjection())
    dest.SetMetadata(files[0].GetMetadata_List())

    for i, tif in enumerate(files):
        img = tif.ReadAsArray()
        # Linear stretch as suggested here: http://eo1.usgs.gov/products/preview
        minVal = float(np.min(img[np.nonzero(img)]))
        scaled = ( (img - np.percentile(img[np.nonzero(img)], 1)) /
                   (np.percentile(img[np.nonzero(img)], 97) - minVal) )
        scaled[scaled > 1] = 1
        band = dest.GetRasterBand(i + 1)
        band.WriteArray(scaled * 255. * scaleFactor)
    dest = None

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Make a RGB GeoTIFF from ALI '
                                                 'or Hyperion data.')
    parser.add_argument('imname', type=str,
                        help='Scene ID of ALI or Hyperion scene.')
    parser.add_argument('outfile', type=str,
                        help='Output GeoTIFF file name.')
    parser.add_argument('scale', nargs='?', const=1, type=float, default=1,
                        help='Scale factor to brighten image. (Default = 1)')
    options = parser.parse_args()
    imname = options.imname
    outfile = options.outfile
    scaleFactor = options.scale

    basedir = '/glusterfs/osdc_public_data/eo1'
    YYYY = imname[10:14]
    DDD = imname[14:17]
    instrument = imname[3]  # 'A' if ALI, 'H' if Hyperion

    if instrument == 'A':
        instrdir = 'ali_l1g'
        suffix = '_ALI_L1G'
        digits = '%02d'
    else:
        instrdir = 'hyperion_l1g'
        suffix = '_HYP_L1G'
        digits = '%03d'
    basefile = '/'.join([basedir, instrdir, YYYY, DDD, imname + suffix, imname])

    # Decide on a list of acceptable bands to use for each of R, G, and B.
    # The band numbers will be tried in order.
    if instrument == 'A':
        bands = [
            [5],  # R
            [4, 3],  # G
            [3, 4],  # B
        ]
    else:
        bands = [
            range(29, 41),  # R
            range(23, 14, -1),  # G
            range(16, 9, -1),  # B
        ]

    files = []
    usedBands = []
    for i, color in enumerate(bands):
        # Try each acceptable color until success, else error.
        for bandNum in color:
            tif = gdal.Open(basefile + '_B' + digits % bandNum + '_L1T.TIF')
            if tif is not None: break
        else:
            print "ERROR: No viable band found for %s component." % "RGB"[i]
            print "       Tried these bands:", color
            exit(1)
        files.append(tif)
        usedBands.append(bandNum)

    print "Creating using bands", usedBands
    saveRGB(files, outfile, scaleFactor)
