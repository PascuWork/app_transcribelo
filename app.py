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
