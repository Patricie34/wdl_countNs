version 1.2

workflow count_Ns_slow {
    input {
        File fasta_file
    }

    call count_ns_per_chromosome_slow {
        input:
            fasta = fasta_file
    }

    output {
        File summary_csv = count_ns_per_chromosome_slow.summary_file
        Int total_n_count = count_ns_per_chromosome_slow.total_count
    }
}

task count_ns_per_chromosome_slow {
    input {
        File fasta
    }

    command <<<
        echo "Processing FASTA file sequentially (slow version)..."
        
        awk '
        BEGIN { 
            print "Chromosome,N_Count" > "summary.csv"
            total = 0
        }
        /^>/ {
            if (chromosome != "") {
                print chromosome "," count >> "summary.csv"
                total += count
            }
            chromosome = substr($1, 2)  # Remove >
            count = 0
            next
        }
        {
            line = $0
            gsub(/[^Nn]/, "", line)
            count += length(line)
        }
        END {
            if (chromosome != "") {
                print chromosome "," count >> "summary.csv"
                total += count
            }
            print "Total," total > "summary.csv"
        }
        ' ~{fasta}
        
        grep "^Total," summary.csv | cut -d',' -f2 > total_count.txt
        
        echo "Results (Slow Version):"
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
