from flask import Flask, request, render_template, send_file
import whisperx
import openai
import subprocess
from dotenv import load_dotenv
import os

# Cargar variables de entorno desde .env
load_dotenv()

app = Flask(__name__)

# Configuración de WhisperX
device = "cpu"  # Cambia a "cuda" si tienes GPU
whisperx_model = whisperx.load_model("large-v2", device, compute_type="float32")


# Clave API de OpenAI desde .env
openai.api_key = os.getenv('OPENAI_API_KEY')

# Función para convertir archivos de audio a MP3 si es necesario
def convert_to_mp3(input_file, output_file):
    # Cambia esta ruta por la ruta completa donde tienes instalado FFmpeg
    ffmpeg_path = r'P:\ffmpeg\bin\ffmpeg.exe'  # Ruta completa al ejecutable de FFmpeg
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
