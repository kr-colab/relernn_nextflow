def genomePath = file(params.genome_bed).parent

process make_windows {
    publishDir genomePath, mode: 'copy'

    input:
        path bedfile
    output:
        path "windows_${params.window_size}.bed"
    script:
        """
        eval "\$(conda shell.bash hook)"
        conda activate etc

        bedtools makewindows -b ${bedfile} -w ${params.window_size} > windows_${params.window_size}.bed
        """
}

workflow make_windows_workflow {
    take:
        bedChannel
    main:
        make_windows(bedChannel)
    emit:
        make_windows.out
}