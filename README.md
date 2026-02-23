- - # ChromApipe

    A fully automated, containerized Nextflow pipeline that compares the physical properties of 3D chromosome organization to biological features like gene expression, chromatin openness, and GC content. Outputs analysis-ready Parquet files per chromosome for downstream exploration.

    ## About

    3D genome organization plays a crucial role in normal cell development and functioning — irregularities can cause massive downstream repercussions like developmental diseases and cancer. In the hopes of deciphering how 3D organization dictates cell functionality, this pipeline pulls genomic annotation data directly via REST API endpoints while deriving physical attributes in parallel.

    ChromApipe also implements the novel Chromosome Accessible Surface Area (CSAA) algorithm from [genBrowser](https://github.com/h4rrye/genBrowser), which constructs a surface around the chromosome to calculate open regions of the genome — a proxy for how accessible genes are to transcription factors and transcription machinery.

    ## Pipeline Architecture

    [![chromapipe_architecture](docs/img/chromapipe_architecture.png)](https://claude.ai/chat/docs/img/chromapipe_architecture.png)

    ## Data Source

    Chromosome 3D structures are sourced from the [Genome Structure Database (GSDB)](https://gsdb.mu.hekademeia.org/) using the GSE105544_ENCFF010WBP dataset. Structures were reconstructed from Hi-C data using the 3DMax algorithm at 500kb resolution for the H1-hESC cell line. Biological annotations are fetched from the [Ensembl REST API](https://rest.ensembl.org/).

    ## Output

    Each chromosome produces two Parquet files:

    **chr{N}_compiled.parquet** — one row per genomic bin (500kb), containing:
  
    - `x`, `y`, `z` — 3D bead coordinates
    - `dist_surface` — distance from chromosome surface (CSAA)
    - `dist_com` — distance from center of mass
    - `dist_rolling_mean` — distance from smoothed backbone
    - `start`, `end` — genomic coordinates
    - `gc_content` — GC fraction per bin
    - `gene_density` — number of genes per bin

    **chr{N}_surface.parquet** — 3D coordinates of the constructed chromosome surface points.

    ## Getting Started
  
    **Prerequisites:** [Nextflow](https://www.nextflow.io/) (≥ 23.04) and [Docker](https://www.docker.com/)
  
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
  
    Python, Polars, Pandas, NumPy, PyArrow, mdtraj, SciPy, Requests, Nextflow (DSL2), Docker, GSDB, Ensembl REST API
  
    ## License
  
    MIT
