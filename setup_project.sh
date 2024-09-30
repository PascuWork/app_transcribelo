#!/bin/bash
# Configuración del entorno para el proyecto

# Crear un entorno virtual
python -m venv venv

# Activar el entorno virtual
source venv/Scripts/activate

# Instalar las dependencias necesarias
pip install -r requirements.txt

# Crear la estructura de directorios
mkdir templates
mkdir static

# Crear archivo app.py con el contenido básico de la aplicación
cat <<EOL > app.py
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
EOL

# Crear archivo upload.html en la carpeta templates
cat <<EOL > templates/upload.html
<!doctype html>
<html>
<head>
    <title>Subir Archivo</title>
</head>
<body>
    <h1>Sube tu archivo .mp3</h1>
    <form method="post" enctype="multipart/form-data">
        <input type="file" name="file" accept=".mp3" required>
        <button type="submit">Subir</button>
    </form>
</body>
</html>
EOL

# Crear archivo download.html en la carpeta templates
cat <<EOL > templates/download.html
<!doctype html>
<html>
<head>
    <title>Descargar Resultados</title>
</head>
<body>
    <h1>Procesamiento Completo</h1>
    <!-- Colocar aquí el código de publicidad si es necesario -->
    <p>Tu archivo ha sido procesado. Puedes descargar los resultados a continuación:</p>
    <a href="/download/transcripcion">Descargar Transcripción (.txt)</a><br>
    <a href="/download/resumen">Descargar Resumen (.md)</a>
</body>
</html>
EOL

echo "Configuración completada exitosamente."
