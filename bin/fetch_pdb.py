import argparse
import urllib.request
import os

# either download or use the local PDB file
parser = argparse.ArgumentParser()
parser.add_argument("--chr", required=True, help="Chromosome number (1-22)")
parser.add_argument("--local-pdb", default=None, help="Path to local PDB file (skips download)")
parser.add_argument("--outdir", default=".", help="Output directory")
args = parser.parse_args()


# if using local PDB, it copies the files to the required dir
# otherwise it donwloads the respective PDB files from github releases
os.makedirs(args.outdir, exist_ok=True)
output_path = os.path.join(args.outdir, f"chr{args.chr}.pdb")

if args.local_pdb:
    import shutil
    shutil.copy(args.local_pdb, output_path)
    print(f"Copied local PDB to {output_path}")
else:
    url = f"https://github.com/h4rrye/chromApipe/releases/download/v.0.1-data/chr{args.chr}.pdb"
    urllib.request.urlretrieve(url, output_path)
    print(f"Downloaded chr{args.chr}.pdb to {output_path}")

