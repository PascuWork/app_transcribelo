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
print(f"Inicializando modelo WhisperX en {device}...")
whisperx_model = whisperx.load_model("large-v2", device, compute_type="float32")
print("Modelo WhisperX cargado exitosamente.")

# Clave API de OpenAI desde .env
openai.api_key = os.getenv('OPENAI_API_KEY')
if openai.api_key:
    print("Clave API de OpenAI cargada correctamente.")
else:
    print("Error: No se ha encontrado la clave API de OpenAI.")

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

@app.route('/', methods=['GET', 'POST'])
def upload_file():
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

        # Transcribir el audio con WhisperX
        print("Cargando audio para transcripción...")
        audio = whisperx.load_audio(output_mp3)
        print("Audio cargado exitosamente, iniciando transcripción...")
        result = whisperx_model.transcribe(audio)
        
        # Verificar si 'text' está en result
        if 'text' in result:
            transcripcion = result['text']
            print(f"Transcripción completada: {transcripcion[:100]}...")  # Mostrar solo los primeros 100 caracteres
        else:
            print(f"Error: No se encontró el campo 'text' en el resultado. Resultado: {result}")
            transcripcion = "Transcripción no disponible."

        # Guardar la transcripción en la carpeta 'transcriptions'
        transcripcion_path = os.path.join('transcriptions', 'transcripcion.txt')
        print(f"Guardando transcripción en {transcripcion_path}...")
        with open(transcripcion_path, 'w') as f:
            f.write(transcripcion)
        print("Transcripción guardada.")

        # Generar resumen con GPT usando la nueva API
        print("Generando resumen con OpenAI GPT usando la nueva API...")

        respuesta = openai.chat_completions.create(
            model="gpt-4",  # Cambia al modelo adecuado
            messages=[
                {"role": "system", "content": "Eres un asistente que crea resúmenes detallados en Markdown."},
                {"role": "user", "content": f"Resume el siguiente texto:\n{transcripcion}"}
            ]
        )

        resumen = respuesta['choices'][0]['message']['content']
        print(f"Resumen generado: {resumen[:100]}...")

        # Guardar el resumen en la carpeta 'summaries'
        resumen_path = os.path.join('summaries', 'resumen.md')
        print(f"Guardando resumen en {resumen_path}...")
        with open(resumen_path, 'w') as f:
            f.write(resumen)
        print("Resumen guardado.")

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
