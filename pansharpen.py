"""
This Python program will create a set of pansharpened GeoTIFFs from the
original bands of an Earth Observing-1 ALI scene using its panchromatic
band and place them in a user-supplied directory.

History:
Aug 2014: Loosely adapted from createRGB.py

Usage:
For use on the Open Science Data Cloud public data commons.
$ python pansharpen.py IMAGEID OUTDIR
For example, make an image of the Italian coast from Jan 29, 2014:
$ python pansharpen.py EO1A1930292014029110PZ myoutputdirectory
"""

from osgeo import gdal
import numpy as np
import argparse

import sys

__author__ = "Maria Patterson, and Nikolas Anderson"
__version__ = "0.1"

def pansharpen(imname, inDir, outDir):
    """Create pansharpened images from EO-1 scene directory."""
    pan = gdal.Open(inDir + '/' + imname + '_B' + digits % 1 + '_L1T.TIF')
    bigPan = pan.ReadAsArray()[:-1, :-1]

    bandNums = []
    srcs = []
    dests = []
    driver = gdal.GetDriverByName("GTiff")
    driver.Register()
    for bandNum in range(2, 11):
        tif = gdal.Open(inDir+'/'+imname + '_B' + digits % bandNum + '_L1T.TIF')
        if tif is None:
            print "WARNING: Band %d not found." % bands
            continue
        bandNums.append(bandNum)
        srcs.append(tif)
        dests.append(driver.CreateCopy(outDir + '/' + imname + '_B' +
                                       digits % bandNum + '_L1T.TIF', pan, 0))

    imgs = [np.float64(src.ReadAsArray()[:-1, :-1]) for src in srcs]
    smoothPan = np.kron(sum(imgs) / len(imgs), np.ones([3, 3])) + 1e-9

    for img, dest in zip(imgs, dests):
        newimg = bigPan / smoothPan * np.kron(img, np.ones([3, 3]))
        #newimg[newimg > 255] = 255
        band = dest.GetRasterBand(1)
        band.WriteArray(newimg)
    dest = None
    dests = None

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Make pansharpened GeoTIFFs'
                                                 'for an ALI scene.')
    parser.add_argument('imname', type=str, help='Scene ID of an ALI scene. '
                                                 'E.g., EO1A1930292014029110PZ')
    parser.add_argument('outDir', type=str,
                        help='Output directory for scene images.')
    options = parser.parse_args()
    imname = options.imname
    outDir = options.outDir

    # TODO: Check whether outDir is really a directory.

    basedir = '/glusterfs/osdc_public_data/eo1'
    YYYY = imname[10:14]
    DDD = imname[14:17]
    instrument = imname[3]  # 'A' if ALI, 'H' if Hyperion

    if instrument == 'A':
        instrdir = 'ali_l1g'
        suffix = '_ALI_L1G'
        digits = '%02d'
    else:
        print("ERROR: Only ALI scenes can be pansharpened.")
        exit(1)
    inDir = '/'.join([basedir, instrdir, YYYY, DDD, imname + suffix])

    pansharpen(imname, inDir, outDir)
