#!/bin/bash

# Configuración del entorno para el proyecto


# Instalar las dependencias necesarias desde requirements.txt (si no existe, crearlo primero)
if [[ ! -f "requirements.txt" ]]; then
  cat <<EOL > requirements.txt
flask
faster-whisper
torch
python-dotenv
ffmpeg-python
EOL
fi

pip install -r requirements.txt

# Crear la estructura de directorios
mkdir -p templates static/css static/js static/images/flags uploads transcriptions summaries


# Crear archivo app.py con el contenido actualizado de la aplicación Flask
cat <<EOL > app.py
from flask import Flask, request, render_template, send_file, jsonify
from faster_whisper import WhisperModel
import subprocess
import os
import threading
import torch
from io import BytesIO
import tempfile

# Configurar FFmpeg
ffmpeg_path = "P:/ffmpeg/bin/ffmpeg.exe"

app = Flask(__name__)

# Verificación de CUDA: usar GPU si está disponible, de lo contrario, usar CPU
device = "cuda" if torch.cuda.is_available() else "cpu"
print(f"Inicializando Whisper en {device}...")

# Variable global para almacenar el progreso
progress = {
    "status": "Procesando...",
    "percent": 0
}

# Caché para los modelos cargados
loaded_models = {}

def load_whisper_model(model_name):
    if model_name in loaded_models:
        print(f"Usando modelo {model_name} de la caché.")
        return loaded_models[model_name]
    else:
        print(f"Cargando modelo {model_name} en {device}...")
        whisper_model = WhisperModel(
            model_name,
            device=device,
            compute_type="float16" if device == "cuda" else "int8"
        )
        loaded_models[model_name] = whisper_model
        print(f"Modelo {model_name} cargado exitosamente.")
        return whisper_model

def convert_to_mp3_in_memory(file_storage):
    output_mp3 = BytesIO()

    command = [
        ffmpeg_path,
        '-i', 'pipe:0',
        '-ac', '1',
        '-ar', '16000',
        '-b:a', '32k',
        '-f', 'mp3',
        'pipe:1'
    ]

    process = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout_data, stderr_data = process.communicate(input=file_storage.read())

    if process.returncode != 0:
        error_message = stderr_data.decode()
        print(f"Error en la conversión de FFmpeg: {error_message}")
        raise Exception(f"Error en la conversión de FFmpeg: {error_message}")

    output_mp3.write(stdout_data)
    output_mp3.seek(0)
    print(f"Archivo convertido y optimizado en memoria.")
    return output_mp3

def transcribir_audio(input_stream, transcripcion_path, language, model_name):
    global progress
    try:
        whisper_model = load_whisper_model(model_name)

        with tempfile.NamedTemporaryFile(suffix=".mp3", delete=False) as temp_audio_file:
            temp_audio_file.write(input_stream.getvalue())
            temp_audio_file.flush()
            temp_audio_path = temp_audio_file.name

        print(f"Archivo temporal creado en {temp_audio_path}")

        # Transcribir el audio
        print(f"Iniciando transcripción con el idioma '{language}'...")
        segments, info = whisper_model.transcribe(
            temp_audio_path,
            language=language or None,
            beam_size=5,
            word_timestamps=False
        )

        print(f"Información de la transcripción: {info}")

        transcripcion = ""
        total_segments = 0
        for i, segment in enumerate(segments):
            print(f"Segmento {i}: {segment.text}")
            transcripcion += segment.text + " "
            total_segments = i + 1

            # Actualizar progreso cada 10 segmentos o al final
            if total_segments % 10 == 0 or segment.end == info.duration:
                progress['percent'] = int((segment.end / info.duration) * 100)
                progress['status'] = f"Transcribiendo... {progress['percent']}% completado"
                print(progress['status'])

        if total_segments == 0:
            raise ValueError("No se encontraron segmentos en el archivo de audio.")

        # Guardar la transcripción
        with open(transcripcion_path, 'w', encoding='utf-8') as f:
            f.write(transcripcion.strip())
        progress['status'] = "Completado"
        progress['percent'] = 100
        print("Transcripción completada y guardada.")

        # Eliminar el archivo temporal
        os.remove(temp_audio_path)
        print(f"Archivo temporal eliminado: {temp_audio_path}")

    except Exception as e:
        progress['status'] = f"Error: {str(e)}"
        print(f"Error en la transcripción: {str(e)}")
        import traceback
        traceback.print_exc()

@app.route('/', methods=['GET', 'POST'])
def upload_file():
    global progress
    if request.method == 'POST':
        try:
            audio_file = request.files['file']
            if not audio_file:
                return 'No se proporcionó ningún archivo', 400

            original_filename = audio_file.filename
            if not original_filename:
                return 'El archivo no tiene un nombre válido', 400

            # Convierte el archivo de audio a MP3 en memoria
            optimized_audio_stream = convert_to_mp3_in_memory(audio_file)

            transcripcion_filename = os.path.splitext(original_filename)[0] + '.txt'
            transcripcion_path = os.path.join('transcriptions', transcripcion_filename)

            selected_language = request.form.get('language', None)
            selected_model = request.form.get('model', 'small')

            print(f"Idioma seleccionado: {selected_language}")
            print(f"Modelo seleccionado: {selected_model}")

            progress = {"status": "Iniciando transcripción...", "percent": 0}

            thread = threading.Thread(target=transcribir_audio, args=(
                optimized_audio_stream,
                transcripcion_path,
                selected_language,
                selected_model
            ))
            thread.start()

            return render_template('progress.html', transcripcion_filename=transcripcion_filename)
        except Exception as e:
            print(f"Error al procesar el archivo: {e}")
            import traceback
            traceback.print_exc()
            return jsonify({"error": str(e)}), 500

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
    # Asegúrate de que el directorio 'transcriptions' existe
    if not os.path.exists('transcriptions'):
        os.makedirs('transcriptions')
    app.run(debug=True)
EOL

# Crear archivo upload.html en la carpeta templates
cat <<EOL > templates/upload.html
<!doctype html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Subir Archivo</title>
    <!-- Enlazar el archivo CSS -->
    <link rel="stylesheet" href="{{ url_for('static', filename='css/styles.css') }}">
</head>
<body>

    <h1>Sube tu Archivo de Audio</h1>

    <form method="post" enctype="multipart/form-data">
        <label for="file">Selecciona un archivo de audio:</label>
        <input type="file" name="file" id="file" required>

        <label for="language">Selecciona el idioma del audio:</label>
        <!-- Selector personalizado -->
        <div class="custom-select-wrapper">
            <div class="custom-select">
                <div class="custom-select__trigger">
                    <span><img src="{{ url_for('static', filename='images/flags/es.png') }}" alt="Español" class="flag-icon"> Español</span>
                    <div class="arrow"></div>
                </div>
                <div class="custom-options">
                    <div class="custom-option selected" data-value="es">
                        <img src="{{ url_for('static', filename='images/flags/es.png') }}" alt="Español" class="flag-icon"> Español
                    </div>
                    <div class="custom-option" data-value="en">
                        <img src="{{ url_for('static', filename='images/flags/en.png') }}" alt="Inglés" class="flag-icon"> Inglés
                    </div>
                    <div class="custom-option" data-value="ja">
                        <img src="{{ url_for('static', filename='images/flags/ja.png') }}" alt="Japonés" class="flag-icon"> Japonés
                    </div>
                    <!-- Agrega más opciones de idioma aquí -->
                </div>
            </div>
        </div>
        <input type="hidden" name="language" id="language" value="es">

        <!-- Selector de modelo -->
        <label for="model">Selecciona el modelo de Whisper:</label>
        <select name="model" id="model" required>
            <option value="tiny">Tiny (Rápido, menos preciso)</option>
            <option value="base">Base (Equilibrio entre velocidad y precisión)</option>
            <option value="small" selected>Small</option>
            <option value="medium">Medium</option>
            <option value="large-v2">Large (Más preciso, más lento)</option>
        </select>

        <button type="submit">Subir y Transcribir</button>
    </form>

    <!-- Logo en la esquina inferior izquierda -->
    <img src="{{ url_for('static', filename='images/logo.png') }}" alt="Logo" class="logo">

    <!-- Enlazar el archivo JavaScript -->
    <script src="{{ url_for('static', filename='js/scripts.js') }}"></script>
</body>
</html>
EOL

# Crear archivo progress.html en la carpeta templates
cat <<EOL > templates/progress.html
<!doctype html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Transcripción en progreso</title>
    <!-- Enlazar el archivo CSS -->
    <link rel="stylesheet" href="{{ url_for('static', filename='css/styles.css') }}">
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
        #download-link {
            display: none;
            margin-top: 20px;
        }
    </style>
</head>
<body>
    <h1>Transcripción en progreso...</h1>
    <div id="progress-bar-container">
        <div id="progress-bar">0%</div>
    </div>
    <p id="progress-status">Iniciando transcripción...</p>

    <div id="download-link">
        <h2>Procesamiento Completo</h2>
        <p>Tu archivo ha sido procesado. Puedes descargar los resultados a continuación:</p>
        <a id="download-transcription" href="#">Descargar Transcripción (.txt)</a>
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
                    $('#download-link').show();
                    $('#download-transcription').attr('href', '/download/{{ transcripcion_filename }}');
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

# Crear archivo CSS en static/css
cat <<EOL > static/css/styles.css
/* Estilos generales */
body {
    font-family: Arial, sans-serif;
    background-color: #fff9e6; /* Fondo amarillo pastel */
    color: #333;
    text-align: center;
    padding: 20px;
    position: relative; /* Necesario para posicionar elementos dentro del body */
    min-height: 100vh; /* Asegura que el body ocupe al menos el alto de la ventana */
}

form {
    display: inline-block;
    margin-top: 30px;
    text-align: left;
    box-shadow: 0 4px 10px rgba(0, 0, 0, 0.1);
    background-color: #ffffff;
    padding: 30px;
    border-radius: 10px;
}

label {
    display: block;
    margin-top: 15px;
    font-weight: bold;
}

input[type="file"],
select,
button {
    width: 100%;
    padding: 10px;
    margin-top: 5px;
    font-size: 16px;
}

button {
    background-color: #ffb84d;
    color: #fff;
    border: none;
    border-radius: 5px;
    cursor: pointer;
    margin-top: 20px;
    font-size: 16px;
    box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
}

button:hover {
    background-color: #ffa31a;
}

/* Estilos para el título */
h1 {
    margin-top: 0;
    font-size: 2em;
    margin-bottom: 20px;
}

/* Estilos para el logo en la esquina inferior izquierda */
.logo {
    position: fixed;
    bottom: 10px; /* Ajusta según sea necesario */
    left: 10px;   /* Ajusta según sea necesario */
    max-width: 150px; /* Ajusta el tamaño del logo */
    height: auto;
}

/* Estilos para el selector personalizado */
.custom-select-wrapper {
    position: relative;
    user-select: none;
    width: 100%;
}

.custom-select {
    position: relative;
}

.custom-select__trigger {
    position: relative;
    display: flex;
    justify-content: space-between;
    align-items: center;
    background-color: #fff;
    padding: 10px;
    font-size: 16px;
    cursor: pointer;
    border: 1px solid #ccc;
    border-radius: 5px;
}

.custom-select__trigger span {
    display: flex;
    align-items: center;
}

.custom-options {
    position: absolute;
    top: 100%;
    left: 0;
    right: 0;
    background-color: #fff;
    max-height: 200px;
    overflow-y: auto;
    border: 1px solid #ccc;
    border-radius: 5px;
    display: none;
    z-index: 999;
}

.custom-option {
    padding: 10px;
    cursor: pointer;
    display: flex;
    align-items: center;
}

.custom-option:hover {
    background-color: #f2f2f2;
}

.custom-option.selected {
    background-color: #ffb84d;
    color: #fff;
}

.flag-icon {
    width: 20px;
    height: auto;
    vertical-align: middle;
    margin-right: 8px;
}

.arrow {
    width: 0;
    height: 0;
    margin-left: 10px;
    border-left: 6px solid transparent;
    border-right: 6px solid transparent;
    border-top: 6px solid #333;
}

.custom-select.open .custom-options {
    display: block;
}

.custom-select.open .arrow {
    border-top: none;
    border-bottom: 6px solid #333;
}
EOL

# Crear archivo JS en static/js
cat <<EOL > static/js/scripts.js
// scripts.js

document.addEventListener('DOMContentLoaded', function() {
    const select = document.querySelector('.custom-select');
    const trigger = select.querySelector('.custom-select__trigger');
    const options = select.querySelectorAll('.custom-option');
    const hiddenInput = document.getElementById('language');

    trigger.addEventListener('click', function() {
        select.classList.toggle('open');
    });

    options.forEach(option => {
        option.addEventListener('click', function() {
            options.forEach(opt => opt.classList.remove('selected'));
            this.classList.add('selected');
            trigger.innerHTML = this.innerHTML + '<div class="arrow"></div>';
            select.classList.remove('open');
            // Actualizar el valor seleccionado
            hiddenInput.value = this.getAttribute('data-value');
        });
    });

    // Cerrar el selector si se hace clic fuera
    document.addEventListener('click', function(e) {
        if (!select.contains(e.target)) {
            select.classList.remove('open');
        }
    });
});
EOL

# Crear el README.md con la descripción básica del proyecto
cat <<EOL > README.md
# Proyecto de Pascual

Este proyecto es una aplicación web que permite a los usuarios subir archivos de audio y transcribirlos utilizando el modelo Whisper.

## Configuración y ejecución

Ejecuta el script \`setup.sh\` (este script) para configurar el entorno y las dependencias necesarias.

EOL

echo "Configuración completada exitosamente."
