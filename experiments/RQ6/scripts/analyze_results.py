#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os
import sys

rq6_path = os.path.abspath(os.path.join(sys.path[0], ".."))
repo_path = os.path.abspath(os.path.join(rq6_path, "..", ".."))
output_path = os.path.join(repo_path, "output", "carpetfuzz_dataset")

if __name__ == "__main__":
    dir_list = os.listdir(output_path)
    dir_list.sort()

    crashes_dict = {}
    for dir in dir_list:
        if dir.startswith(".") or "carpetfuzz" not in dir:
            continue
        # Only consider original CarpetFuzz
        if "carpetfuzz_random" in dir:
            continue

        program = dir.split("_")[0]

        if program not in crashes_dict:
            crashes_dict[program] = 0

        crashes_dir = os.path.join(output_path, dir, "crashes")

        crashes_num = len([filename for filename in os.listdir(crashes_dir) if filename.startswith("id:")])

        crashes_dict[program] += crashes_num

    print("[OK] Found %d crashes:" % sum(crashes_dict.values()))
    for program in crashes_dict.keys():
        print("    - %s: %d" % (program, crashes_dict[program]))
