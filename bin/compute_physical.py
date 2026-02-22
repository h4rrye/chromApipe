"""
this script computes physical attribtues & network
properties of the physical 3D model of the chromosome
taking the respective PDB file as input. There are 
more additions coming to this script where we will use
networkx to process this structrure as a connected
graph and study various network properties.
"""

import argparse
import mdtraj as md
import numpy as np
import scipy.ndimage as nd
import math
import pandas as pd
from tqdm import tqdm
import os

parser = argparse.ArgumentParser()
parser.add_argument("--pdb", required=True, help="Path to PDB file")
parser.add_argument("--chr", required=True, help="Chromosome number")
parser.add_argument("--outdir", default=".", help="Output directory")
args = parser.parse_args()

os.makedirs(args.outdir, exist_ok=True)
chr_str = md.load_pdb(args.pdb)
coords = chr_str.xyz.reshape(-1, 3)



# --------------- Center Of Mass -----------------
com = md.compute_center_of_mass(chr_str)

chr_com = []
for coord in coords:
    dist = np.min(np.linalg.norm(com - coord, axis=1))
    chr_com.append(dist)

chr_com = np.array(chr_com)



# ------------- Rolling Mean Spleen --------------
window_size = 50
smooth = []
for i in range(0, len(coords) - window_size, 1):
    smooth.append(np.mean(coords[i:i + window_size], axis=0))

smooth = np.array(smooth)

dist_rm = []
for coord in coords:
    dist = np.min(np.linalg.norm(coord - smooth, axis=1))
    dist_rm.append(dist)

dist_rm = np.array(dist_rm)



# --------------------- Chromosome Surface Accessible Area -----------
# creating spheres
dists = [math.dist(coords[i], coords[i+1]) for i in range(len(coords) - 1)]
r = 1.45 * max(dists)
d = 15

all_spheres = np.empty((3, 0))
for coord in tqdm(coords, desc="Building surface"):
    rad = np.linspace(0, r, int(d/2))
    phi = np.linspace(0, np.pi, d)
    theta = np.linspace(0, 2*np.pi, d, endpoint=False)
    theta, phi, rad = np.meshgrid(theta, phi, rad, indexing='ij')

    dx = rad.flatten() * np.sin(phi.flatten()) * np.cos(theta.flatten()) + coord[0]
    dy = rad.flatten() * np.sin(phi.flatten()) * np.sin(theta.flatten()) + coord[1]
    dz = rad.flatten() * np.cos(phi.flatten()) + coord[2]

    all_spheres = np.hstack([all_spheres, np.array([dx, dy, dz])])

all_spheres = all_spheres.T


# extract surface bins
scaling_factor = abs(np.min(all_spheres)) * 1.25
all_spheres += scaling_factor
coords_scaled = coords + scaling_factor

edge_size = max(
    all_spheres[:, 0].max() - all_spheres[:, 0].min(),
    all_spheres[:, 1].max() - all_spheres[:, 1].min(),
    all_spheres[:, 2].max() - all_spheres[:, 2].min()
)
edge_size += edge_size * 0.1
b = 50
bin_size = edge_size / b

box = np.zeros((b, b, b), dtype='float')
for row in all_spheres:
    xi, yi, zi = int(row[0] // bin_size), int(row[1] // bin_size), int(row[2] // bin_size)
    if (0 <= xi < b) and (0 <= yi < b) and (0 <= zi < b):
        box[xi, yi, zi] = 1

kernel = np.ones((3, 3, 3), dtype='int')
kernel[1, 1, 1] = 0
neighbour_count = nd.convolve(box, kernel, mode='constant', cval=0)

surface_bins = (box == 1) & (neighbour_count < 26)
surface_coords = np.argwhere(surface_bins) * bin_size - scaling_factor


# calculating distances and saving files
dist_surf = []
for coord in coords:
    dist = np.min(np.linalg.norm(surface_coords - coord, axis=1))
    dist_surf.append(dist)

dist_surf = np.array(dist_surf)

physical_df = pd.DataFrame({
    "x": coords[:, 0],
    "y": coords[:, 1],
    "z": coords[:, 2],
    "dist_surface": dist_surf,
    "dist_com": chr_com,
    "dist_rolling_mean": dist_rm
})

surface_df = pd.DataFrame(surface_coords, columns=["x", "y", "z"])

physical_df.to_csv(os.path.join(args.outdir, f"chr{args.chr}_physical.csv"), index=False)
surface_df.to_csv(os.path.join(args.outdir, f"chr{args.chr}_surface.csv"), index=False)

print(f"Saved chr{args.chr}_physical.csv ({len(physical_df)} beads)")
print(f"Saved chr{args.chr}_surface.csv ({len(surface_df)} surface points)")
