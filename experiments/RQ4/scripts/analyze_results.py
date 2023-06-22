#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os
import sys

rq4_dir = os.path.abspath(os.path.join(sys.path[0], ".."))
repo_dir = os.path.abspath(os.path.join(rq4_dir, "..", ".."))
rq1_dir = os.path.join(repo_dir, "experiments", "RQ1")
coverage_rq1_dir = os.path.join(rq1_dir, "results", "coverage")
coverage_rq4_dir = os.path.join(rq4_dir, "results", "coverage")

if __name__ == "__main__":

    coverage_files = os.listdir(coverage_rq4_dir)
    coverage_files.sort()

    coverage_data = {}

    # TODO not union, average
    for filename in coverage_files:
        if filename.startswith("."):
            continue
        
        program = filename.split("_")[0]
        fuzzer = "carpetfuzz_random"

        if program not in coverage_data:
            coverage_data[program] = {}

        if fuzzer not in coverage_data[program]:
            coverage_data[program][fuzzer] = []
        
        with open(os.path.join(coverage_rq4_dir, filename), "r") as f:
            showmap_list = f.read().splitlines()
        
        edge_list = [line.split(":")[0] for line in showmap_list if len(line) != 0]
        coverage_data[program][fuzzer].append(edge_list)

    coverage_files = os.listdir(coverage_rq1_dir)
    coverage_files.sort()

    for filename in coverage_files:
        if filename.startswith("."):
            continue
        
        program, fuzzer, index = filename.split("_")

        if program not in coverage_data:
            continue

        if fuzzer not in coverage_data[program]:
            coverage_data[program][fuzzer] = []
        
        with open(os.path.join(coverage_rq1_dir, filename), "r") as f:
            showmap_list = f.read().splitlines()
        
        edge_list = []

        if fuzzer != "carpetfuzz":
            for line in showmap_list:
                if len(line) == 0:
                    continue

                edge = line.split(":")[0]

                # Union
                if edge not in coverage_data[program][fuzzer]:
                    coverage_data[program][fuzzer].append(edge)
        # Average for CarpetFuzz
        else:
            edge_list = [line.split(":")[0] for line in showmap_list if len(line) != 0]
            coverage_data[program][fuzzer].append(edge_list)
    
    print ("{:<20} {:<24} {:<24}".format('','Compare to AFL', 'Compare to ALL'))
    print ("{:<20} {:<8} {:<8} {:<8} {:<8} {:<8} {:<8}".format('Program','Ranked', 'Random', 'Rate', 'Ranked', 'Random', 'Rate'))
    
    sum_list = [0] * 6

    for program in coverage_data.keys():
        row_data = [program]

        edges_afl = set(coverage_data[program]["afl"])
        edges_all = set(coverage_data[program]["afl"])

        for fuzzer in ["aflfast", "mopt", "afl++"]:
            edges = set(coverage_data[program][fuzzer])

            edges_all = edges_all | edges
        
        unique_edges_carpetfuzz_sum = 0
        unique_edges_carpetfuzz_random_sum = 0
        unique_edges_carpetfuzz_to_all_sum = 0
        unique_edges_carpetfuzz_random_to_all_sum = 0

        num = len(coverage_data[program]["carpetfuzz"])
        for index in range(num):

            edges_carpetfuzz = set(coverage_data[program]["carpetfuzz"][index])
            edges_carpetfuzz_random = set(coverage_data[program]["carpetfuzz_random"][index])
        
            unique_edges_carpetfuzz_sum += len(edges_carpetfuzz - edges_afl)
            unique_edges_carpetfuzz_random_sum += len(edges_carpetfuzz_random - edges_afl)

            unique_edges_carpetfuzz_to_all_sum += len(edges_carpetfuzz - edges_all)
            unique_edges_carpetfuzz_random_to_all_sum += len(edges_carpetfuzz_random - edges_all)
        
        unique_edges_carpetfuzz_avg = unique_edges_carpetfuzz_sum / num
        unique_edges_carpetfuzz_random_avg = unique_edges_carpetfuzz_random_sum / num
        rate = unique_edges_carpetfuzz_avg / unique_edges_carpetfuzz_random_avg

        row_data.append("%.1f" % unique_edges_carpetfuzz_avg)
        row_data.append("%.1f" % unique_edges_carpetfuzz_random_avg)
        row_data.append("%.2f%%" % (100 * rate))

        unique_edges_carpetfuzz_to_all_avg = unique_edges_carpetfuzz_to_all_sum / num
        unique_edges_carpetfuzz_random_to_all_avg = unique_edges_carpetfuzz_random_to_all_sum / num
        rate_to_all = unique_edges_carpetfuzz_to_all_avg / unique_edges_carpetfuzz_random_avg
        
        row_data.append("%.1f" % unique_edges_carpetfuzz_to_all_avg)
        row_data.append("%.1f" % unique_edges_carpetfuzz_random_to_all_avg)
        row_data.append("%.2f%%" % (100 * rate_to_all))
        
        sum_list[0] += unique_edges_carpetfuzz_avg
        sum_list[1] += unique_edges_carpetfuzz_random_avg
        sum_list[2] += rate
        sum_list[3] += unique_edges_carpetfuzz_to_all_avg
        sum_list[4] += unique_edges_carpetfuzz_random_to_all_avg
        sum_list[5] += rate_to_all

        print("{:<20} {:<8} {:<8} {:<8} {:<8} {:<8} {:<8}".format(*row_data))
    
    print("{:<20} {:<8} {:<8} {:<8} {:<8} {:<8} {:<8}".format('Average', "%.2f"%(sum_list[0]/10), "%.2f"%(sum_list[1]/10), "%.2f%%"%(100 * sum_list[2]/10), "%.2f"%(sum_list[3]/10), "%.2f"%(sum_list[4]/10), "%.2f%%"%(100 * sum_list[5]/10)))