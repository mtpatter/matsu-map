matsu-map
=========

Code for creating analytics based on EO-1 images, uploading them to GeoServer,
and posting them to an Atom feed to facilitate discovery.

Setup
-----

Perform

```bash
cp config.sh.sample config.sh
```

and modify `config.sh` according to the parameters of your GeoServer and Atom
Hopper installations.

Use
---

To upload one or more GeoTIFFs to GeoServer, run `gsload.sh` with the files as
arguments. For example:

```bash
./gsload.sh first.tif second.tif
```

If you wish to create an RGB image for an EO-1 scene, perform

```bash
python createRGB.py SCENEID
```

If you need to create and upload a large number of RGB images for testing
purposes, simply run

```bash
./makeRGB.sh
```
