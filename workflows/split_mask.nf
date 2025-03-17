process split_mask {
    memory '48GB'

    publishDir "${params.outdir}", mode: 'symlink'

    input:
        tuple path(mask_bed), val(chrom), val(start), val(end)
    
    output:
        tuple path("out_${chrom}_${start}_${end}/mask_${chrom}_${start}_${end}.bed"), path("out_${chrom}_${start}_${end}/${chrom}_${start}_${end}.genome.bed")

    script:
        def dirname = "out_${chrom}_${start}_${end}"
        def region = "${chrom}_${start}_${end}"
        """
        eval "\$(conda shell.bash hook)"
        conda activate etc
        mkdir -p ${dirname}
        echo -e "${chrom}\t${start}\t${end}" > ${dirname}/${region}.genome.bed
        bedtools intersect -a ${dirname}/${region}.genome.bed -b $mask_bed | sort -T . -k1,1 -k2,2n -k3,3n > ${dirname}/mask_${region}.bed
        echo "done"
        """
}

workflow split_mask_workflow {
    take:
        maskChannel
    main:
        split_mask(maskChannel)
    emit:
        split_mask.out
}