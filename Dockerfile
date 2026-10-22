FROM python:3.13-slim

WORKDIR /app

# Install system dependencies if required for C-extensions/networking
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install python dependencies for ingestion (including psycopg for PostgreSQL)
RUN pip install --no-cache-dir \
    pandas==3.0.6 \
    pyarrow==25.0.1 \
    sqlalchemy==2.1.3 \
    psycopg[binary]==3.3.6

# Copy application ingestion script
COPY ingest.py .

ENTRYPOINT ["python", "ingest.py"]
