process DRAGEN_DEMULTIPLEXER {
    tag {"$meta.lane" ? "$meta.id"+"."+"$meta.lane" : "$meta.id" }
    label 'process_high'
    queue 'dragen'
    debug true

    input:
    tuple val(meta), path(samplesheet), path(run_dir)

    output:
    tuple val(meta), path("**_S[1-9]*_R?_00?.fastq.gz")          , emit: fastq
    tuple val(meta), path("**_S[1-9]*_I?_00?.fastq.gz")          , optional:true, emit: fastq_idx
    tuple val(meta), path("**Undetermined_S0*_R?_00?.fastq.gz")  , optional:true, emit: undetermined
    tuple val(meta), path("**Undetermined_S0*_I?_00?.fastq.gz")  , optional:true, emit: undetermined_idx
    tuple val(meta), path("Reports")                             , emit: reports
    tuple val(meta), path("Stats")                               , emit: stats
    tuple val(meta), path("InterOp/*.bin")                       , emit: interop
    path("versions.yml")                                         , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error "BCL2FASTQ module does not support Conda. Please use Docker / Singularity / Podman instead."
    }
    def args = task.ext.args ?: ''
    def args2 = task.ext.args2 ?: ''
    def args3 = task.ext.args3 ?: ''
    def input_tar = run_dir.toString().endsWith(".tar.gz") ? true : false
    def input_dir = input_tar ? run_dir.toString() - '.tar.gz' : run_dir

    """
    if [ ! -d ${input_dir} ]; then
        mkdir -p ${input_dir}
    fi

    dragen_input_directory=\$(echo ${run_dir} | sed 's/\\/data\\/medper\\/LAB/\\/mnt\\/SequencerOutput/')

    /opt/edico/bin/dragen --bcl-conversion-only=true --no-lane-splitting true --output-legacy-stats true \
        --bcl-input-directory \$dragen_input_directory \
        --intermediate-results-dir /staging/LAB/tmp/ \
        --output-directory ./ --force \
        --sample-sheet $samplesheet

    cp -r ${run_dir}/InterOp .

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        dragen: \$(echo \$(/opt/edico/bin/dragen --version 2>&1) | sed -e "s/dragen Version //g")
    END_VERSIONS
    """
}
