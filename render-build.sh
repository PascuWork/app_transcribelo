#!/bin/bash
# Descargar FFmpeg
curl -L https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-64bit-static.tar.xz -o ffmpeg.tar.xz
# Extraer el archivo
tar -xf ffmpeg.tar.xz
# Mover el binario de FFmpeg a /usr/local/bin
mv ffmpeg-*-static/ffmpeg /usr/local/bin/ffmpeg
# Limpieza
rm -rf ffmpeg.tar.xz ffmpeg-*-static
