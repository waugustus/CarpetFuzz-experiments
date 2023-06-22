#!/usr/bin/env python
# -*- coding: utf-8 -*-
# Maintained in https://github.com/waugustus/pyshowmap

import os
import re
import sys
import shlex
import signal
import argparse
import subprocess
from hashlib import md5
from shutil import copyfile
from multiprocessing import Pool
from sysv_ipc import SharedMemory, IPC_PRIVATE, IPC_CREX


rq1_path = os.path.abspath(os.path.join(sys.path[0], ".."))
repo_path = os.path.abspath(os.path.join(rq1_path, "..", ".."))
stubs_dir = os.path.join(rq1_path, "results", "stubs")
coverage_dir = os.path.join(rq1_path, "results", "coverage")

MAP_SIZE = 8 * 1024 * 1024

timeout_seconds = 1
collect_coverage_flag = True
edges_only_flag = True

stub_list = []

def cleanupSubprocesses(signum, frame):
    os.killpg(0, signal.SIGTERM)
    sys.exit()

# Prevent the program to break the original file
def copySeedFile(seed_path):
    tmpfile_path = "/tmp/.showmap-tmpfile-%s" % (md5(seed_path.encode("utf-8")).hexdigest())
    try:
        copyfile(seed_path, tmpfile_path)
    except IOError as e:
        print("Unable to copy the seed file %s: %s" % (seed_path, e))
        exit(1)
    except:
        print("Unexpected error:", sys.exc_info())
        exit(1)
    return tmpfile_path

def executeStub(stub):
    if not os.path.exists(stub.split(" ")[0]):
        print("ELF not found: %s" % (stub.split(" ")[0]))
        exit(1)
    find_seed_result = re.findall(r'output_\S+/id:\S+', stub)
    tmpfile_path = None
    seed_path = None
    if len(find_seed_result) > 0:
        seed_path = find_seed_result[0]
        tmpfile_path = copySeedFile(seed_path)
        stub = stub.replace(seed_path, tmpfile_path)

    execution_cmd = ("timeout %d %s" % (timeout_seconds, stub))
    # args = [e.strip() for e in re.sub(' +', ' ', execution_cmd).split(" ") if len(e) != 0 and not e.isspace()]
    args = shlex.split(execution_cmd)
    p = subprocess.Popen(args, stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, preexec_fn=os.setsid)
    try:
        p.communicate(timeout=timeout_seconds)
    except subprocess.TimeoutExpired:
        os.killpg(p.pid, signal.SIGKILL)
    except subprocess.SubprocessError as e:
        print(e.cmd)


    if tmpfile_path and os.path.exists(tmpfile_path):
        os.remove(tmpfile_path)

    return

def calibrateMapSize(stub):
    global MAP_SIZE
    err = None
    my_env = os.environ.copy()
    my_env["AFL_DEBUG"] = "1"
    args = shlex.split(stub)
    p = subprocess.Popen(args, stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, preexec_fn=os.setsid, env=my_env)
    try:
        _, err = p.communicate(timeout=timeout_seconds)
    except subprocess.TimeoutExpired:
        os.killpg(p.pid, signal.SIGKILL)
    except subprocess.SubprocessError as e:
        print(e.cmd)
    if err:
        find_map_result = re.compile("__afl_map_size(?:\s*=\s*|\s+)(\d+)").findall(err.decode("cp850"))
        if len(find_map_result) > 0:
            MAP_SIZE = int(max(find_map_result))
    return

def parseArguments():
    parser = argparse.ArgumentParser(description="Parse stub file and count the coverage of all stubs.")
    parser.add_argument("-b", dest="cpu_ids", help="Bind the subprocesses to the specified CPU core, e.g., \"-b 0-3\" or \"-b 0,1,2,3\".(default=0-`os.cpu_count()`)", required=False, default="0-%d" % os.cpu_count())

    args = parser.parse_args()

    cpu_ids = args.cpu_ids

    return cpu_ids

def parseCoreArgument(str):
    core_list = []
    for s in str.split(","):
        if "-" in s:
            tmp_list = range(int(s.split("-")[0]), int(s.split("-")[1]) + 1)
            for ele in tmp_list:
                core_list.append(ele)
        else:
            core_list.append(int(s))
    return core_list

if __name__ == "__main__":

    core_ids = parseArguments()
    
    core_list = parseCoreArgument(core_ids)

    os.sched_setaffinity(0, core_list)

    stub_files_list = os.listdir(stubs_dir)
    stub_files_list.sort()

    for stub_file in stub_files_list:
        if stub_file.startswith("."):
            continue
        print("[*] Processing %s ..." % stub_file)

        program, fuzzer, index = stub_file.split("_")
        
        stub_file_path = os.path.join(stubs_dir, stub_file)
        output_path = os.path.join(coverage_dir, stub_file)
        
        with open(stub_file_path, "r") as f:
            stub_list = [stub for stub in f.read().splitlines() if len(stub) > 0 and not stub.isspace()]

        if program == "editcap":
            os.environ['AFL_IGNORE_PROBLEMS']="1"

        os.environ['LD_LIBRARY_PATH'] = "%s:%s" % (os.path.abspath(os.path.join(stub_list[0].split(" ")[0], "../../", "lib")), os.environ.get('LD_LIBRARY_PATH'))

        calibrateMapSize(stub_list[0].split(" ")[0])
        print("[*] Target Map Size: %d" % (MAP_SIZE))

        shm = SharedMemory(IPC_PRIVATE, flags=IPC_CREX, mode=0o600, size=MAP_SIZE, init_character=b'\x00')

        os.environ['__AFL_SHM_ID'] = str(shm.id)
        os.environ['AFL_MAP_SIZE'] = str(MAP_SIZE)

        shm_content = shm.read()

        assert shm_content == bytes([0] * MAP_SIZE)

        with Pool(processes=len(os.sched_getaffinity(0))) as p:
            p.map(executeStub, stub_list)

        shm_content = shm.read()

        shm.detach()
        shm.remove()

        if shm_content[0] == 0:
            print("[ERROR] No coverage detected!")
            exit(1)

        bitmap = []
        for i in range(1, MAP_SIZE):
            if shm_content[i] == 0:
                continue
            if not edges_only_flag:
                bitmap.append("%06d:%d" % (i, int(shm_content[i])))
            else:
                bitmap.append("%06d:%d" % (i, 1))

        with open(output_path, "w") as f:
            f.write("\n".join(bitmap))  

        print("[+] Captured %d tuples." % (len(bitmap)))

    os.killpg(0, signal.SIGTERM)