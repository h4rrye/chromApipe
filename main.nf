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
    path script

    output:
    tuple val(chr_num), path("chr${chr_num}.pdb")

    script:
    """
    python3 ${script} --chr ${chr_num} --outdir .
    """
}

process compute_physical {
    input:
    tuple val(chr_num), path(pdb_file)
    path script

    output:
    tuple val(chr_num), path("chr${chr_num}_physical.csv"), path("chr${chr_num}_surface.csv")

    script:
    """
    python3 ${script} --pdb ${pdb_file} --chr ${chr_num} --outdir . 
    """
}

process fetch_annotations {
    input:
    val chr_num
    path script
    path mapping

    output:
    tuple val(chr_num), path("chr${chr_num}_annotations.csv")

    script:
    """
    export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
    export REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
    python3 ${script} --chr ${chr_num} --mapping ${mapping} --outdir .
    """
}

process compile {
    publishDir params.outdir, mode: 'copy'

    input:
    tuple val(chr_num), path(physical), path(surface), path(annotations)
    path script

    output:
    path("chr${chr_num}_compiled.parquet")
    path("chr${chr_num}_surface.parquet")

    script:
    """
    python3 ${script} --chr ${chr_num} --physical ${physical} --surface ${surface} --annotations ${annotations} --outdir .
    """
}

workflow {
    chr_list = Channel.fromList("${params.chromosomes}".tokenize(','))
    
    // Create channels for scripts
    fetch_pdb_script = file("${projectDir}/bin/fetch_pdb.py")
    compute_physical_script = file("${projectDir}/bin/compute_physical.py")
    fetch_annotations_script = file("${projectDir}/bin/fetch_annotations.py")
    compile_script = file("${projectDir}/bin/compile.py")
    mapping_file = file(params.mapping)

    fetch_pdb(chr_list, fetch_pdb_script)
    compute_physical(fetch_pdb.out, compute_physical_script)

    fetch_annotations(chr_list, fetch_annotations_script, mapping_file)

    compile_input = compute_physical.out
        .join(fetch_annotations.out, by: 0)
    
    compile(compile_input, compile_script)
}

