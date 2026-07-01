FROM python:3.12-slim

# System deps for psycopg2 / bcrypt build (kept minimal)
RUN apt-get update && apt-get install -y --no-install-recommends \
        gcc libpq-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Python deps first for better layer caching
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the app
COPY . .

EXPOSE 8000

# server.py runs uvicorn on 0.0.0.0:8000 in its __main__ block
CMD ["python", "server.py"]
