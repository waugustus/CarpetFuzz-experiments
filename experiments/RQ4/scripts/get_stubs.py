#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os
import re
import sys
import json
import argparse

rq4_path = os.path.abspath(os.path.join(sys.path[0], ".."))
repo_path = os.path.abspath(os.path.join(rq4_path, "..", ".."))
stubs_dir = os.path.join(rq4_path, "results", "stubs")
output_dir = os.path.join(repo_path, "output", "carpetfuzz_dataset")
configures_dir = os.path.join(repo_path, "configures")
programs_dir = os.path.abspath(os.path.join(repo_path, "..", "programs"))
fuzzer_dir = os.path.abspath(os.path.join(repo_path, "..", "fuzzer"))

with open(os.path.join(configures_dir, "carpetfuzz_dataset", "config.json"), "r") as f:
    config = json.loads(f.read())

def scanStubs():

    dir_list = os.listdir(output_dir)
    dir_list.sort()

    for dir in dir_list:
        if dir.startswith("."):
            continue
        if "_random" not in dir:
            continue

        print("[*] Processing %s ..." % dir)
        
        ret_list = []

        program, _, _, index = dir.split("_")
        package = config[program]["package"]

        build_path = os.path.join(programs_dir, package, "build_afl++")
        orig_stub = config[program]["stub"]

        queue_dir = os.path.join(output_dir, dir, "queue")

        argvs_path = os.path.join(repo_path, "configures", "carpetfuzz_dataset", "argvs", package, "random_stubs_%s_%s.txt" % (program, index))
        with open(argvs_path, "r") as f:
            argvs = f.read().splitlines()[1:]
        
        testcase_list = os.listdir(queue_dir)
        testcase_list.sort()
        for testcase in testcase_list:
            if testcase.startswith("."):
                continue
            testcase_path = os.path.join(queue_dir, testcase)
            if "argv:" in testcase:
                argv_id = int(re.search(r"argv:(\d+)", testcase).group(1))
                stub = "{build_path}/bin/{stub}".format(build_path=build_path, stub=argvs[argv_id].replace("@@", testcase_path))
                    
            else:
                stub = "{build_path}/bin/{stub}".format(build_path=build_path, stub=orig_stub.replace("@@", testcase_path))
            ret_list.append(stub)

        with open(os.path.join(stubs_dir, "%s.txt" % dir), "w") as f:
            f.write("\n".join(ret_list))
    return

if __name__ == "__main__":

    parser = argparse.ArgumentParser(description='''
    CarpetFuzz-experiments - CarpetFuzz's experiments.
        get_stubs.py - Get stub files for afl-showmap.py.
    ''', formatter_class=argparse.RawTextHelpFormatter)

    args = parser.parse_args()

    scanStubs()

    print("[OK] All finished, results are saved in %s." % stubs_dir)