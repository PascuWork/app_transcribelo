from flask import Flask, request, render_template, send_file
import whisperx
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
        
        # Verificar si 'segments' está en result
        if 'segments' in result:
            print("Transcripción completada. Procesando segmentos...")
            # Concatenar los textos de cada segmento
            transcripcion = " ".join([segment['text'] for segment in result['segments']])
            print(f"Transcripción: {transcripcion[:100]}...")  # Mostrar los primeros 100 caracteres para depuración
        else:
            print(f"Error: No se encontró el campo 'segments' en el resultado. Resultado: {result}")
            transcripcion = "Transcripción no disponible."

        # Guardar la transcripción con el mismo nombre del archivo de audio pero con extensión .txt
        transcripcion_filename = os.path.splitext(original_filename)[0] + '.txt'
        transcripcion_path = os.path.join('transcriptions', transcripcion_filename)
        print(f"Guardando transcripción en {transcripcion_path}...")
        with open(transcripcion_path, 'w') as f:
            f.write(transcripcion)
        print("Transcripción guardada.")

        # Comentar el bloque de generación de resumen con GPT
        """
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
        """

        return send_file(transcripcion_path, as_attachment=True)

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
