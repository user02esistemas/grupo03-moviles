FROM python:3.12-slim

# Evita .pyc y fuerza logs sin buffer (utiles en contenedor).
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /code

# Dependencias del sistema minimas (compilar algunas ruedas si hiciera falta).
RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential \
    && rm -rf /var/lib/apt/lists/*

# Instalar dependencias primero para aprovechar la cache de capas.
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

# Codigo de la aplicacion.
COPY ./app ./app

EXPOSE 8000

# En desarrollo, docker-compose sobreescribe este comando para activar --reload.
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
