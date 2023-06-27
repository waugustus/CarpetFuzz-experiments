#!/usr/bin/env python
# -*- coding: utf-8 -*-
# We created this file based on CarpetFuzz/script/find_relationship.py
# to reduce the time cost caused by multiple loading of the model

import os
import sys
import json

rq2_dir = os.path.abspath(os.path.join(sys.path[0], ".."))
repo_dir = os.path.abspath(os.path.join(rq2_dir, "..", ".."))
results_dir = os.path.join(rq2_dir, "results")
groundtruth_dir = os.path.join(rq2_dir, "groundtruth")

project_dir = os.path.abspath(os.path.join(repo_dir, "..", "fuzzer", "CarpetFuzz"))
model_dir = os.path.join(project_dir, "models")
script_dir = os.path.join(project_dir, "scripts")

sys.path.append(os.path.join(script_dir))

from utils.groff_util import GroffUtil
from utils.nlp_util import NLPUtil
from utils.model_util import ModelUtil
from utils.relationship_util import RelationshipUtil

groff_util = GroffUtil()
nlp_util = NLPUtil("%s/elmo-constituency-parser-2020.02.10.tar.gz" % model_dir)
relationship_util = RelationshipUtil(nlp_util)

def evaluateOnValidationDataset():
    # Validation dataset
    label_path = os.path.join(groundtruth_dir, "label_validation_dataset.json")
    with open(label_path, "r") as f:
        label_data = json.loads(f.read())

    positive_sents = label_data["positive"]
    negative_sents = label_data["negative"]

    formatted_list = []
    for sents in [positive_sents, negative_sents]:
        for sent in sents:
            formatted_list.append({'cmd': '', 'option': '', 'sent': sent})
    
    preprocessed_list = nlp_util.preprocessing(formatted_list, {}, [])

    sent2vec_model_path = "%s/linux_w2v_300d.model" % model_dir
    xgb_model_path = "%s/xgb.m" % model_dir
    feature_num = 300
    threshold = 0.5
    model_util = ModelUtil(xgb_model_path, sent2vec_model_path, feature_num, threshold)
    # Explicit R-sentences
    prediction_positive_list, prediction_negative_list = model_util.prediction(preprocessed_list)

    TP = 0
    TN = 0
    FP = 0
    FN = 0
    for d in prediction_positive_list:
        if d['sent'] in positive_sents:
            TP += 1
        elif d['sent'] in negative_sents:
            FP += 1
    
    for d in prediction_negative_list:
        if d['sent'] in negative_sents:
            TN += 1
        elif d['sent'] in positive_sents:
            FN += 1
    
    acc, fpr, recall = (TP + TN)/(TP + TN + FP + FN), FP/(FP + TN), TP/(TP + FN)

    return acc, fpr, recall

def evaluateOnCarpetFuzzDataset():
    # Validation dataset
    label_path = os.path.join(groundtruth_dir, "label_carpetfuzz_dataset.json")
    with open(label_path, "r") as f:
        label_data = json.loads(f.read())

    positive_sents = label_data["positive"]
    negative_sents = label_data["negative"]
    idc_pairs = label_data["IDC"]

    TP, FP, TN, FN = 0, 0, 0, 0
    TP_i, FP_i, FN_i = 0, 0, 0

    prediction_idc_pairs = []
    for filename in os.listdir(results_dir):
        if filename.startswith("."):
            continue
            
        with open(os.path.join(results_dir, filename), "r") as f:
            data = json.loads(f.read())
        rsents = data["rsent"]
        non_rsents = data["non_rsent"]
        implicit_rsent_pairs = data["implicit_rsent"]

        for d in rsents:
            sent = d['sent'].strip()
            if sent in positive_sents:
                TP += 1
            elif sent in negative_sents:
                FP += 1
        
        for d in non_rsents:
            sent = d['sent'].strip()
            if sent in negative_sents:
                TN += 1
            elif sent in positive_sents:
                FN += 1

        for pair in implicit_rsent_pairs:
            if [pair[0]["sent"], pair[1]["sent"]] in idc_pairs or [pair[1]["sent"], pair[0]["sent"]] in idc_pairs:
                TP_i += 1
            else:
                FP_i += 1
            prediction_idc_pairs.append([pair[0]["sent"], pair[1]["sent"]])

    for pair in idc_pairs:
        if pair not in prediction_idc_pairs and pair[::-1] not in prediction_idc_pairs:
            FN_i += 1

    acc_e, fpr_e, recall_e = (TP + TN)/(TP + TN + FP + FN), FP/(FP + TN), TP/(TP + FN)
    precision_i, recall_i = (TP_i) / (TP_i + FP_i), (TP_i) / (TP_i + FN_i)

    return acc_e, fpr_e, recall_e, precision_i, recall_i

if __name__ == "__main__":
    
    acc_v, fpr_v, recall_v = evaluateOnValidationDataset()
    acc_c, fpr_c, recall_c, precision_i, recall_i = evaluateOnCarpetFuzzDataset()

    print("{:<16} {:<16} {:<10} {:<10} {:<10}".format("Type", "Dataset", "Accuracy", "FPR", "Recall"))
    print("{:<16} {:<16} {:<10} {:<10} {:<10}".format("Explicit", "Validation", "%.2f%%" % (100 * acc_v), "%.2f%%" % (100 * fpr_v), "%.2f%%" % (100 * recall_v)))
    print("{:<16} {:<16} {:<10} {:<10} {:<10}".format("Explicit", "CarpetFuzz", "%.2f%%" % (100 * acc_c), "%.2f%%" % (100 * fpr_c), "%.2f%%" % (100 * recall_c)))
    print("{:<16} {:<16} {:<21} {:<10}".format("Implicit", "CarpetFuzz", "%.2f%% (Precision)" % (100 * precision_i), "%.2f%%" % (100 * recall_i)))
    



    
    

    