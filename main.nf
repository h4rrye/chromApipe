// uncomment this following line if using older version of nextflow
// < 22.03.0-edge or 22.04.0 stable release
// nextflow.enable.dsl2

// params are the cmd line args
params.chromosomes = "1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22"
params.mapping = "${projectDir}/data/GSE105544_ENCFF010WBP_mapping.txt"
params.outdir = "results"

process fetch_pdb {
    input:
    val chr_num

    output:
    tuple val(chr_num), path("chr${chr_num}.pdb")

    script:
    """
    python ${projectDir}/bin/fetch_pdb.py --chr ${chr_num} --outdir .
    """
}

process compute_physical {
    input:
    tuple val(chr_num), path(pdb_file)

    output:
    tuple val(chr_num), path("chr${chr_num}_physical.csv"), path("chr${chr_num}_surface.csv")

    script:
    """
    python ${projectDir}/bin/compute_physical.py --pdb ${pdb_file} --chr ${chr_num} --outdir . 
    """
}

process fetch_annotations {
    input:
    val chr_num

    output:
    tuple val(chr_num), path("chr${chr_num}_annotations.csv")

    script:
    """
    python ${projectDir}/bin/fetch_annotations.py --chr ${chr_num} --mapping ${params.mapping} --outdir .
    """
}

process compile {
    publishDir params.outdir, mode: 'copy'

    input:
    tuple val(chr_num), path(physical), path(surface), path(annotations)

    output:
    path("chr${chr_num}_compiled.parquet")
    path("chr${chr_num}_surface.parquet")

    script:
    """
    python ${projectDir}/bin/compile.py --chr ${chr_num} --physical ${physical} --surface ${surface} --annotations ${annotations} --outdir .
    """
}

workflow {
    chr_list = Channel.fromList("${params.chromosomes}".tokenize(','))

    fetch_pdb(chr_list)
    compute_physical(fetch_pdb.out)

    fetch_annotations(chr_list)

    compile_input = compute_physical.out
        .join(fetch_annotations.out, by: 0)
    
    compile(compile_input)
}

