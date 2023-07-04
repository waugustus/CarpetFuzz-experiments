# RQ4: What is the effectiveness of CarpetFuzz’s prioritization technique?
This subdirectory contains the script and data to reproduce the RQ4 in the paper

## Structure

|Subdirectory|Description|
|----|----|
|[results/coverage](results/coverage/)|Coverage data of CarpetFuzz-random instances.|
|[results/stubs](results/stubs/)|Stub files of the testcase for measuring coverage|
|[scripts/afl-showmap.py](scripts/afl-showmap.py)|A Python wrapper of afl-showmap to measure coverage based on stub files, maintained in https://github.com/waugustus/pyshowmap|
|[scripts/analyze_results.py](scripts/analyze_results.py)|Analyze and calculate coverage information, and present it in the format of Table 2.|
|[scripts/get_stubs.py](scripts/get_stubs.py)|Obtain stubs of testcase for measuring coverage.|


## How to

Execute the following commands:

```
$ python3 scripts/get_stubs.py
$ python3 scripts/afl-showmap.py
$ python3 scripts/analyze_results.py
```