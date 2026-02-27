FROM python:3.11

# Install system dependencies including build tools for mdtraj
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    procps \
    gcc \
    g++ \
    make \
  && update-ca-certificates \
  && rm -rf /var/lib/apt/lists/*

# Install Python dependencies for chromApipe
RUN pip install --no-cache-dir \
    pandas \
    numpy \
    polars \
    pyarrow \
    scipy \
    requests \
    tqdm \
    mdtraj

WORKDIR /work
