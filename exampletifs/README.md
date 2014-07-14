The files ALI images were produced from scene scene `EO1A1930292014029110PZ`, and the Hyperion images from scene `EO1H0830672014063110KF`.

Files with base names ending in `rgb` were produced using `createRGB.py`, a utility for combining EO-1 data to form visible spectrum images. Files ending in `classified` or `colored` were produced using Jake's classifier.

The prefix `pct` means that the image was created by applying `rgb2pct.py` to one of the original files. The prefix `compressed` means that the image was produced using `gdal_translate -co COMPRESS=DEFLATE`. The prefix `jpeg` means that the image was produced using `gdal_translate -co COMPRESS=JPEG`.

All images use 8-bit color depth.
