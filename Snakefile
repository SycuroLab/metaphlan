# ************************************
# * Snakefile for metaphlan pipeline *
# ************************************

# **** Variables ****

configfile: "config.yaml"

# **** Imports ****

import pandas as pd
SAMPLES = pd.read_csv(config["list_files"], header = None)
SAMPLES = SAMPLES[0].tolist()

#os.environ["PATH"]+=os.pathsep+"/bulk/IMCshared_bulk/shared/shared_software/MetaPhlAn/metaphlan3/bin/"

# **** Rules ****

rule all:
    input:
        config["output_dir"] + "/merged_abundance_table_species.txt",
#        config["output_dir"] + "/merged_abundance_table_species_relab.txt"

rule merge_reads:
    input:
        r11 = config["path"]+"{sample}"+config["for"],
        r12 = config["path"]+"{sample}"+config["rev"],
    output:
        config["output_dir"] + "/merged_data/{sample}.fastq"
    shell:
        "cat {input.r11} {input.r12} > {output}"

	
#rule download_database:
#    output: touch(config["output_dir"] + "/logs/database.done")
#    conda: "utils/envs/metaphlan3_env.yaml"
#    shell: "metaphlan --install"

rule metaphlan:
    input:
        reads = config["output_dir"] + "/merged_data/{sample}.fastq" if config["paired"] else config["path"]+"{sample}"+config["suff"]
    output:
        bt = config["output_dir"] + "/metaphlan/{sample}_bowtie2.bz2",
        sam = config["output_dir"] + "/metaphlan/{sample}_sam.bz2",
        pr = config["output_dir"] + "/metaphlan/{sample}_profile.txt"
    params:
        metaphlan_database = config["metaphlan_database"],
        threads = config["threads"]

    conda: "utils/envs/metaphlan3_env.yaml"
    shell:
            "metaphlan -t rel_ab_w_read_stats --unknown_estimation {input.reads} --add_viruses --input_type fastq -s {output.sam} "
            "--bowtie2db {params.metaphlan_database} --bowtie2out {output.bt} --nproc {params.threads} -o {output.pr}"

rule mergeprofiles:
    input: expand(config["output_dir"] + "/metaphlan/{sample}_profile.txt", sample=SAMPLES)
    output: o1=config["output_dir"] + "/merged_abundance_table.txt",
            o2=config["output_dir"] + "/merged_abundance_table_species.txt"
    params: profiles=config["output_dir"]+"/metaphlan/*_profile.txt"
    conda: "utils/envs/merge_metaphlan_tables_env.yaml"
    shell: """
           python utils/merge_metaphlan_tables.py {params.profiles} > {output.o1}
           grep -E "(s__)|(^ID)|(clade_name)|(UNKNOWN)" {output.o1} | grep -v "t__" | sed 's/^.*s__//g' > {output.o2}
           """
#rule mergeprofiles_relab:
#    input: expand(config["output_dir"] + "/metaphlan/{sample}_profile.txt", sample=SAMPLES)
#    output: o1=config["output_dir"] + "/merged_abundance_table_relab.txt",
#            o2=config["output_dir"] + "/merged_abundance_table_species_relab.txt"
#    params: profiles=config["output_dir"]+"/metaphlan/*_profile.txt"
#    conda: "utils/envs/metaphlan3_env.yaml"
#    shell: """
#           python utils/merge_metaphlan_tables_relab.py {params.profiles} > {output.o1}
#           grep -E "(s__)|(^ID)|(clade_name)|(UNKNOWN)" {output.o1} | grep -v "t__" | sed 's/^.*s__//g' > {output.o2}
#           """
#
