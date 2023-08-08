# CarpetFuzz-experiments
This repo contains the data required to reproduce the experiments from our USENIX 2023 publication: CarpetFuzz: Automatic Program Option Constraint Extraction from Documentation for Fuzzing.

In our paper, we evaluated CarpetFuzz through a total of six experiments, including an end-to-end experiment, a comparative experiment, and four submodule experiments, which collectively required 33,600 CPU hours.

The CarpetFuzz version used in the experiment is commit 50f09eb94d33abbfe3e18184988a0c3a8f0f5612.

## Environment

We conducted the experiment on a server with 128 cores, 256GB of memory, and 11TB of disk space. The server was running the Ubuntu 20.04 operating system.

We believe that a configuration with 32 cores, 128GB of memory, and 50GB of disk space is sufficient.

## Install

Our benchmark includes **50 executable programs**. To alleviate the manual effort involved in resolving the dependencies of the environment, we have provided a Dockerfile to automate the setup of the required environment for all experiments.

```
# Download CarpetFuzz repo with the submodules
git clone https://github.com/waugustus/CarpetFuzz-experiments
cd CarpetFuzz-experiments
# Build image
sudo docker build -t
carpetfuzz-experiment:latest .
# Create container
sudo docker run -d -name
"carpetfuzz-experiment"
carpetfuzz-experiment:latest tail -f
/dev/null
sudo docker exec -it
carpetfuzz-experiment bash
```

## Preprossing

### Fuzzing
To replicate the experiments described in the paper, the first step is to initiate all Fuzzing instances, which would require approximately **33,600 CPU hours**. 

```
chmod +x ./run_fuzzing.sh
# Repeat 5 times, under CarpetFuzz and POWER dataset
screen -dmS fuzzing bash -c "./run_fuzzing.sh -r 5 -e 2>&1 |tee fuzzing.log" 
```

Note that due to the unavailability of a license from the authors of POWER, we are unable to utilize their tools for conducting comparative experiments in this repo. Therefore, it is optional to perform the comparative experiments, resulting in a reduction of 7200 CPU hours. 

Additionally, in the paper, each Fuzzing instance was repeated five times. However, for the sake of simplification, conducting three repetitions is deemed acceptable, resulting in a reduction of 10,560 CPU hours.

Therefore, the experiments can be simplified to (about **15,840 CPU-hours**),

```
# Repeat 3 times, without POWER dataset
screen -dmS fuzzing bash -c "./run_fuzzing.sh -r 3 2>&1 |tee fuzzing.log" 
```

If you don't intend to run the entire benchmark, you can try using the `-s` and `-p` options, which will reduce the time to approximately `48 * 6 * PROGRAMS * REPETITIONS`. You can customize the number of programs and repetitions based on your specific requirements and available resources. For instance, if you choose to run experiments on 5 programs from Table 2, with 5 repetitions each, the estimated CPU hours would be around 4320.

```
# Repeat 5 times, only use 5 programs from Table 5
screen -dmS fuzzing bash -c "./run_fuzzing.sh -r 5 -s -p 5 2>&1 |tee fuzzing.log" 
```

Considering the inherent stochastic nature of fuzzing, we **strongly recommend** conducting at least **5** repetitions of the experiments whenever feasible. This will help ensure better reproducibility of the results presented in the paper and provide more robust insights into the effectiveness of our approach.


The fuzzing results will be saved in [output/carpetfuzz_dataset](output/carpetfuzz_dataset) and [output/power_dataset](output/power_dataset)

### Relationship Identification & Extraction

To replicate the experiments in Sections 5.2 and 5.3, relationship identification and extraction need to be performed on the documents in the program's compilation directory (about **1 hour**).

```
screen -dmS bash -c "python3 analyzing_manpages.py 2>&1 | tee analyze.log"
```

After completing the preprocessing step, the results of all experiments can be obtained using the corresponding scripts in their respective directories.

## Structure

|Subdirectory|Section|Research Question|Time Required|Space Required|
|----|----|----|----|----|
|[experiments/RQ1](experiments/RQ1)|5.1|What is the performance of CarpetFuzz?| < 1 hour| < 100MB|
|[experiments/RQ2](experiments/RQ2)|5.2|What is the accuracy of relationship identification?| < 10 minutes | < 100MB |
|[experiments/RQ3](experiments/RQ3)|5.3|What is the accuracy of relationship extraction?| < 10 minutes | < 100MB |
|[experiments/RQ4](experiments/RQ4)|5.4|What is the effectiveness of CarpetFuzz’s prioritization technique?| < 1 hour | < 100MB
|[experiments/RQ5](experiments/RQ5)|5.5|What is the fuzzing performance of CarpetFuzz com- pared to the state-of-the-art techniques?| N/A | N/A |
|[experiments/RQ6](experiments/RQ6)|5.6|Can CarpetFuzz discover real-world vulnerabilities?| < 10 minutes | None |
