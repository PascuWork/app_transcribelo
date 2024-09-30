from flask import Flask, request, render_template, send_file
import whisper
import openai
from dotenv import load_dotenv
import os

# Cargar variables de entorno desde .env
load_dotenv()

app = Flask(__name__)
model = whisper.load_model("base")

# Clave API de OpenAI desde .env
openai.api_key = os.getenv('OPENAI_API_KEY')

@app.route('/', methods=['GET', 'POST'])
def upload_file():
    if request.method == 'POST':
        # Guardar el archivo subido
        audio_file = request.files['file']
        audio_file.save('audio.mp3')

        # Transcribir el audio con Whisper
        result = model.transcribe('audio.mp3')
        transcripcion = result['text']

        # Guardar la transcripción en un archivo .txt
        with open('transcripcion.txt', 'w') as f:
            f.write(transcripcion)

        # Generar resumen con GPT
        respuesta = openai.ChatCompletion.create(
            model="gpt-3.5-turbo",
            messages=[
                {"role": "system", "content": "Eres un asistente que crea resúmenes detallados en Markdown."},
                {"role": "user", "content": f"Resume el siguiente texto:\n{transcripcion}"}
            ]
        )
        resumen = respuesta['choices'][0]['message']['content']

        # Guardar el resumen en un archivo .md
        with open('resumen.md', 'w') as f:
            f.write(resumen)

        return render_template('download.html')

    return render_template('upload.html')

@app.route('/download/<filename>')
def download_file(filename):
    if filename == 'transcripcion':
        return send_file('transcripcion.txt', as_attachment=True)
    elif filename == 'resumen':
        return send_file('resumen.md', as_attachment=True)
    else:
        return 'Archivo no encontrado', 404

if __name__ == '__main__':
    app.run(debug=True)
