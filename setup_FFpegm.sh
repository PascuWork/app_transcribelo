#!/bin/bash
#ejecutar el script
#./setup_ffmpeg.sh
# Verifica si estás en un sistema Windows (Git Bash o WSL)
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    echo "Instalando FFmpeg precompilado para Windows..."

    # Descargar FFmpeg precompilado para Windows
    curl -L https://www.gyan.dev/ffmpeg/builds/ffmpeg-git-full.7z -o ffmpeg.7z

    # Verificar si la descarga fue exitosa
    if [[ -f "ffmpeg.7z" ]]; then
        echo "Descarga completada exitosamente."

        # Instalar 7-Zip si no está disponible (solo para Git Bash en Windows)
        if ! command -v 7z &> /dev/null; then
            echo "7-Zip no está instalado. Instalando 7-Zip..."
            curl -L https://www.7-zip.org/a/7z2107-x64.exe -o 7zip-installer.exe
            ./7zip-installer.exe /S  # Instalar silenciosamente
            echo "7-Zip instalado."
        fi

        # Extraer el archivo 7z descargado
        7z x ffmpeg.7z -offmpeg

        # Mover FFmpeg a la ruta P:\ffmpeg
        mkdir -p "P:/ffmpeg"
        mv ffmpeg/* "P:/ffmpeg"

        # Verifica si FFmpeg ya está en el PATH
        if command -v ffmpeg &> /dev/null; then
            echo "FFmpeg ya está en el PATH."
        else
            # Agregar FFmpeg al PATH de manera permanente usando PowerShell
            echo "Agregando FFmpeg al PATH permanentemente..."
            powershell -Command "[Environment]::SetEnvironmentVariable('PATH', \$env:PATH + ';P:\\ffmpeg\\bin', [EnvironmentVariableTarget]::User)"
            
            echo "FFmpeg instalado correctamente y agregado al PATH."
            echo "Es posible que necesites reiniciar la terminal o la computadora para que los cambios surtan efecto."
        fi
    else
        echo "La descarga de FFmpeg falló. Por favor, verifica tu conexión o el enlace de descarga."
    fi

else
    echo "Este script es solo para sistemas Windows con Git Bash o WSL."
fi
