// Import sub-workflows
include { make_windows_workflow } from './workflows/make_windows.nf'
include { split_chroms_workflow } from './workflows/split_chroms.nf'
include { split_mask_workflow } from './workflows/split_mask.nf'
include { relernn_workflow } from './workflows/relernn.nf'

// Main workflow
workflow {
    // Read in genome bed file
    bedChannel = Channel.fromPath(params.genome_bed)

    // Make windows of size #params.window_size along chromosomes 
    make_windows_workflow(bedChannel)

    // Break up VCFs according to windows
    // filter for it[0] in params.chrom_list
    windowChannel = make_windows_workflow.out
        .splitCsv(header: false, sep: '\t')
        .map{tuple(it[0], it[1], it[2]) }
        .filter{it[0] in params.chrom_list}
        
    vcfChannel = Channel.fromPath(params.vcf).combine(windowChannel)
    
    split_chroms_workflow(vcfChannel)
    
    // Split mask into windows
    maskChannel = Channel.fromPath(params.mask).combine(windowChannel)
    split_mask_workflow(maskChannel)
    

    // Create pairs of windows and VCF path names 
    window_vcf = split_chroms_workflow.out
        .map{ file -> 
            def id = (file.name =~ /window_(\w+).vcf/)[0][1]
            return tuple(id, file)
        }
    
    // Create pairs of windows and mask path names
    window_mask = split_mask_workflow.out 
        .map{ file -> 
            def id = (file.name =~ /mask_(\w+).bed/)[0][1] 
            return tuple(id, file)
        }

    // Combine VCF and mask channels
    relernn_simulateChannel = window_vcf
        .join(window_mask)
        .map{ tuple -> 
            return tuple.flatten()
         }  

    relernn_simDirChannel = split_chroms_workflow.out
        .map{ file -> 
            def id = (file.name =~ /window_(\w+).vcf/)[0][1]
            return tuple(id, "${params.outdir}out_${id}")
        }

    // ReLERNN!! 
    relernn_workflow(relernn_simulateChannel)
}
