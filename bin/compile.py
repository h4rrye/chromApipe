""" 
takes the outputs from the annotation & physical
scripts and merges them into one parquet per chromosome
"""
import argparse
import polars as pl
import os

parser = argparse.ArgumentParser()
parser.add_argument(
    "--chr", 
    required=True, 
    help="Chromosome number"
)
parser.add_argument(
    "--physical", 
    required=True, 
    help="Path to physical features CSV"
)
parser.add_argument(
    "--surface", 
    required=True, 
    help="Path to surface points CSV"
)
parser.add_argument(
    "--annotations", 
    required=True, 
    help="Path to annotations CSV"
)
parser.add_argument(
    "--outdir", 
    default=".", 
    help="Output directory"
)
args = parser.parse_args()


#----------- read the files ----------
os.makedirs(args.outdir, exist_ok=True)

physical = pl.read_csv(
    args.physical, 
    schema={
        "x": pl.Float64, 
        "y": pl.Float64, 
        "z": pl.Float64,
        "dist_surface": pl.Float64, 
        "dist_com": pl.Float64, 
        "dist_rolling_mean": pl.Float64
    }
)

annotations = pl.read_csv(
    args.annotations, 
    schema={
        "bead": pl.Int64,
        "chr": pl.Int64, 
        "start": pl.Int64, 
        "end": pl.Int64,
        "gc_content": pl.Float64, 
        "gene_density": pl.Float64
    }
)

surface = pl.read_csv(
    args.surface, 
    schema={
        "x": pl.Float64, 
        "y": pl.Float64, 
        "z": pl.Float64
    }
)


#------ mergeing the files---------------
# using one-to-one mapping as the beads align
merged = pl.concat(
    [physical, annotations.drop(["bead", "chr"])], 
    how="horizontal"
)
merged = merged.with_columns(pl.lit(int(args.chr)).alias("chr"))
merged = merged.cast({col: pl.Float32 for col in merged.columns if col != "chr"})


#--------- merge, round & save -------------
merged = pl.concat([physical, annotations.drop(["bead", "chr"])], how="horizontal")
merged = merged.with_columns(pl.lit(int(args.chr)).alias("chr"))
merged = merged.with_columns(pl.col(pl.Float64).round(4))

merged.write_parquet(os.path.join(args.outdir, f"chr{args.chr}_compiled.parquet"))
surface.write_parquet(os.path.join(args.outdir, f"chr{args.chr}_surface.parquet"))

print(f"Saved chr{args.chr}_compiled.parquet ({merged.shape[0]} beads, {merged.shape[1]} columns)")
print(f"Saved chr{args.chr}_surface.parquet ({surface.shape[0]} surface points)")
