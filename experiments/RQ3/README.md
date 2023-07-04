# RQ3: What is the accuracy of relationship extraction?
This subdirectory contains the script and data to reproduce the RQ3 in the paper

## Structure

|Subdirectory|Description|
|----|----|
|[groundtruth/label_carpetfuzz_dataset.json](groundtruth/label_carpetfuzz_dataset.json)|Labeled data of the relationships in documents of the 20 programs.|
|[results](results)|Relationships extracted by CarpetFuzz.|
|[scripts/analyze_results.py](scripts/analyze_results.py)|Analyze and calculate the performance of relationship extraction module.|

## How to

Execute the following commands:

```
$ python3 scripts/analyze_results.py
```