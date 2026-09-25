#!/usr/bin/env python3
"""
greet-helper.py - bridges a Quickshell greeter to greetd over its IPC socket.
"""
import json, os, socket, struct, sys, subprocess

TIMEOUT_S = 10
MAX_PROMPTS = 5

def send_msg(sock, obj):
    body = json.dumps(obj).encode("utf-8")
    sock.sendall(struct.pack("=I", len(body)) + body)

def recv_exact(sock, n):
    buf = b""
    while len(buf) < n:
        chunk = sock.recv(n - len(buf))
        if not chunk:
            raise ConnectionError("greetd closed the socket")
        buf += chunk
    return buf

def recv_msg(sock):
    (length,) = struct.unpack("=I", recv_exact(sock, 4))
    if length > 1 << 20:
        raise ValueError("oversized message from greetd")
    return json.loads(recv_exact(sock, length).decode("utf-8"))

def fail(reason):
    print(f"FAIL:{reason}")
    sys.exit(1)

def run_exit_cmd():
    raw = os.environ.get("GREETER_EXIT_CMD", "")
    if not raw:
        print("WARN: GREETER_EXIT_CMD not set - greeter will NOT self-terminate; "
              "greetd is waiting for this process's compositor to exit.",
              file=sys.stderr)
        return
    try:
        cmd = json.loads(raw)
        subprocess.run(cmd, timeout=5, check=True)
    except Exception as e:
        print(f"WARN: GREETER_EXIT_CMD failed ({e!r}); greeter may hang on "
              f"'starting session'", file=sys.stderr)

def main():
    if len(sys.argv) < 3:
        fail("usage: greet-helper.py <username> <session_cmd...>")
    username = sys.argv[1]
    session_cmd = sys.argv[2:]
    password = sys.stdin.readline().rstrip("\n")

    sock_path = os.environ.get("GREETD_SOCK")
    if not sock_path:
        fail("GREETD_SOCK not set - this must be run inside a greetd session")

    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.settimeout(TIMEOUT_S)
    cancelled = False
    try:
        sock.connect(sock_path)
        send_msg(sock, {"type": "create_session", "username": username})
        resp = recv_msg(sock)

        prompts = 0
        while resp.get("type") == "auth_message":
            prompts += 1
            if prompts > MAX_PROMPTS:
                send_msg(sock, {"type": "cancel_session"}); cancelled = True
                fail(f"too many auth prompts ({prompts}), aborting")
            kind = resp.get("auth_message_type")
            if kind == "secret":
                send_msg(sock, {"type": "post_auth_message_response", "response": password})
            elif kind in ("info", "error"):
                send_msg(sock, {"type": "post_auth_message_response"})
            else:
                send_msg(sock, {"type": "cancel_session"}); cancelled = True
                fail(f"unsupported auth prompt type '{kind}' - cannot answer "
                     f"automatically (this greeter only handles a single "
                     f"secret/password prompt)")
            resp = recv_msg(sock)

        if resp.get("type") == "error":
            fail(resp.get("description", "auth error"))
        if resp.get("type") != "success":
            fail(f"unexpected response after auth: {resp}")

        send_msg(sock, {"type": "start_session", "cmd": session_cmd})
        resp = recv_msg(sock)
        if resp.get("type") == "error":
            fail(resp.get("description", "start_session error"))
        if resp.get("type") != "success":
            fail(f"unexpected response to start_session: {resp}")

        run_exit_cmd()
        print("OK")
    except Exception as e:
        if not cancelled:
            try:
                send_msg(sock, {"type": "cancel_session"})
            except Exception:
                pass
        fail(str(e))
    finally:
        try:
            sock.close()
        except Exception:
            pass

if __name__ == "__main__":
    main()
