#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os
import sys

rq1_path = os.path.abspath(os.path.join(sys.path[0], ".."))
repo_path = os.path.abspath(os.path.join(rq1_path, "..", ".."))
coverage_dir = os.path.join(rq1_path, "results", "coverage")

if __name__ == "__main__":

    coverage_files = os.listdir(coverage_dir)
    coverage_files.sort()

    coverage_data = {}

    for filename in coverage_files:
        if filename.startswith("."):
            continue
        
        program, fuzzer, index = filename.split("_")

        if program not in coverage_data:
            coverage_data[program] = {}

        if fuzzer not in coverage_data[program]:
            coverage_data[program][fuzzer] = []
        
        with open(os.path.join(coverage_dir, filename), "r") as f:
            showmap_list = f.read().splitlines()
        
        for line in showmap_list:
            if len(line) == 0:
                continue

            edge = line.split(":")[0]

            # Union
            if edge not in coverage_data[program][fuzzer]:
                coverage_data[program][fuzzer].append(edge)

    print ("{:<20} {:<89} {:<48}".format('','Baseline', 'CarpetFuzz'))
    print ("{:<20} {:<8} {:<26} {:<26} {:<26} {:<8} {:<17} {:<24}".format('Program','AFL', 'AFLfast', 'MOPT', 'AFL++', '', 'Compare to AFL', 'Compare to ALL'))
    print ("{:<20} {:<8} {:<8} {:<8} {:<8} {:<8} {:<8} {:<8} {:<8} {:<8} {:<8} {:<8} {:<8} {:<8} {:<8} {:<8} {:<8}".format('','E_b',
        'E_f', 'n_f', 'r',
        'E_f', 'n_f', 'r',
        'E_f', 'n_f', 'r',
        'E_f', 'n_f', 'r',
        'n_all', 'r_all', 'Pct.'))
    
    r_sum = {"aflfast": 0, "mopt": 0, "afl++": 0, "carpetfuzz": 0, "all": 0}
    pct_sum = 0

    for program in coverage_data.keys():
        row_data = [program]

        edges_afl = set(coverage_data[program]["afl"])
        edges_all = set(coverage_data[program]["afl"])
        row_data.append(len(edges_afl))
        for fuzzer in ["aflfast", "mopt", "afl++"]:
            edges = set(coverage_data[program][fuzzer])
            unique_edges = edges - edges_afl

            row_data.append(len(edges))
            row_data.append(len(unique_edges))
            row_data.append("%.2f%%" % (100 * len(unique_edges)/len(edges_afl)))

            edges_all = edges_all | edges

            r_sum[fuzzer] += 100 * len(unique_edges)/len(edges_afl)
        
        edges_carpetfuzz = set(coverage_data[program]["carpetfuzz"])
        unique_edges_carpetfuzz = edges_carpetfuzz - edges_afl

        row_data.append(len(edges_carpetfuzz))
        row_data.append(len(unique_edges_carpetfuzz))
        row_data.append("%.2f%%" % (100 * len(unique_edges_carpetfuzz)/len(edges_afl)))

        unique_edges_carpetfuzz_to_all = edges_carpetfuzz - edges_all
        
        row_data.append(len(unique_edges_carpetfuzz_to_all))
        row_data.append("%.2f%%" % (100 * len(unique_edges_carpetfuzz_to_all)/len(edges_afl)))
        if len(unique_edges_carpetfuzz) == 0:
            row_data.append(0)
        else:
            row_data.append("%.2f%%" % (100 * len(unique_edges_carpetfuzz_to_all)/len(unique_edges_carpetfuzz)))
            pct_sum += 100 * len(unique_edges_carpetfuzz_to_all)/len(unique_edges_carpetfuzz)

        r_sum["carpetfuzz"] += 100 * len(unique_edges_carpetfuzz)/len(edges_afl)
        r_sum["all"] += 100 * len(unique_edges_carpetfuzz_to_all)/len(edges_afl)

        print("{:<20} {:<8} {:<8} {:<8} {:<8} {:<8} {:<8} {:<8} {:<8} {:<8} {:<8} {:<8} {:<8} {:<8} {:<8} {:<8} {:<8}".format(*row_data))
    
    print("{:<20} {:<8} {:<8} {:<8} {:<8} {:<8} {:<8} {:<8} {:<8} {:<8} {:<8} {:<8} {:<8} {:<8} {:<8} {:<8} {:<8}".format('Average', '', '', '', "%.2f%%"%(r_sum["aflfast"] / 20), '', '', "%.2f%%"%(r_sum['mopt'] / 20), '', '', "%.2f%%"%(r_sum["afl++"] / 20), '', '', "%.2f%%"%(r_sum['carpetfuzz'] / 20), '', "%.2f%%"%(r_sum['all'] / 20), "%.2f%%"%(pct_sum / 20)))
        


        

        
