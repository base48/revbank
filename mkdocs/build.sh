#!/bin/sh
set -e
mkdir docs || true
perl pod2md.pl
sh md2md.sh
mkdocs build
rsync --recursive --copy-links /usr/lib/python3/dist-packages/mkdocs/themes/readthedocs/css/fonts/ site/fonts/
rsync -av site/ revspace-public:/data/revbank.nl/docs/
