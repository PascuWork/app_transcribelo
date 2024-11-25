# TranscribeLo

**TranscribeLo** es una aplicación web sencilla que permite a los usuarios subir archivos de audio (como `.mp3`), transcribirlos automáticamente utilizando **WhisperX**, y generar un resumen detallado del contenido transcrito usando **OpenAI GPT**. El proyecto está diseñado para facilitar la transcripción y resumen de archivos de audio con la opción de descargar tanto la transcripción completa como el resumen en formato **Markdown**.

## Arquitectura
```bash
/TRANSCRIBELO
│
├── venv/                        # Entorno virtual (no se sube a GitHub)
│
├── templates/                   # Plantillas HTML
│   ├── upload.html              # Página para subir archivos de audio
│   └── download.html            # Página para descargar los resultados (transcripción y resumen)
│
├── static/                      # Archivos estáticos (CSS, JS, imágenes)
│   ├── css/                     # Carpeta para archivos CSS
│   │   └── styles.css           # Archivo de estilos (opcional)
│   └── js/                      # Carpeta para archivos JS (opcional si necesitas JavaScript)
│       └── main.js              # Archivo JavaScript principal (opcional)
│
├── uploads/                     # Carpeta temporal para guardar los archivos subidos (e.g., .mp3)
│   └── (Aquí se almacenan temporalmente los archivos de audio que se procesarán)
│
├── transcriptions/              # Carpeta para guardar las transcripciones en formato .txt
│   └── (Aquí se almacenan los archivos de texto de las transcripciones)
│
├── summaries/                   # Carpeta para guardar los resúmenes en formato Markdown (.md)
│   └── (Aquí se almacenan los archivos .md generados)
│
├── app.py                       # Código principal de la aplicación Flask
│
├── .env                         # Archivo para las variables de entorno (API keys)
│   └── (No subas este archivo a GitHub; contiene información sensible como claves de API)
│
├── .gitignore                   # Archivos y carpetas que no se deben subir a GitHub
│
├── requirements.txt             # Dependencias necesarias para el proyecto
│
└── setup_project.sh             # Script para configurar el entorno de desarrollo
```

## Características

- **Subida de archivos de audio**: Los usuarios pueden subir archivos de audio en formato `.mp3` u otros formatos, que luego se convertirán automáticamente a `.mp3` si es necesario utilizando **FFmpeg**.
- **Transcripción automática**: Los archivos de audio son transcritos usando **WhisperX**, una versión avanzada y eficiente de **Whisper**.
- **Generación de resúmenes**: Un resumen en formato **Markdown** es generado automáticamente a partir de la transcripción usando **OpenAI GPT**.
- **Descarga de resultados**: Los usuarios pueden descargar tanto la transcripción completa en `.txt` como el resumen en `.md`.

## Estructura del Proyecto


## Tecnologías Utilizadas

- **Python**: Lenguaje principal de la aplicación.
- **Flask**: Framework web para crear la API y la interfaz web.
- **WhisperX**: Utilizado para transcribir archivos de audio.
- **OpenAI GPT**: Para generar resúmenes de los textos transcritos.
- **FFmpeg**: Para procesar y convertir archivos de audio a formatos compatibles.
- **HTML/CSS**: Para las plantillas front-end y la visualización en el navegador.

## Requisitos Previos

Antes de comenzar, asegúrate de tener instalados los siguientes programas:

- **Python 3.x**: Puedes descargarlo desde [aquí](https://www.python.org/downloads/).
- **FFmpeg**: Asegúrate de que esté instalado y añadido al `PATH` del sistema. Si no lo tienes, puedes instalarlo siguiendo las instrucciones proporcionadas en el script `setup_ffmpeg.sh`.
- **Clave de API de OpenAI**: Necesitarás una clave API para acceder a los servicios de OpenAI. 

