#!/usr/bin/env python3
import argparse, json, os, signal, socket, struct, sys, threading, time

p = argparse.ArgumentParser()
p.add_argument("--sock", required=True)
p.add_argument("--run-dir", required=True)
p.add_argument("--scenario", default="ok")
p.add_argument("--ttl", type=float, default=40.0)
p.add_argument("--password", default="testpass")
p.add_argument("--exit-grace", type=float, default=5.0)
p.add_argument("--no-exit-after-session", action="store_true")
args = p.parse_args()

run_dir = os.path.realpath(args.run_dir)
sock_path = os.path.abspath(args.sock)
if not os.path.realpath(os.path.dirname(sock_path)).startswith(run_dir + os.sep) \
        and os.path.realpath(os.path.dirname(sock_path)) != run_dir:
    sys.exit("REFUSING: socket must be inside --run-dir")
if sock_path.startswith("/run/") or "greetd.sock" in os.path.basename(sock_path):
    sys.exit("REFUSING: that looks like the real greetd socket")

LOG = open(os.path.join(run_dir, "mock_greetd.log"), "a", buffering=1)
EVT = open(os.path.join(run_dir, "events.jsonl"), "a", buffering=1)
lock = threading.Lock()
checks = {"session_created": False, "auth_succeeded": False,
          "start_session_received": False, "greeter_exited_after_start": None,
          "password_sent_to_nonsecret_prompt": False,
          "cancel_session_seen": False, "protocol_violations": []}
done = threading.Event()
t0 = time.time()

def log(msg):
    with lock:
        LOG.write(f"[{time.time()-t0:6.2f}s] {msg}\n")

def evt(kind, **kw):
    with lock:
        EVT.write(json.dumps({"t": round(time.time()-t0, 3), "kind": kind, **kw}) + "\n")

def redact(req):
    r = dict(req)
    if "response" in r and r["response"] is not None:
        r["response"] = f"<redacted len={len(str(r['response']))}>"
    return r

def recv_exact(conn, n):
    buf = b""
    while len(buf) < n:
        chunk = conn.recv(n - len(buf))
        if not chunk:
            return None
        buf += chunk
    return buf

def read_msg(conn):
    hdr = recv_exact(conn, 4)
    if hdr is None:
        return None
    (n,) = struct.unpack("=I", hdr)
    if n > 1 << 20:
        raise ValueError("oversized message")
    body = recv_exact(conn, n)
    return None if body is None else json.loads(body.decode("utf-8"))

def send_msg(conn, obj):
    data = json.dumps(obj).encode("utf-8")
    conn.sendall(struct.pack("=I", len(data)) + data)
    evt("reply", msg=obj)
    log(f"-> {json.dumps(obj)}")

def prompts_for(scn):
    if scn == "otp":
        return [("secret", "Password:"), ("visible", "Code:")]
    if scn == "info":
        return [("info", "Touch your security key (mock)"), ("secret", "Password:")]
    return [("secret", "Password:")]

def handle(conn):
    attempts = 0
    prompts, idx = [], 0
    try:
        while not done.is_set():
            req = read_msg(conn)
            if req is None:
                log("client closed connection")
                evt("client_closed")
                return "closed"
            log(f"<- {json.dumps(redact(req))}")
            evt("request", msg=redact(req))
            t = req.get("type")

            if t == "create_session":
                checks["session_created"] = True
                if not isinstance(req.get("username"), str) or not req["username"]:
                    checks["protocol_violations"].append("create_session without username")
                if args.scenario == "hang":
                    log("scenario=hang: not replying"); done.wait(); return "hang"
                if args.scenario == "drop":
                    log("scenario=drop: closing"); return "dropped"
                attempts += 1
                prompts, idx = prompts_for(args.scenario), 0
                kind, text = prompts[0]
                send_msg(conn, {"type": "auth_message", "auth_message_type": kind, "auth_message": text})

            elif t == "post_auth_message_response":
                if not prompts:
                    checks["protocol_violations"].append("response without pending prompt")
                    send_msg(conn, {"type": "error", "error_type": "error", "description": "no auth in progress"})
                    continue
                kind, _ = prompts[idx]
                resp = req.get("response")
                if kind in ("info", "error") and resp is not None:
                    checks["protocol_violations"].append(f"non-null response to {kind} message")
                if kind != "secret" and resp == args.password:
                    checks["password_sent_to_nonsecret_prompt"] = True
                    log("!!! SECURITY: password was sent to a non-secret prompt")
                ok = True
                if kind == "secret":
                    ok = (resp == args.password)
                    if args.scenario == "fail_then_ok" and attempts == 1:
                        ok = False
                elif kind == "visible":
                    ok = (resp == "123456")
                if not ok:
                    prompts = []
                    send_msg(conn, {"type": "error", "error_type": "auth_error",
                                    "description": "Authentication failed"})
                    continue
                idx += 1
                if idx < len(prompts):
                    k2, t2 = prompts[idx]
                    send_msg(conn, {"type": "auth_message", "auth_message_type": k2, "auth_message": t2})
                else:
                    checks["auth_succeeded"] = True
                    prompts = []
                    send_msg(conn, {"type": "success"})

            elif t == "cancel_session":
                checks["cancel_session_seen"] = True
                prompts = []
                send_msg(conn, {"type": "success"})

            elif t == "start_session":
                checks["start_session_received"] = True
                cmd, env = req.get("cmd"), req.get("env", [])
                if not (isinstance(cmd, list) and cmd and all(isinstance(c, str) for c in cmd)):
                    checks["protocol_violations"].append("start_session cmd must be non-empty list of strings")
                if not (isinstance(env, list) and all(isinstance(e, str) and "=" in e for e in env)):
                    checks["protocol_violations"].append("start_session env must be list of KEY=VALUE strings")
                if not checks["auth_succeeded"]:
                    send_msg(conn, {"type": "error", "error_type": "error", "description": "not authenticated"})
                    continue
                if args.scenario == "start_error":
                    send_msg(conn, {"type": "error", "error_type": "error", "description": "mock: cannot start session"})
                    continue
                send_msg(conn, {"type": "success"})
                # Real greetd expects the greeter to terminate right after this.
                conn.settimeout(args.exit_grace)
                try:
                    data = conn.recv(1)
                    exited = (data == b"")
                except socket.timeout:
                    exited = False
                checks["greeter_exited_after_start"] = exited
                log("GREETER EXITED after start_session -> session would start now" if exited
                    else f"FAIL: greeter still connected {args.exit_grace}s after start_session")
                evt("greeter_exit_check", exited=exited)
                return "session_concluded"
            else:
                send_msg(conn, {"type": "error", "error_type": "error", "description": "unknown request"})
    except socket.timeout:
        log("client idle timeout")
        return "idle"
    except Exception as e:
        log(f"connection error: {e!r}")
        checks["protocol_violations"].append(f"exception: {e!r}")
        return "error"
    finally:
        try: conn.close()
        except Exception: pass

def finish(reason):
    if done.is_set():
        return
    done.set()
    c = checks
    if c["password_sent_to_nonsecret_prompt"] or c["protocol_violations"]:
        result = "FAIL"
    elif args.scenario in ("ok", "otp", "info", "fail_then_ok"):
        result = "PASS" if (c["start_session_received"] and c["greeter_exited_after_start"]) else "FAIL"
    elif args.scenario == "start_error":
        result = "PASS" if c["auth_succeeded"] and c["start_session_received"] else "FAIL"
    else:  # hang / drop: pass means the mock survived; greeter-side behaviour is read from the qs log
        result = "INFO"
    v = {"scenario": args.scenario, "result": result, "reason": reason,
         "elapsed_s": round(time.time() - t0, 2), "checks": c}
    with open(os.path.join(run_dir, "verdict.json"), "w") as f:
        json.dump(v, f, indent=2)
    log(f"VERDICT {result} ({reason})")

def main():
    if os.path.exists(sock_path):
        os.unlink(sock_path)
    srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    old = os.umask(0o177)
    srv.bind(sock_path)
    os.umask(old)
    os.chmod(sock_path, 0o600)
    srv.listen(4)
    srv.settimeout(0.25)
    log(f"mock greetd v2 listening on {sock_path} scenario={args.scenario} ttl={args.ttl}s")
    signal.signal(signal.SIGTERM, lambda *_: (finish("SIGTERM"), os._exit(0)))
    deadline = t0 + args.ttl
    while time.time() < deadline and not done.is_set():
        try:
            conn, _ = srv.accept()
        except socket.timeout:
            continue
        conn.settimeout(20)
        log("--- new connection ---")
        def run(c=conn):
            outcome = handle(c)
            if outcome == "session_concluded" and not args.no_exit_after_session:
                time.sleep(1.0)
                finish("session concluded")
        threading.Thread(target=run, daemon=True).start()
    finish("ttl reached" if not done.is_set() else "done")
    try: os.unlink(sock_path)
    except OSError: pass
    LOG.flush()
    os._exit(0)

if __name__ == "__main__":
    main()
