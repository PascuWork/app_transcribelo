# transcribelo
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
│   │   └── styles.css           # Archivo de estilos
│   └── js/                      # Carpeta para archivos JS (opcional si necesitas JavaScript)
│       └── main.js              # Archivo JavaScript principal (si es necesario)
│
├── uploads/                     # Carpeta temporal para guardar los archivos subidos (e.g., .mp3)
│   └── (Aquí se almacenan temporalmente los archivos de audio que se procesarán)
│
├── transcriptions/              # Carpeta para guardar las transcripciones
│   └── (Aquí se almacenan los archivos de texto de las transcripciones)
│
├── summaries/                   # Carpeta para guardar los resúmenes en formato Markdown
│   └── (Aquí se almacenan los archivos .md generados)
│
├── app.py                       # Código principal de la aplicación Flask
│
├── .env                         # Archivo para las variables de entorno (API keys)
│   └── (No subas este archivo a GitHub; contiene información sensible)
│
├── .gitignore                   # Archivos y carpetas que no se deben subir a GitHub
│
├── requirements.txt             # Dependencias necesarias para el proyecto
│
└── setup_project.sh             # Script para configurar el entorno de desarrollo

