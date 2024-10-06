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
whisperx_model = whisperx.load_model("medium", device, compute_type="float32")  # Cambiado a 'medium'
print("Modelo WhisperX cargado exitosamente.")

# Variable global para almacenar el progreso
progress = {
    "status": "Procesando...",
    "percent": 0
}

# Función para convertir el archivo de audio a MP3 optimizado
def convert_to_mp3(input_file, output_file):
    ffmpeg_path = "P:/ffmpeg/bin/ffmpeg.exe"  # Ruta completa a FFmpeg
    
    # Comando FFmpeg para optimizar el audio
    command = [
        ffmpeg_path, 
        '-i', input_file,           # Archivo de entrada
        '-ac', '1',                 # Convertir a mono
        '-ar', '16000',             # Reducir la frecuencia de muestreo a 16 kHz
        '-b:a', '64k',              # Reducir la tasa de bits a 64 kbps
        output_file
    ]
    
    subprocess.run(command, check=True)
    print(f"Archivo convertido y optimizado en {output_file}")

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

            # Actualizar progreso cada 10 segmentos
            if (i + 1) % 10 == 0 or i == total_segments - 1:
                progress['percent'] = int((i + 1) / total_segments * 100)
                progress['status'] = f"Transcribiendo... {progress['percent']}% completado"
                print(progress['status'])

            # Reducir la pausa para mejorar la velocidad
            import time
            time.sleep(0.01)

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

        # Convertir el archivo a MP3 optimizado
        output_mp3 = os.path.join('uploads', 'audio_optimized.mp3')
        convert_to_mp3(input_path, output_mp3)

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
