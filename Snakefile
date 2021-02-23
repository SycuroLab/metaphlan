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
        config["output_dir"] + "/merged_abundance_table_species.txt"

rule merge_reads:
    input:
        r1 = config["path"]+"{sample}"+config["for"],
        r2 = config["path"]+"{sample}"+config["rev"]
    output:
        config["output_dir"] + "/merged_data/{sample}.fastq"
    shell:
        "cat {input.r1} {input.r2} > {output}"

#rule download_database:
#    output: touch(config["output_dir"] + "/logs/database.done")
#    conda: "utils/envs/metaphlan3_env.yaml"
#    shell: "metaphlan --install"

rule metaphlan:
    input:
#        db = config["output_dir"] +"/logs/database.done",
        reads = config["output_dir"] + "/merged_data/{sample}.fastq" if config["paired"] else config["path"]+"{sample}"+config["suff"]
    output:
        bt = config["output_dir"] + "/metaphlan/{sample}_bowtie2.bz2",
        pr = config["output_dir"] + "/metaphlan/{sample}_profile.txt"
    params: threads=config["threads"]
    conda: "utils/envs/metaphlan3_env.yaml"
    shell:
            "metaphlan -t rel_ab_w_read_stats --unknown_estimation {input.reads} --input_type fastq "
            "--bowtie2out {output.bt} --nproc {threads} -o {output.pr}"

rule mergeprofiles:
    input: expand(config["output_dir"] + "/metaphlan/{sample}_profile.txt", sample=SAMPLES)
    output: o1=config["output_dir"] + "/merged_abundance_table.txt",
            o2=config["output_dir"] + "/merged_abundance_table_species.txt"
    params: profiles=config["output_dir"]+"/metaphlan/*_profile.txt"
    conda: "utils/envs/metaphlan3_env.yaml"
    shell: """
           python utils/merge_metaphlan_tables.py {params.profiles} > {o1}
           grep -E "(s__)|(^ID)|(clade_name)|(UNKNOWN)" {o1} | grep -v "t__" | sed 's/^.*s__//g' > {o2}
           """

