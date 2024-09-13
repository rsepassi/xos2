#!/usr/bin/env sh

png=$1
out=icon

mkdir $out.iconset
sips -z 16 16     $png --out $out.iconset/icon_16x16.png
sips -z 32 32     $png --out $out.iconset/icon_16x16@2x.png
sips -z 32 32     $png --out $out.iconset/icon_32x32.png
sips -z 64 64     $png --out $out.iconset/icon_32x32@2x.png
sips -z 128 128   $png --out $out.iconset/icon_128x128.png
sips -z 256 256   $png --out $out.iconset/icon_128x128@2x.png
sips -z 256 256   $png --out $out.iconset/icon_256x256.png
sips -z 512 512   $png --out $out.iconset/icon_256x256@2x.png
sips -z 512 512   $png --out $out.iconset/icon_512x512.png
sips -z 1024 1024 $png --out $out.iconset/icon_512x512@2x.png

iconutil -c icns $out.iconset
