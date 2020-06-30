# ************************************
# * Snakefile for metaphlan pipeline *
# ************************************

# **** Variables ****

configfile: "config.yaml"

# **** Imports ****

import pandas as pd
SAMPLES = pd.read_csv(config["list_files"], header = None)
SAMPLES = SAMPLES[0].tolist()

# **** Rules ****

rule all:
    input:
        "output/merged_abundance_table.txt",
        "output/abundance_heatmap_species.png"

rule merge_reads:
    input:
        r1 = config["path"]+"{sample}"+config["for"],
        r2 = config["path"]+"{sample}"+config["rev"]
    output:
        "data/merged/{sample}.fastq"
    shell:
        "cat {input.r1} {input.r2} > {output.m}"

rule metaphlan2:
    input:
        "data/merged/{sample}.fastq" if config["paired"] else config["path"]+"{sample}"+config["suff"]
    output:
        bt = "output/metaphlan2/{sample}_bowtie2.bz2",
        pr = "output/metaphlan2/{sample}_profile.txt"
    params:
        db = "output/metaphlan2/{sample}_database"
    conda: "utils/envs/metaphlan3_env.yaml"
    shell:
            "metaphlan {input} --input_type fastq "
            "--bowtie2out {output.bt} --nproc 4 -o {output.pr}"

rule mergeprofiles:
    input: expand("output/metaphlan2/{sample}_profile.txt", sample=SAMPLES)
    output: "output/merged_abundance_table.txt"
    conda: "utils/envs/metaphlan2_env.yaml"
    shell: "merge_metaphlan_tables.py output/metaphlan2/*_profile.txt > {output}"

rule heatmap:
    input: "output/merged_abundance_table.txt"
    output: "output/abundance_heatmap_species.png"
    conda: "utils/envs/hclust_env.yaml"
    shell:
            """
            grep -E "(s__)|(^ID)" output/merged_abundance_table.txt | grep -v "t__" | sed 's/^.*s__//g' > output/merged_abundance_table_species.txt
            hclust2.py -i output/merged_abundance_table_species.txt -o output/abundance_heatmap_species.png --ftop 25 --f_dist_f braycurtis --s_dist_f braycurtis --cell_aspect_ratio 0.5 -l --flabel_size 6 --slabel_size 6 --max_flabel_len 100 --max_slabel_len 100 --minv 0.1 --dpi 300
            """
