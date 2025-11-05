FROM python:3.9-slim

WORKDIR /app

# Install system dependencies and create directories
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /opt/app/logs

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app.py .

# Set resource limits (CPU and memory constraints)
ENV PYTHONUNBUFFERED=1

EXPOSE 5000

CMD ["python", "app.py"]