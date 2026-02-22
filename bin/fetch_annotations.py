"""
This script fetches the genome annotations via REST API
from ESEMBL, then maps it to the 3D structure. There are more
additions coming to this script and can fetch magnitude of 
biological data for the corresponding chromosome.
"""

import argparse
import requests
import pandas as pd
import time
import os

#--------- user picked arguments & saving mapping file ------------
parser = argparse.ArgumentParser()
parser.add_argument(
    "--chr", 
    required=True, 
    help="Chromosome number (1-22)"
)
parser.add_argument(
    "--mapping", 
    required=True, 
    help="Path to GSDB mapping file"
)
parser.add_argument(
    "--outdir", 
    default=".", 
    help="Output directory"
)
args = parser.parse_args()


#------------- loading mapping file for filering out data -----------
os.makedirs(args.outdir, exist_ok=True)
mapping = pd.read_csv(
    args.mapping, 
    sep=r'\s+', 
    header=None, 
    names=["bead", "chr", "start", "end"]
)
mapping = mapping[mapping["chr"] == int(args.chr)]


#---------------------- fetch GC Content ----------------
ENSEMBL = "https://rest.ensembl.org"

def get_gc_content(chr_num, start, end):
    url = f"{ENSEMBL}/sequence/region/human/{chr_num}:{start}:{end}?content-type=application/json"
    r = requests.get(url)
    if r.status_code == 200:
        seq = r.json()["seq"].upper()
        gc = (seq.count("G") + seq.count("C")) / len(seq)
        return round(gc, 4)
    return None


#------------- calculate bin wise [500kb] gene density -----------------
def get_gene_density(chr_num, start, end):
    url = f"{ENSEMBL}/overlap/region/human/{chr_num}:{start}:{end}?feature=gene;content-type=application/json"
    r = requests.get(url)
    if r.status_code == 200:
        genes = r.json()
        return len(genes)
    return None


#----------- calculate GC content & gene density by calling the above functions ----------------
gc_values = []
gene_counts = []

for _, row in mapping.iterrows():
    gc = get_gc_content(args.chr, row["start"], row["end"])
    genes = get_gene_density(args.chr, row["start"], row["end"])
    gc_values.append(gc)
    gene_counts.append(genes)
    time.sleep(0.1)                 #---- increase this waittime incase of error `429`: too many requests. ENSEMBL allows for 15 requests per second.


#----------------- saving the results ---------------
annotations = pd.DataFrame({
    "bead": mapping["bead"].values,
    "chr": mapping["chr"].values,
    "start": mapping["start"].values,
    "end": mapping["end"].values,
    "gc_content": gc_values,
    "gene_density": gene_counts
})

annotations.to_csv(
    os.path.join(
        args.outdir, 
        f"chr{args.chr}_annotations.csv"
    ), 
    index=False
)
print(f"Saved chr{args.chr}_annotations.csv ({len(annotations)} bins)")

