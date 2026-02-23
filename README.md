- # ChromApipe

  There is no doubt that 3D genome organization plays a crucial role in normal cell development and functioning. Any irregularities can cause massive downstream repercussions like developmental diseases and even cancer. In the hopes of deciphering how 3D organization dictates cell functionality, I created a pipeline that compares the physical properties of chromosome organization to its biological features like expression, openness, and bound proteins.

  This pipeline also implements a novel Chromosome Accessible Surface Area algorithm ([genBrowser](https://github.com/h4rrye/genBrowser)) which creates a surface around the chromosome to calculate the open regions of the genome — another proxy for how easily accessible genes are to various transcription factors and transcription machinery.

  ChromApipe is a fully automated, containerized Nextflow pipeline that pulls genomic annotation data directly via REST API endpoints while deriving physical attributes in parallel. The final output is two parquet files per chromosome: one containing the surface points and another with all physical attributes and biological features merged for downstream analysis.

  ## Pipeline Architecture

  <!-- Add your HTML diagram here -->

  <image-card alt="ChromApipe Architecture" src="./docs/img/chromapipe_architecture.svg" ></image-card>

  ## Data Source

  Chromosome 3D structures are sourced from the [Genome Structure Database (GSDB)](https://gsdb.mu.hekademeia.org/) using the GSE105544_ENCFF010WBP dataset. Structures were reconstructed from Hi-C data using the 3DMax algorithm at 500kb resolution for the H1-hESC cell line. Biological annotations are fetched from the [Ensembl REST API](https://rest.ensembl.org/).

  ## Output

  Each chromosome produces two parquet files:

  **chr{N}_compiled.parquet** — one row per genomic bin (500kb), containing:
  
  - `x`, `y`, `z` — 3D bead coordinates
  - `dist_surface` — distance from chromosome surface (CSAA)
  - `dist_com` — distance from center of mass
  - `dist_rolling_mean` — distance from smoothed backbone
  - `start`, `end` — genomic coordinates
  - `gc_content` — GC fraction per bin
  - `gene_density` — number of genes per bin

  **chr{N}_surface.parquet** — 3D coordinates of the constructed chromosome surface points.

  ## Usage
  
  ```bash
  # Run on all 22 autosomes
  nextflow run main.nf
  
  # Run on specific chromosomes
  nextflow run main.nf --chromosomes 1,2,3
  
  # Use a local PDB file
  nextflow run main.nf --chromosomes 1 --local_pdb /path/to/chr1.pdb
  
  # Resume a failed or partial run
  nextflow run main.nf -resume
  ```

  ## Future Scope
  
  - Gene expression integration (H1-hESC RNA-seq from ENCODE)
  - Histone modification and replication timing annotations
  - Network analysis using NetworkX for chromatin interaction topology
  - Deployment on AWS Batch for scalable cloud execution
  - nf-core compatibility for community contribution

  ## Stack
  
  - **Python**: polars, pandas, numpy, pyarrow, mdtraj, scipy, requests
  - **Nextflow**: DSL2, channel-based parallelism
  - **Docker**: containerized execution
  - **Data sources**: GSDB (3DMax, 500kb), Ensembl REST API
