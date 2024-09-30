#!/bin/bash

# Verifica si estás en un sistema Windows
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    echo "Instalando FFmpeg para Windows..."

    # Verifica si FFmpeg ya está instalado
    if command -v ffmpeg &> /dev/null; then
        echo "FFmpeg ya está instalado."
    else
        # Descargar FFmpeg para Windows (versión precompilada)
        curl -L https://github.com/GyanD/codexffmpeg/releases/download/2023-09-01/ffmpeg-2023-09-01-git-e3f97ca5d6-full_build.zip -o ffmpeg.zip

        # Extraer FFmpeg
        unzip ffmpeg.zip -d ffmpeg

        # Mover FFmpeg al directorio correcto (dentro de la carpeta de programas o similar)
        mkdir -p "$HOME/Programs/ffmpeg"
        mv ffmpeg/* "$HOME/Programs/ffmpeg"

        # Agregar FFmpeg al PATH de manera permanente usando PowerShell
        echo "Agregando FFmpeg al PATH permanentemente..."
        powershell -Command '[Environment]::SetEnvironmentVariable("PATH", "$env:PATH;$HOME/Programs/ffmpeg/bin", [EnvironmentVariableTarget]::User)'

        echo "FFmpeg instalado correctamente y agregado al PATH."
        echo "Es posible que necesites reiniciar la terminal para que los cambios surtan efecto."
    fi
else
    echo "Este script es solo para sistemas Windows."
fi
