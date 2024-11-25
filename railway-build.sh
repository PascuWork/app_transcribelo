#!/bin/bash

# Asegurarse de que el archivo tiene permisos de ejecución
chmod +x railway-build.sh

# Instalación de FFmpeg
echo "Clonando el repositorio oficial de FFmpeg..."
git clone https://github.com/FFmpeg/FFmpeg.git ffmpeg-source

echo "Instalando dependencias necesarias para compilar FFmpeg..."
apt-get update && apt-get install -y yasm pkg-config gcc g++ make libsndfile1 python3 python3-pip

echo "Compilando FFmpeg desde el código fuente..."
cd ffmpeg-source
./configure --prefix=/usr/local --disable-static --enable-shared
make -j$(nproc)
make install

echo "Limpiando archivos temporales..."
cd ..
rm -rf ffmpeg-source

echo "FFmpeg instalado exitosamente."

# Instalación de dependencias de Python
echo "Instalando dependencias de Python..."
pip install --upgrade pip
pip install -r requirements.txt

echo "Configuración completada con éxito."
