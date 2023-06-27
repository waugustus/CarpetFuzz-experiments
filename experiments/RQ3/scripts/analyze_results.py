#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os
import sys
import json

rq3_dir = os.path.abspath(os.path.join(sys.path[0], ".."))
groundtruth_dir = os.path.join(rq3_dir, "groundtruth")
results_dir = os.path.join(rq3_dir, "results")

if __name__ == "__main__":
    label_data_path = os.path.join(groundtruth_dir, "label_carpetfuzz_dataset.json")

    with open(label_data_path, "r") as f:
        label_data = json.loads(f.read())

    TP_c, FP_c, FN_c = 0, 0, 0
    TP_d, FP_d, FN_d = 0, 0, 0
    for program in label_data:
        conflict_list = label_data[program]["conflict"]
        dependent_dict = label_data[program]["dependent"]

        extracted_data_path = os.path.join(results_dir, "relation_%s.json" % program)

        with open(extracted_data_path, "r") as f:
            extracted_data = json.loads(f.read())

        for conflict_pair in extracted_data["options"]['conflict_options']:

            # For lrzip, the "-o" option is used to specify the output file. 
            # We consider it as a mandatory option, so we have removed the "-O" option 
            # and ignored any conflicting relationship between them. 
            # If we were to consider this relationship, the precision would be higher.
            if program == "lrzip" and conflict_pair == ["-O", "-o"]:
                continue
            
            # Check other conflict pairs
            if conflict_pair in conflict_list or conflict_pair[::-1] in conflict_list:
                TP_c += 1
            else:
                FP_c += 1

        for conflict_pair in conflict_list:
            if conflict_pair not in extracted_data["options"]['conflict_options'] and conflict_pair[::-1] not in extracted_data["options"]['conflict_options']:
                FN_c += 1
        
        for dependent_key in extracted_data["options"]['dependent_options']:
            if dependent_key in dependent_dict and extracted_data["options"]['dependent_options'][dependent_key] == dependent_dict[dependent_key]:
                TP_d += 1
            else:
                FP_d += 1
        
        for dependent_key in dependent_dict:
            if not dependent_key in extracted_data["options"]['dependent_options'] or dependent_dict[dependent_key] != extracted_data["options"]['dependent_options'][dependent_key]:
                FN_d += 1


    TP = TP_c + TP_d
    FP = FP_c + FP_d
    FN = FN_c + FN_d

    print("{:<16} {:<10} {:<10}".format("Type", "Precision", "Recall"))

    print("{:<16} {:<10} {:<10}".format("Conflict", "%.2f%%" % (100 * (TP_c)/(TP_c + FP_c)), "%.2f%%" % (100 * (TP_c)/(TP_c + FN_c))))
    print("{:<16} {:<10} {:<10}".format("Dependent", "%.2f%%" % (100 * (TP_d)/(TP_d + FP_d)), "%.2f%%" % (100 * (TP_d)/(TP_d + FN_d))))
    print("{:<16} {:<10} {:<10}".format("All", "%.2f%%" % (100 * (TP)/(TP + FP)), "%.2f%%" % (100 * (TP)/(TP + FN))))
 