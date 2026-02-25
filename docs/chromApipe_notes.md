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

### NextFlow

<b> Functioning</b>

<span style='Color:red;'>Processes, Channels, Workflows</span>

Think of it as a network.

- <b>Process</b> : are the individual tasks, like every single python script is an individual task. This corresponds to nodes in the network
- <b>Channels</b>: is how data flows thorough the processes, output of one script goes into a channel which serves as input to another channel. Think of this as the edges between the nodes
- <b>Workflow</b>: think of it as wiring a network. You tell which channel will connect to which process and how these processes are linked/arranged or flow.

`val chr_num` : use this in **input** as we are declaring it as numeric

`val(chr_num)` : use this in **output** as this is referencing an exisiting variable

`--outidr .` : this does not mean that the files are saved in the same directory. As NextFlow saves files in their own subfolder eg `work/ax/dfjkfsn.../`, the `.` only tells NextFlow to pick up the same directory where you saved it.

___

> `git rm -r <file_name>` removes tracking for a file, useful when you want to delete a file from the git repo but keep it locally.

____

<b> TODO:</b>

1. Round 4 -> 8

___



## Cloud runtime

- use `SDKMAN!` that is the preferred bioinformatics way
- use `Amazon Corretto` made for aws workflows

> these 2 steps takes care of most of the workload

## STACK

- python: polars, pandas, pyarrow, requests
- NextFlow: DSL2, Docker, nextflow.config, main.nf