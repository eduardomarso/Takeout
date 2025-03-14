#!/usr/bin/env bash

# configure shellscript
set -e
shopt -s globstar

# ensure dependencies are installed
for cmd in exiftool jq; do
  command -v "$cmd" >/dev/null 2>&1 || { echo >&2 "$cmd is not installed. Aborting."; exit 1; }
done

# change directory to the script directory
cd "$(dirname "$0")"

# create temporary file to store file paths
fullpaths=$(mktemp)

# delete fullpaths on exit
trap 'rm -f "$fullpaths"' EXIT

# find all JSON files and enumerate over them
files=(./**/*.json)

for i in "${!files[@]}"; do
  file="${files[$i]}"

  # read the filename from the JSON file
  filename=$(jq -r .title "$file")

  # skip if filename is empty
  if [ -z "$filename" ]; then
    continue
  fi

  # update filename with subscript if found
  # ./test.JPG(1).json -> 1
  # ./test.JPG.json -> ""
  if [[ $file =~ \(([0-9]+)\)\.json$ ]]; then
    filename="${filename%.*}(${BASH_REMATCH[1]}).${filename##*.}"
  fi

  # read the timestamp from the JSON file
  timestamp=$(jq -r .photoTakenTime.timestamp "$file")

  # get the directory of the JSON file
  directory=$(dirname "$file")

  # iterate over the original and edited file
  for f in "$filename" "${filename%.*}-edited.${filename##*.}"; do

    # get the full path of the file (Windows-compatible)
    fullpath=$(cygpath -w "$directory/$f")

    # skip if file does not exist
    if [ ! -f "$fullpath" ]; then
      continue
    fi

    # print progress
    echo "[$((i+1))/${#files[@]}] $file : $fullpath"

    # hardlink (it's fast) JSON to $fullpath.json (Windows-compatible)
    if [ ! -f "$fullpath.json" ]; then
      cp "$file" "$fullpath.json"
    fi

    # set modification time from unix timestamp (Windows-compatible)
    touch -m -t "$(date -d @"$timestamp" +%Y%m%d%H%M.%S)" "$fullpath"

    # append to fullpaths file (Windows-compatible)
    echo "$fullpath" >> "$fullpaths"

  done
done

# deduplicate fullpaths (sort does not matter but is nice)
sort -u "$fullpaths" > "$fullpaths.tmp"
mv "$fullpaths.tmp" "$fullpaths"

# print fullpaths size
echo "Found $(wc -l < "$fullpaths") unique files to process"

# run exiftool on all files with full metadata mapping
exiftool \
  -api LargeFileSupport=1 \
  -d %s \
  -tagsfromfile "%d%f.%e.json" \
  "-GPSAltitude<GeoDataAltitude" \
  "-GPSLatitude<GeoDataLatitude" \
  "-GPSLatitudeRef<GeoDataLatitude" \
  "-GPSLongitude<GeoDataLongitude" \
  "-GPSLongitudeRef<GeoDataLongitude" \
  "-GPSPosition<GeoDataLatitude,GeoDataLongitude" \
  "-DateTimeOriginal<PhotoTakenTimeTimestamp" \
  "-CreateDate<PhotoTakenTimeTimestamp" \
  "-ModifyDate<PhotoTakenTimeTimestamp" \
  "-Description<Description" \
  "-ImageDescription<Description" \
  "-Artist<GooglePhotosOrigin" \
  "-Copyright<GooglePhotosOrigin" \
  "-Keywords<Tags" \
  "-Subject<Tags" \
  "-Orientation<Rotation" \
  "-XResolution<PhotoLastModifiedTime" \
  "-YResolution<PhotoLastModifiedTime" \
  "-ResolutionUnit<PhotoLastModifiedTime" \
  "-Software<GooglePhotosOrigin" \
  "-UserComment<GooglePhotosOrigin" \
  "-ImageWidth<PhotoMetadataWidth" \
  "-ImageHeight<PhotoMetadataHeight" \
  "-ColorSpace<PhotoMetadataColorProfile" \
  "-Codec<PhotoMetadataCodec" \
  "-EncodingSoftware<PhotoMetadataEncodingSoftware" \
  "-overwrite_original" \
  "-preserve" \
  "-progress" \
  "-@ $fullpaths" || true

# clear any previous accidental input
while read -r -t 0; do read -r; done

# optional cleanup JSON files
read -p "Delete all JSON files? [y/N] " -n 1 -r
printf "\n"

if [[ $REPLY =~ ^[Yy]$ ]]; then
  for file in "${files[@]}"; do
    rm -v "$file"
  done
fi

# delete all empty folders
echo "Deleting empty folders..."
find . -type d -empty -delete
echo "Empty folders deleted."
