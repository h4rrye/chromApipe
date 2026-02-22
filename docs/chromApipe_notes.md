# chromApipe

enviroment name: `chromapipe`

> using `bin/` for storing the python files as Nextflow automatically adds bin/ to PATH, so we can call the python script directly. With `src/` we need to mannually set up the path to the script.

### PDB Source

**Genome Structure Database (GSDB)**

GSE105544_ENCFF010WBP, 500kb resolution, **3DMax** consistently shows the highest dSCC scores, outperforming LorGD.

> I used `LorGD` for `genBrowser`

I saved the PDB files as github release assets do they dont live in the repo and take up space. This data can be directly accessed via the download url.

____

use this to view parquet files in the terminal

`parquet-tools show data/chr21_compiled.parquet --head 5`

____

> we are not organizing the files in the `data/` directory as these files are only there to test out the python scripts. Once we run the NextFlow pipeline, it takes care of its own files, hence it will be good idea to even add the data/ to `.gitignore`.

___

## STACK

python, polars, pandas, pyarrow, requests