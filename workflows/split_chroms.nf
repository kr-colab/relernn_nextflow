def vcfPath = file(params.vcf).parent

process split_chroms{
    publishDir vcfPath, mode: 'symlink'
    
    input:
        tuple path(vcf), val(chrom), val(start), val(end)
    output:
        path "window_${chrom}_${start}_${end}.vcf", emit: out

    script:
    """
    eval "\$(conda shell.bash hook)"
    conda activate etc

    tabix ${vcf}
    bcftools view --max-alleles 2 -r "${chrom}:${start}-${end}" ${vcf} > window_${chrom}_${start}_${end}.vcf
    """
}

workflow split_chroms_workflow {
    take:
        vcfChannel
    main:
        split_chroms(vcfChannel)
    emit:
        split_chroms.out
}
