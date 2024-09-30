#!/bin/bash

# Configuración del entorno para el proyecto

# Crear un entorno virtual
python -m venv venv

# Activar el entorno virtual en Windows
source venv/Scripts/activate

# Instalar las dependencias necesarias desde requirements.txt (si no existe, crearlo primero)
if [[ ! -f "requirements.txt" ]]; then
  cat <<EOL > requirements.txt
flask
openai-whisper
python-dotenv
openai
ffmpeg-python
EOL
fi

pip install -r requirements.txt

# Crear la estructura de directorios
mkdir -p templates static/css static/js uploads transcriptions summaries

# Crear el archivo .env con las variables necesarias
cat <<EOL > .env
OPENAI_API_KEY="TU_CLAVE_API_AQUÍ"
EOL

# Crear archivo app.py con el contenido básico de la aplicación Flask y WhisperX
cat <<EOL > app.py
from flask import Flask, request, render_template, send_file
import whisperx
import openai
import subprocess
from dotenv import load_dotenv
import os

# Agrega FFmpeg al PATH en tiempo de ejecución
os.environ['PATH'] += os.pathsep + "P:/ffmpeg/bin"

# Cargar variables de entorno desde .env
load_dotenv()

app = Flask(__name__)

# Configuración de WhisperX
device = "cpu"  # Cambia a "cuda" si tienes GPU
whisperx_model = whisperx.load_model("large-v2", device)

# Clave API de OpenAI desde .env
openai.api_key = os.getenv('OPENAI_API_KEY')

# Función para convertir archivos de audio a MP3 si es necesario
def convert_to_mp3(input_file, output_file):
    ffmpeg_path = "P:/ffmpeg/bin/ffmpeg.exe"  # Ruta completa a FFmpeg
    command = [ffmpeg_path, '-i', input_file, output_file]
    subprocess.run(command, check=True)

@app.route('/', methods=['GET', 'POST'])
def upload_file():
    if request.method == 'POST':
        # Guardar el archivo subido en la carpeta 'uploads'
        audio_file = request.files['file']
        input_path = os.path.join('uploads', 'audio_input')
        audio_file.save(input_path)

        # Convertir el archivo a MP3 si es necesario
        output_mp3 = os.path.join('uploads', 'audio.mp3')
        convert_to_mp3(input_path, output_mp3)

        # Transcribir el audio con WhisperX
        audio = whisperx.load_audio(output_mp3)
        result = whisperx_model.transcribe(audio)
        transcripcion = result['text']

        # Guardar la transcripción en la carpeta 'transcriptions'
        transcripcion_path = os.path.join('transcriptions', 'transcripcion.txt')
        with open(transcripcion_path, 'w') as f:
            f.write(transcripcion)

        # Generar resumen con GPT
        respuesta = openai.ChatCompletion.create(
            model="gpt-4-mini",  # Puedes cambiar al modelo de tu preferencia
            messages=[
                {"role": "system", "content": "Eres un asistente que crea resúmenes detallados en Markdown."},
                {"role": "user", "content": f"Resume el siguiente texto:\n{transcripcion}"}
            ]
        )
        resumen = respuesta['choices'][0]['message']['content']

        # Guardar el resumen en la carpeta 'summaries'
        resumen_path = os.path.join('summaries', 'resumen.md')
        with open(resumen_path, 'w') as f:
            f.write(resumen)

        return render_template('download.html')

    return render_template('upload.html')

@app.route('/download/<filename>')
def download_file(filename):
    if filename == 'transcripcion':
        return send_file(os.path.join('transcriptions', 'transcripcion.txt'), as_attachment=True)
    elif filename == 'resumen':
        return send_file(os.path.join('summaries', 'resumen.md'), as_attachment=True)
    else:
        return 'Archivo no encontrado', 404

if __name__ == '__main__':
    app.run(debug=True)
EOL

# Crear archivo upload.html en la carpeta templates
cat <<EOL > templates/upload.html
<!doctype html>
<html>
<head>
    <title>Subir Archivo</title>
</head>
<body>
    <h1>Sube tu archivo .mp3 o de otro formato de audio</h1>
    <form method="post" enctype="multipart/form-data">
        <input type="file" name="file" required>
        <button type="submit">Subir</button>
    </form>
</body>
</html>
EOL

# Crear archivo download.html en la carpeta templates
cat <<EOL > templates/download.html
<!doctype html>
<html>
<head>
    <title>Descargar Resultados</title>
</head>
<body>
    <h1>Procesamiento Completo</h1>
    <p>Tu archivo ha sido procesado. Puedes descargar los resultados a continuación:</p>
    <a href="/download/transcripcion">Descargar Transcripción (.txt)</a><br>
    <a href="/download/resumen">Descargar Resumen (.md)</a>
</body>
</html>
EOL

# Crear un archivo CSS opcional en static/css
cat <<EOL > static/css/styles.css
/* Estilos personalizados */
body {
    font-family: Arial, sans-serif;
    background-color: #f4f4f4;
    color: #333;
}
EOL

# Crear un archivo JS opcional en static/js
cat <<EOL > static/js/main.js
// Funciones JavaScript opcionales
console.log("Página cargada");
EOL

# Crear el README.md con la descripción básica del proyecto
cat <<EOL > README.md
# Transcribelo Proyecto
EOL

echo "Configuración completada exitosamente."
