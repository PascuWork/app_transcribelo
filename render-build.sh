#!/bin/bash

echo "Clonando el repositorio oficial de FFmpeg..."
git clone https://github.com/FFmpeg/FFmpeg.git ffmpeg-source

echo "Instalando dependencias necesarias para compilar FFmpeg..."
apt-get update && apt-get install -y yasm pkg-config gcc g++ make

echo "Compilando FFmpeg desde el código fuente..."
cd ffmpeg-source
./configure --prefix=/usr/local --disable-static --enable-shared
make
make install

echo "Limpiando archivos temporales..."
cd ..
rm -rf ffmpeg-source

echo "FFmpeg instalado exitosamente."
