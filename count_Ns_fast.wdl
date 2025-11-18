version 1.0

workflow count_Ns_fast {
    input {
        File fasta_file
    }

    call split_fasta_sequences {
        input:
            fasta = fasta_file
    }

    scatter (seq_file in split_fasta_sequences.sequence_files) {
        call count_ns_fast_per_seq {
            input:
                sequence_file = seq_file
        }
    }

    call create_chromosome_summary {
        input:
            result_files = count_ns_fast_per_seq.result_file
    }

    output {
        File summary_csv = create_chromosome_summary.summary_file
        Int total_n_count = create_chromosome_summary.total_count
    }
}

task split_fasta_sequences {
    input {
        File fasta
    }

    command <<<
        echo "Splitting FASTA file into individual sequences..."
        mkdir -p sequences
        
        awk '
        /^>/ {
            if (out) close(out)
            header = substr($1, 2)  # Remove >
            out = "sequences/" header ".fasta"
        }
        {
            if (out) print > out
        }
        ' ~{fasta}
        
        ls sequences/*.fasta > sequence_files.txt
        echo "Created $(wc -l < sequence_files.txt) individual sequence files"
    >>>

    output {
        Array[File] sequence_files = read_lines("sequence_files.txt")
    }

    runtime {
        docker: "ubuntu:22.04"
        memory: "2 GB"
        cpu: 1
    }
}

task count_ns_fast_per_seq {
    input {
        File sequence_file
    }

    command <<<
        sequence_name=$(basename ~{sequence_file} .fasta)
        echo "Processing sequence: $sequence_name"
        
        grep -o -i 'N' ~{sequence_file} | wc -l > n_count.txt
        count=$(cat n_count.txt)
        
        echo "$sequence_name,$count" > result.txt
        echo "$sequence_name,$count"
    >>>

    output {
        Int n_count = read_int("n_count.txt")
        File result_file = "result.txt"
        String sequence_name = basename(sequence_file, ".fasta")
    }

    runtime {
        docker: "ubuntu:22.04"
        memory: "1 GB"
        cpu: 1
    }
}

task create_chromosome_summary {
    input {
        Array[File] result_files
    }

    command <<<
        echo "Creating chromosome summary..."
        echo "Chromosome,N_Count" > summary.csv
        
        total=0
        for result_file in ~{sep=" " result_files}; do
            line=$(cat $result_file)
            echo "$line" >> summary.csv
            count=$(echo "$line" | cut -d',' -f2)
            total=$((total + count))
        done
        
        echo "Total,$total" >> summary.csv
        echo $total > total_count.txt
        
        echo "Final Results (Fast Version):"
        cat summary.csv
    >>>

    output {
        File summary_file = "summary.csv"
        Int total_count = read_int("total_count.txt")
    }

    runtime {
        docker: "ubuntu:22.04"
        memory: "1 GB"
        cpu: 1
    }
}