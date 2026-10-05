#!/usr/bin/env python3
"""End-to-end check of the auth slice against a running API.

Usage: API_BASE_URL=http://localhost:4000/api/v1 python3 scripts/smoke_check.py
Expects the seed admin (SEED_ADMIN_EMAIL / SEED_ADMIN_PASSWORD, defaults below).
"""
import json
import os
import sys
import urllib.error
import urllib.request
import uuid

API = os.environ.get("API_BASE_URL", "http://localhost:4000/api/v1")
ADMIN_EMAIL = os.environ.get("SEED_ADMIN_EMAIL", "admin@example.com")
ADMIN_PASSWORD = os.environ.get("SEED_ADMIN_PASSWORD", "ChangeMe-123")
failures = []


def call(method, path, body=None, token=None, ip=None):
    data = None if body is None else json.dumps(body).encode()
    request = urllib.request.Request(API + path, data=data, method=method)
    request.add_header("Content-Type", "application/json")
    if token:
        request.add_header("Authorization", "Bearer " + token)
    if ip:
        request.add_header("X-Forwarded-For", ip)
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return response.status, json.loads(response.read() or b"null")
    except urllib.error.HTTPError as error:
        return error.code, json.loads(error.read() or b"null")


def expect(label, response, status, error=None):
    code, body = response
    ok = code == status and (error is None or (body or {}).get("error") == error)
    print(("  ok   " if ok else "  FAIL ") + label + ("" if ok else f" -> {code} {body}"))
    if not ok:
        failures.append(label)
    return body


suffix = uuid.uuid4().hex[:8]
email = f"Smoke.{suffix}@Example.com"
signup = expect("signup", call("POST", "/auth/signup", {"name": "Smoke Tester", "email": email, "password": "password-1"}, ip=f"10.9.{suffix[:2]}.1"), 200)
token = signup["token"]
expect("email normalised", (200 if signup["user"]["email"] == email.lower() else 500, None), 200)
expect("duplicate signup", call("POST", "/auth/signup", {"name": "Smoke Tester", "email": email, "password": "password-1"}), 409, "An account with this email already exists")
expect("invalid email", call("POST", "/auth/signup", {"name": "Smoke Tester", "email": "nope", "password": "password-1"}), 400, "Enter a valid email address")
expect("GET /me", call("GET", "/me", token=token), 200)
expect("GET /me without token", call("GET", "/me"), 401, "Please log in again")
expect("PATCH /me", call("PATCH", "/me", {"name": "Smoke Renamed"}, token=token), 200)
expect("wrong current password", call("PATCH", "/me", {"currentPassword": "nope-nope", "newPassword": "password-2"}, token=token), 400, "Current password is incorrect")
expect("change password", call("PATCH", "/me", {"currentPassword": "password-1", "newPassword": "password-2"}, token=token), 200)
expect("wrong password login", call("POST", "/auth/login", {"email": email, "password": "password-1"}), 401, "Email or password is incorrect")
member = expect("login", call("POST", "/auth/login", {"email": email, "password": "password-2"}), 200)
expect("member blocked from admin", call("GET", "/admin/users", token=member["token"]), 403, "Not allowed for this account")
expect("logout", call("POST", "/auth/logout", token=token), 200)
expect("revoked token rejected", call("GET", "/me", token=token), 401)
admin = expect("admin login", call("POST", "/auth/login", {"email": ADMIN_EMAIL, "password": ADMIN_PASSWORD}), 200)
users = expect("list users", call("GET", "/admin/users?limit=5", token=admin["token"]), 200)
expect("new member listed", (200 if any(u["id"] == member["user"]["id"] for u in users) else 500, None), 200)
expect("admin cannot suspend self", call("PATCH", f"/admin/users/{admin['user']['id']}", {"status": "suspended"}, token=admin["token"]), 409, "You cannot suspend your own account")
expect("suspend member", call("PATCH", f"/admin/users/{member['user']['id']}", {"status": "suspended"}, token=admin["token"]), 200)
expect("suspended sessions revoked", call("GET", "/me", token=member["token"]), 401)
expect("suspended login refused", call("POST", "/auth/login", {"email": email, "password": "password-2"}), 403, "Account suspended. Contact support.")
expect("unknown route", call("GET", "/nope"), 404, "Not found")
codes = [call("POST", "/auth/login", {"email": f"throttle.{suffix}@example.com", "password": "wrong-pass"})[0] for _ in range(11)]
expect("11th login attempt throttled", (200 if codes[:10] == [401] * 10 and codes[10] == 429 else 500, None), 200)

print(f"\n{len(failures)} failed" if failures else "\nall checks passed")
sys.exit(1 if failures else 0)
