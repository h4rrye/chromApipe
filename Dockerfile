FROM python:3.11-slim

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