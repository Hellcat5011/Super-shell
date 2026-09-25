#!/usr/bin/env python3
import os, subprocess, time, json, sys

scenarios = ["ok", "fail_then_ok", "otp", "info", "start_error", "hang", "drop"]
sock_path = os.path.abspath("mock.sock")
fake_hyprctl = os.path.abspath("fake_hyprctl.sh")

with open(fake_hyprctl, "w") as f:
    f.write("#!/bin/sh\n")
    f.write('echo "$@" >> exit_cmd_log.txt\n')
os.chmod(fake_hyprctl, 0o755)

for scenario in scenarios:
    print(f"=== Testing scenario: {scenario} ===")
    
    if os.path.exists("exit_cmd_log.txt"):
        os.unlink("exit_cmd_log.txt")
    if os.path.exists(sock_path):
        os.unlink(sock_path)
    
    # Start mock
    mock = subprocess.Popen([
        sys.executable, "mock_greetd_v2.py", 
        "--sock", sock_path, 
        "--run-dir", os.getcwd(), 
        "--scenario", scenario
    ])
    
    # Wait for mock to be ready
    time.sleep(0.5)
    
    env = os.environ.copy()
    env["GREETD_SOCK"] = sock_path
    env["GREETER_EXIT_CMD"] = json.dumps([fake_hyprctl, "dispatch", "exit"])
    
    helper = subprocess.Popen([
        sys.executable, "greet-helper.py", "tester", "echo", "session_started"
    ], env=env, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    
    out, err = helper.communicate(input="testpass\n")
    mock.wait()
    
    print("Helper STDOUT:", out.strip())
    print("Helper STDERR:", err.strip())
    
    if os.path.exists("exit_cmd_log.txt"):
        with open("exit_cmd_log.txt") as f:
            print("Exit CMD log:", f.read().strip())
    else:
        print("Exit CMD log: [not created]")
    
    if os.path.exists("verdict.json"):
        with open("verdict.json") as f:
            v = json.load(f)
            print("Verdict:", v["result"], "-", v["reason"])
    print("-" * 40)
