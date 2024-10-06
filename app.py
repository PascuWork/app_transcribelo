from flask import Flask, request, render_template, send_file, jsonify
import whisperx
import subprocess
from dotenv import load_dotenv
import os
import threading
import torch  # Import necesario para verificar si CUDA está disponible
from io import BytesIO
import tempfile  # Importar para manejar archivos temporales

# Agrega FFmpeg al PATH en tiempo de ejecución
os.environ['PATH'] += os.pathsep + "P:/ffmpeg/bin"

# Cargar variables de entorno desde .env
load_dotenv()

app = Flask(__name__)

# Verificación de CUDA: usar GPU si está disponible, de lo contrario, usar CPU
device = "cuda" if torch.cuda.is_available() else "cpu"
print(f"Inicializando modelo WhisperX en {device}...")

# Configuración de WhisperX
whisperx_model = whisperx.load_model("medium", device, compute_type="float32")
print(f"Modelo WhisperX cargado exitosamente en {device}.")

# Variable global para almacenar el progreso
progress = {
    "status": "Procesando...",
    "percent": 0
}

# Función para convertir el archivo de audio a MP3 optimizado en memoria
def convert_to_mp3_in_memory(input_file):
    ffmpeg_path = "P:/ffmpeg/bin/ffmpeg.exe"  # Ruta completa a FFmpeg

    # Usar flujos de memoria en lugar de escribir archivos
    output_mp3 = BytesIO()  # Flujo de salida para el archivo optimizado en memoria

    # Comando FFmpeg para optimizar el audio
    command = [
        ffmpeg_path,
        '-i', input_file,          # Archivo de entrada
        '-ac', '1',                # Convertir a mono
        '-ar', '16000',            # Reducir la frecuencia de muestreo a 16 kHz
        '-b:a', '32k',             # Reducir la tasa de bits a 32 kbps (más agresivo)
        '-f', 'mp3',               # Formato de salida mp3
        'pipe:1'                   # Salida a stdout (flujo en memoria)
    ]

    # Ejecutar el comando FFmpeg y escribir la salida en el flujo de memoria
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout_data, stderr_data = process.communicate()

    if process.returncode != 0:
        raise Exception(f"Error en la conversión de FFmpeg: {stderr_data.decode()}")

    output_mp3.write(stdout_data)
    output_mp3.seek(0)  # Reiniciar el puntero al principio del archivo en memoria

    print(f"Archivo convertido y optimizado en memoria.")
    return output_mp3

# Función para realizar la transcripción en segundo plano
def transcribir_audio(input_stream, transcripcion_path, language):
    global progress
    try:
        # Crear un archivo temporal para guardar el audio desde el flujo en memoria
        with tempfile.NamedTemporaryFile(suffix=".mp3", delete=False) as temp_audio_file:
            temp_audio_file.write(input_stream.read())
            temp_audio_file.flush()  # Asegurarse de que los datos se escriban completamente
            temp_audio_path = temp_audio_file.name

        print(f"Archivo temporal creado en {temp_audio_path}")

        # Cargar el audio desde el archivo temporal para WhisperX
        print("Cargando audio para transcripción desde el archivo temporal...")
        audio = whisperx.load_audio(temp_audio_path)
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

        # Eliminar el archivo temporal después de la transcripción
        os.remove(temp_audio_path)
        print(f"Archivo temporal eliminado: {temp_audio_path}")

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

        # Convertir el archivo a MP3 optimizado en memoria
        optimized_audio_stream = convert_to_mp3_in_memory(input_path)

        # Nombre de archivo de transcripción
        transcripcion_filename = os.path.splitext(original_filename)[0] + '.txt'
        transcripcion_path = os.path.join('transcriptions', transcripcion_filename)

        # Capturar el idioma seleccionado por el usuario
        selected_language = request.form['language']

        # Restablecer progreso
        progress = {"status": "Iniciando transcripción...", "percent": 0}

        # Procesar el audio en un hilo separado para no bloquear el servidor
        thread = threading.Thread(target=transcribir_audio, args=(optimized_audio_stream, transcripcion_path, selected_language))
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
