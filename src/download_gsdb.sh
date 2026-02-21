#!/bin/bash

OUTDIR="gsdb_3dmax_pdbs"
BASE="https://calla.rnet.missouri.edu/genome3d/GSDB/Database/AX9716PF/GSE105544_ENCFF010WBP/VC/3DMax"
mkdir -p "$OUTDIR"

for i in $(seq 1 22); do
  echo "Downloading chr${i}.pdb..."
  curl -L -o "$OUTDIR/chr${i}.pdb" "$BASE/chr${i}.pdb"
done

echo "Done. Files in $OUTDIR/"
