//Simulate data
process relernn_simulate {
    cache 'lenient'

    time '72h'
    memory '24GB'
    cpus "${params.threads}"
    
    input:
        tuple val(region), path(vcf), path(mask_bed), path(genome_bed)
    output:
        path("simulate-${region}.finished.txt"), emit: simulations
    script:
        """
        eval "\$(conda shell.bash hook)"
        conda activate relernn
        mkdir -p sim_${region}
        ReLERNN_SIMULATE \
            --vcf ${vcf} \
            --genome ${genome_bed} \
            --projectDir sim_${region} \
            --assumedMu ${params.mutation_rate} \
            --upperRhoThetaRatio ${params.URTR} \
            -t ${params.threads} \
            -l 1 \
            --mask ${mask_bed}

        touch simulate-${region}.finished.txt
        """
}
    
process relernn_train {
    cache 'lenient'
    
    queue "${params.gpu_queue}"
    clusterOptions = " --gres=gpu:1"
    time '48h'
    memory '48GB'

    input:
        tuple val(region), path(simdir)
    output:
        path("train-${region}.finished.txt") , emit: training
    script:
        """
        eval "\$(conda shell.bash hook)"
        conda activate relernn
        ReLERNN_TRAIN \
            --projectDir ${simdir}/ \
            --gpuID 0

        touch "train-${region}.finished.txt"
        """
}
    

process relernn_predict {
    
    cache 'lenient'

    queue "${params.gpu_queue}"
    clusterOptions = " --gres=gpu:1"
    time '48h'
    memory '12GB'

    input:
        tuple val(region), path(vcf), path(traindir) 
    output:
        path("predict-${region}.finished.txt") , emit: prediction
    script:
        """
        eval "\$(conda shell.bash hook)"
        conda activate relernn
        ReLERNN_PREDICT \
            --vcf ${vcf} \
            --projectDir ${traindir} \
            --gpuID 0
  
        touch "predict-${region}.finished.txt"
        """
}


process relernn_bscorrect {
    cache 'lenient'
    publishDir "${params.outdir}", mode: 'symlink'

    queue "${params.gpu_queue}"
    clusterOptions = " --gres=gpu:1"
    time '96h'
    memory '48GB'

    input:
        tuple val(region), path(preddir)
    output:
        path("bscorrect-${region}.finished.txt") , emit: bscorrect
    script:
        """
        eval "\$(conda shell.bash hook)"
        conda activate relernn
        ReLERNN_BSCORRECT \
            --projectDir ${preddir} \
            --gpuID 0

        touch "bscorrect-${region}.finished.txt"
        mkdir -p ${params.outdir}/sim_${region}
        cp -r ${preddir}/* ${params.outdir}/sim_${region}/
        """
}

process relernn_merge_bs {
    publishDir "${params.outdir}", mode: 'copy'

    input:
        path(bs_finished_files) 
        path(bs_files)
    output:
        path("allwindows.PREDICT.BSCORRECTED.txt") , emit: all_bs_files
    script:
        """
        cat <(cat ${bs_files} | grep chrom | uniq) <(cat ${bs_files} | grep -v chrom | sort -k1,1 -k2,2n -k3,3) > allwindows.PREDICT.BSCORRECTED.txt
        """
}


workflow relernn_workflow {
    take:
        relernn_simulateChannel

    main:
        // Run simulation
        simulated = relernn_simulate(relernn_simulateChannel)

        //get the working path and concat to simpath
        simDirChannel = simulated.map { pathname -> ["${pathname.getName().split('-')[1].split('\\.')[0]}", "${pathname.getParent()}/sim_${pathname.getName().split('-')[1].split('\\.')[0]}"] }
        // Train model

        trained = relernn_train(simDirChannel)
        
        // Extract VCF and dir from channels

        // get first and second elements of tuple
        vcfChannel = relernn_simulateChannel.map { tuple -> [tuple[0], tuple[1]]}
        
        trainedChannel = trained.map { pathname -> ["${pathname.getName().split('-')[1].split('\\.')[0]}", "${pathname.getParent()}/sim_${pathname.getName().split('-')[1].split('\\.')[0]}"] }

        predictChannel = vcfChannel.join(trainedChannel).map { tuple -> tuple.flatten() }

        predicted = relernn_predict(predictChannel)
        predictedDirChannel = predicted.map { pathname -> ["${pathname.getName().split('-')[1].split('\\.')[0]}", "${pathname.getParent()}/sim_${pathname.getName().split('-')[1].split('\\.')[0]}"] }
        bscorrected = relernn_bscorrect(predictedDirChannel)
        

        bs_files = predictedDirChannel
        .map { id, path -> 
        // Construct the file path using both elements of the tuple
        def filePath = "${path}/window_${id}.PREDICT.BSCORRECTED.txt"
        return file(filePath)
        }.collect()
        
        all_bs_files = relernn_merge_bs(bscorrected, bs_files)

    emit:
        all_bs_files
}