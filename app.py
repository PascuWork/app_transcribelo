from flask import Flask, request, render_template, send_file, jsonify
import whisperx
import os
from dotenv import load_dotenv
import time  # Para simular tiempo de procesamiento

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

# Variable global para el progreso
progress = 0

# Función para renombrar archivo a MP3 si es necesario
def ensure_mp3_extension(input_file):
    base, ext = os.path.splitext(input_file)
    if ext.lower() != '.mp3':
        mp3_file = f"{base}.mp3"
        os.rename(input_file, mp3_file)
        return mp3_file
    return input_file

@app.route('/', methods=['GET', 'POST'])
def upload_file():
    global progress
    progress = 0  # Resetea el progreso al inicio
    if request.method == 'POST':
        # Guardar el archivo subido en la carpeta 'uploads'
        audio_file = request.files['file']
        original_filename = audio_file.filename
        input_path = os.path.join('uploads', original_filename)
        audio_file.save(input_path)
        progress = 25  # Progreso del 25%

        # Renombrar el archivo a MP3 si es necesario
        output_mp3 = ensure_mp3_extension(input_path)
        progress = 50  # Progreso del 50%

        # Transcribir el audio con WhisperX
        audio = whisperx.load_audio(output_mp3)
        result = whisperx_model.transcribe(audio)
        progress = 75  # Progreso del 75%

        # Verificar si 'text' está en result
        if 'text' in result:
            transcripcion = result['text']
        else:
            transcripcion = "Transcripción no disponible."

        # Guardar la transcripción
        transcripcion_path = os.path.join('transcriptions', f"{os.path.splitext(original_filename)[0]}.txt")
        with open(transcripcion_path, 'w') as f:
            f.write(transcripcion)
        
        progress = 100  # Progreso completado

        return render_template('download.html')

    return render_template('upload.html')

@app.route('/progress')
def get_progress():
    global progress
    return jsonify({'progress': progress})

@app.route('/download/transcripcion')
def download_file():
    # Cambiar el nombre del archivo de transcripción basado en el archivo original
    transcripcion_file = os.path.join('transcriptions', 'transcripcion.txt')
    return send_file(transcripcion_file, as_attachment=True)

if __name__ == '__main__':
    app.run(debug=True)
