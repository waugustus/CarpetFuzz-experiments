#!/bin/bash

repo_path="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
output_dir="${repo_path}/output"
configures_dir="${repo_path}/configures"
programs_carpetfuzz_dataset_dir="$( realpath "${repo_path}/../programs" )"
programs_power_dataset_dir="$( realpath "${repo_path}/../programs_rq5" )"
fuzzer_dir="$( realpath "${repo_path}/../fuzzer" )"

config_carpetfuzz_dataset=$(cat "${configures_dir}/carpetfuzz_dataset/config.json")
config_power_dataset=$(cat "${configures_dir}/power_dataset/config.json")

usage() {
    echo "CarpetFuzz-experiments - CarpetFuzz's experiments."
    echo "run_fuzzing.sh - Run all fuzzing instances in the paper."
    echo
    echo "Usage: $0 [-c CORES] [-r REPEAT] [-s] [-h]"
    echo
    echo "Options:"
    echo "  -c CORES   Number of cores to be used (default: number of available CPU cores)."
    echo "  -r REPEAT  Number of repetitions (default: 5)."
    echo "  -e         Extended mode. Also fuzz programs in Power's dataset."
    echo "  -s         Simplified mode. Only fuzz programs in Table 2. (can be combined with -p)"
    echo "  -p         Number of programs to be fuzzed (only work with -s)"
    echo "  -h         Display this help message."
}

runFuzzing() {
    total_runs=$1
    cores=$2

    printf '%s\n' "${total_runs[@]}"| xargs -P ${cores} -n 1 -I {} bash -c "{}"
}

runOnCarpetFuzzDataset() {
    cores=$1
    repeat=$2
    simplified_flag=$3
    num_programs=$4

    total_runs=()

    cpu_bind=0

    # 48 hours
    timeout_seconds=172800
    programs_dir=${programs_carpetfuzz_dataset_dir}

    for key in $(echo $config_carpetfuzz_dataset|jq keys[]); do
        
        program=$(echo $key|tr -d '"')
        package=$(echo $config_carpetfuzz_dataset|jq .${key}.package|tr -d '"')

        prioritization=$(echo $config_carpetfuzz_dataset | jq .${key}.prioritization)
        if [[ ${simplified_flag} == true ]];then
            if [[ "${prioritization}" == null ]];then
                continue
            fi

            num_programs=`expr ${num_programs} - 1`
            if [[ ${num_programs} < 0 ]]; then
                break
            fi
        fi

        for index in $(seq 1 "${repeat}"); do
            for fuzzer in "afl" "aflfast" "mopt" "afl++" "carpetfuzz" "carpetfuzz_random"; do
                
                if [[ "$fuzzer" == "carpetfuzz_random" && "${prioritization}" == null ]]; then
                    continue
                fi
                
                task="${program}_${fuzzer}_${index}"

                if [[ "${program}" == openssl-* ]]; then
                    input_path="${programs_dir}/${package}/input/${program:8}"
                else
                    input_path="${programs_dir}/${package}/input"
                fi

                output_path="${output_dir}/carpetfuzz_dataset/${task}"
                stub=$(echo $config_carpetfuzz_dataset | jq .${key}.stub |tr -d '"')

                timeout=$(echo $config_carpetfuzz_dataset | jq .${key}.timeout|tr -d '"')
                if [[ "${timeout}" == null ]]; then
                    slice=""
                else
                    slice="-t ${timeout}"
                fi

                if [[ "$fuzzer" == carpetfuzz* ]]; then
                    fuzzer_path="${fuzzer_dir}/CarpetFuzz/fuzzer_afl"
                    build_path="${programs_dir}/${package}/build_carpetfuzz"
                    if [[ "$fuzzer" == "carpetfuzz_random" ]]; then
                        argvs_path="${configures_dir}/carpetfuzz_dataset/argvs/${package}/random_stubs_${program}_${index}.txt"
                    else
                        argvs_path="${configures_dir}/carpetfuzz_dataset/argvs/${package}/ranked_stubs_${program}.txt"                    
                    fi
                    cmd="screen -dmS ${task} timeout ${timeout_seconds}s ${fuzzer_path}/afl-fuzz -i ${input_path} -o ${output_path} -b ${cpu_bind} -m none ${slice} -K ${argvs_path} -- ${build_path}/bin/${stub}; echo \"Fuzzing ${task}\"; sleep ${timeout_seconds}"
                else
                    fuzzer_path="${fuzzer_dir}/${fuzzer}"
                    build_path="${programs_dir}/${package}/build_${fuzzer}"
                    cmd="screen -dmS ${task} timeout ${timeout_seconds}s ${fuzzer_path}/afl-fuzz -i ${input_path} -o ${output_path} -b ${cpu_bind} -m none ${slice} -- ${build_path}/bin/${stub}; echo \"Fuzzing ${task}\"; sleep ${timeout_seconds}"
                fi

                # Wait for other instances to startup
                delay_time=$(expr $cpu_bind \* 1)

                cmd="LD_LIBRARY_PATH=${build_path}/lib $cmd"
                if [[ $program == "editcap" ]]; then
                    cmd="AFL_IGNORE_PROBLEMS=1 $cmd"
                fi

                cmd="sleep ${delay_time}; $cmd"

                total_runs+=("${cmd}")
                cpu_bind=`expr ${cpu_bind} + 1`
                if [[ ${cpu_bind} == ${cores} ]];then
                    cpu_bind=0
                fi
            done
        done
    done

    for cmd in "${total_runs[@]}"
    do
        echo -e "$cmd\n"
    done
    echo ${cpu_bind}

}

runOnPowerDataset() {
    cores=$1
    repeat=$2
    cpu_bind=$3

    total_runs=()

    # 24 hours
    timeout_seconds=86400
    programs_dir=${programs_power_dataset_dir}

    for key in $(echo $config_power_dataset|jq keys[]); do
        
        program=$(echo $key|tr -d '"')
        package=$(echo $config_power_dataset|jq .${key}.package|tr -d '"')
        for index in $(seq 1 "${repeat}"); do
            fuzzer="carpetfuzz++"
            task="${program}_${fuzzer}_${index}"

            input_path="${programs_dir}/${package}/input_${program}"
            output_path="${output_dir}/power_dataset/${task}"
            build_path="${programs_dir}/${package}/build_orig"
            stub=$(echo $config_power_dataset | jq .${key}.stub |tr -d '"')
            stub="${program}.afl ${stub#* }"
            fuzzer_path="${fuzzer_dir}/CarpetFuzz/fuzzer"
            argvs_path="${configures_dir}/power_dataset/argvs/${package}/ranked_stubs_${program}.txt"    

            timeout=$(echo $config_power_dataset | jq .${key}.timeout|tr -d '"')
            if [[ "${timeout}" == null ]]; then
                slice=""
            else
                slice="-t ${timeout}"
            fi                

            cmd="screen -dmS ${task} timeout ${timeout_seconds}s ${fuzzer_path}/afl-fuzz -i ${input_path} -o ${output_path} -b ${cpu_bind} -m none ${slice} -K ${argvs_path} -- ${build_path}/bin/${stub}; echo \"Fuzzing ${task}\"; sleep ${timeout_seconds}"

            cmd="LD_LIBRARY_PATH=${build_path}/lib $cmd"

            # Wait for other instances to startup
            delay_time=$(expr $cpu_bind \* 1)

            cmd="sleep ${delay_time}; $cmd"

            total_runs+=("${cmd}")

            cpu_bind=`expr ${cpu_bind} + 1`
            if [[ ${cpu_bind} == ${cores} ]];then
                cpu_bind=0
            fi
        done
    done

    for cmd in "${total_runs[@]}"
    do
        echo -e "$cmd\n"
    done

}

extended_flag=false
simplified_flag=false

while getopts "c:r:p:seh" opt; do
    case $opt in
        c) cores=$OPTARG ;;
        r) repeat=$OPTARG ;;
        p) programs=$OPTARG ;;
        e) extended_flag=true ;;
        s) simplified_flag=true ;;
        h)
            usage
            exit 0
            ;;
        \?)
            echo "Invalid option: -$OPTARG"
            usage
            exit 1
            ;;
    esac
done

cores=${cores:-$(nproc)}
repeat=${repeat:-5}
programs=${programs:-10}

if (( cores > $(nproc) )); then
    echo "[x] Not enough cores!"
    exit 1
fi

if (( programs > 10 )); then
    echo "[x] Not enough programs in Table 2!"
    exit 1
fi

echo "[*] Number of cores to be used: ${cores}, repeat ${repeat} times"

echo "[*] Get the commands list for CarpetFuzz dataset ..."
IFS=$'\n' read -rd '' -a total_runs <<<"$(runOnCarpetFuzzDataset ${cores} ${repeat} ${simplified_flag} ${programs})"

cpu_bind=${total_runs[-1]}
unset total_runs[-1]

if [[ ${extended_flag} == true ]]; then
    echo "[*] Get the commands list for Power dataset ..."
    IFS=$'\n' read -rd '' -a power_runs <<<"$(runOnPowerDataset ${cores} ${repeat} ${cpu_bind})"
    total_runs+=("${power_runs[@]}")
fi

echo "[*] Start Fuzzing ..."
runFuzzing "${total_runs}" "${cores}"

echo "[OK] All finished, results are saved in output/."