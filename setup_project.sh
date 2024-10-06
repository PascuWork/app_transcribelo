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
from flask import Flask, request, render_template, send_file, jsonify
import whisperx
import subprocess
from dotenv import load_dotenv
import os
import threading

# Agrega FFmpeg al PATH en tiempo de ejecución
os.environ['PATH'] += os.pathsep + "P:/ffmpeg/bin"

# Cargar variables de entorno desde .env
load_dotenv()

app = Flask(__name__)

# Configuración de WhisperX
device = "cpu"  # Cambia a "cuda" si tienes GPU
print(f"Inicializando modelo WhisperX en {device}...")
whisperx_model = whisperx.load_model("large-v2", device, compute_type="float32")
print("Modelo WhisperX cargado exitosamente.")

# Variable global para almacenar el progreso
progress = {
    "status": "Procesando...",
    "percent": 0
}

# Función para renombrar archivo a MP3 si es necesario
def ensure_mp3_extension(input_file):
    base, ext = os.path.splitext(input_file)
    if ext.lower() != '.mp3':
        # Renombrar el archivo con la extensión .mp3
        mp3_file = f"{base}.mp3"
        os.rename(input_file, mp3_file)
        print(f"Renombrando archivo {input_file} a {mp3_file}")
        return mp3_file
    return input_file

# Función para realizar la transcripción en segundo plano
def transcribir_audio(output_mp3, transcripcion_path, language):
    global progress
    try:
        # Transcribir el audio con WhisperX
        print("Cargando audio para transcripción...")
        audio = whisperx.load_audio(output_mp3)
        print("Audio cargado exitosamente, iniciando transcripción...")

        # Transcripción en segmentos
        result = whisperx_model.transcribe(audio, language=language)  # Usar el idioma seleccionado
        segments = result.get('segments', [])

        # Procesar los segmentos y calcular progreso real
        total_segments = len(segments)
        if total_segments == 0:
            raise ValueError("No se encontraron segmentos en el archivo de audio.")

        transcripcion = ""
        for i, segment in enumerate(segments):
            transcripcion += segment['text'] + " "
            # Actualizar progreso
            progress['percent'] = int((i + 1) / total_segments * 100)
            progress['status'] = f"Transcribiendo... {progress['percent']}% completado"
            print(progress['status'])
            # Simulación de trabajo pesado
            import time
            time.sleep(0.05)  # Pequeña pausa simulada para actualización progresiva

        # Guardar la transcripción en el archivo de texto
        with open(transcripcion_path, 'w') as f:
            f.write(transcripcion)
        progress['status'] = "Completado"
        progress['percent'] = 100
        print("Transcripción completada y guardada.")

    except Exception as e:
        progress['status'] = f"Error: {str(e)}"
        print(f"Error en la transcripción: {str(e)}")

@app.route('/', methods=['GET', 'POST'])
def upload_file():
    global progress
    if request.method == 'POST':
        # Guardar el archivo subido en la carpeta 'uploads'
        audio_file = request.files['file']
        original_filename = audio_file.filename
        input_path = os.path.join('uploads', original_filename)
        print(f"Guardando archivo subido en {input_path}...")
        audio_file.save(input_path)
        print(f"Archivo guardado en {input_path}.")

        # Renombrar el archivo a MP3 si es necesario
        output_mp3 = ensure_mp3_extension(input_path)

        # Nombre de archivo de transcripción
        transcripcion_filename = os.path.splitext(original_filename)[0] + '.txt'
        transcripcion_path = os.path.join('transcriptions', transcripcion_filename)

        # Capturar el idioma seleccionado por el usuario
        selected_language = request.form['language']

        # Restablecer progreso
        progress = {"status": "Iniciando transcripción...", "percent": 0}

        # Procesar el audio en un hilo separado para no bloquear el servidor
        thread = threading.Thread(target=transcribir_audio, args=(output_mp3, transcripcion_path, selected_language))
        thread.start()

        return render_template('progress.html', transcripcion_filename=transcripcion_filename)

    return render_template('upload.html')

@app.route('/progress')
def get_progress():
    global progress
    return jsonify(progress)

@app.route('/download/<filename>')
def download_file(filename):
    transcripcion_path = os.path.join('transcriptions', filename)
    if os.path.exists(transcripcion_path):
        return send_file(transcripcion_path, as_attachment=True)
    else:
        return 'Archivo no encontrado', 404

if __name__ == '__main__':
    app.run(debug=True)
EOL

# Crear archivo upload.html en la carpeta templates
cat <<EOL > templates/upload.html
<!doctype html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Subir Archivo</title>
</head>
<body>
    <h1>Sube tu archivo .mp3 o de otro formato de audio</h1>
    <form method="post" enctype="multipart/form-data">
        <input type="file" name="file" required><br><br>
        
        <label for="language">Selecciona el idioma del audio:</label>
        <select name="language" required>
            <option value="es">Español</option>
            <option value="en">Inglés</option>
            <option value="de">Alemán</option>
            <option value="it">Italiano</option>
            <option value="fr">Francés</option>
            <option value="ja">Japonés</option>
            <option value="zh">Chino</option>
        </select><br><br>
        
        <button type="submit">Subir</button>
    </form>
</body>
</html>
EOL

# Crear archivo progress.html en la carpeta templates
cat <<EOL > templates/progress.html
<!doctype html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Transcripción en progreso</title>
    <script src="https://code.jquery.com/jquery-3.6.0.min.js"></script>
    <style>
        #progress-bar-container {
            width: 100%;
            background-color: #f3f3f3;
            border-radius: 25px;
            margin-top: 20px;
        }
        #progress-bar {
            width: 0%;
            height: 30px;
            background-color: #4caf50;
            border-radius: 25px;
            text-align: center;
            line-height: 30px;
            color: white;
        }
        #download-links {
            display: none;
            margin-top: 20px;
        }
    </style>
</head>
<body>
    <h1>Transcripción en progreso...</h1>
    <div id="progress-bar-container">
        <div id="progress-bar">0%</</div>
    </div>
    <p id="progress-status">Iniciando transcripción...</p>

    <div id="download-links">
        <h2>Procesamiento Completo</h2>
        <p>Tu archivo ha sido procesado. Puedes descargar los resultados a continuación:</p>
        <a id="download-transcription" href="#">Descargar Transcripción (.txt)</a><br>
        <a id="download-summary" href="#">Descargar Resumen (.md)</a>
    </div>

    <script>
        function updateProgress() {
            $.getJSON('/progress', function(data) {
                $('#progress-bar').css('width', data.percent + '%');
                $('#progress-bar').text(data.percent + '%');
                $('#progress-status').text(data.status);

                if (data.percent < 100) {
                    setTimeout(updateProgress, 1000);  // Actualizar cada 1 segundo
                } else {
                    $('#progress-bar-container').hide();
                    $('#progress-status').hide();
                    $('#download-links').show();
                    $('#download-transcription').attr('href', '/download/{{ transcripcion_filename }}');
                    $('#download-summary').attr('href', '/download/resumen.md');
                }
            });
        }

        $(document).ready(function() {
            updateProgress();
        });
    </script>
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
# Proyecto de Pascual
EOL

echo "Configuración completada exitosamente."
