# relernn_nextflow

Nextflow pipeline to run ReLERNN


## Installation

The pipeline requires using conda/mamba. 
To make installation fast and to avoid conflicts among libraries,
we create three different environments: one for Nextflow (optional if another install is already available)

```bash
mamba env create -f envs/nextflow.yml
```

one for ReLERNN

```bash
mamba env create -f envs/relernn.yml
```

and one for extra goodies used in in the pipeline

```bash
mamba env create -f envs/etc.yml
```

## Usage

Usage requires a few inputs that are specified in a config. An example is given at `relernn_config.yaml`.
We encrouage you to use full paths to the inputs so that the pipeline can be run from any directory, but relative paths should work if you run the command below from the repository root.

The pipeline has only been tested on a cluster, so the profile `cluster` is used. Like the above configuration, 
edits should be made to the name of the gpu queue.
The the other parameters (hopefully) can be left as is.
The pool seq mode is not yet implemented, but hopefully will be soon.

Once configs are edits, running the pipeline is as simple as:

```bash
conda activate nextflow
nextflow run main.nf -params-file relernn_config.yaml -profile cluster -with-conda
```

If the pipeline fails for unforeseen reasons (system crash),
you can add `-resume` to the above command to pick up where things left off.

