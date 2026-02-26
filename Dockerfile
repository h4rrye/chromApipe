FROM python:3.11-slim

# System deps: CA bundle for TLS + minimal tools some libs expect
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
  && update-ca-certificates \
  && rm -rf /var/lib/apt/lists/*

# Python deps
RUN pip install --no-cache-dir \
    pandas \
    numpy \
    polars \
    pyarrow \
    mdtraj \
    scipy \
    requests \
    tqdm \
    awscli

WORKDIR /work