#!/usr/bin/env python3
# ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
# ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
# └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
# https://github.com/kbuckleys/
#
# github.py — YOUR GITHUB, for Cynosure's "github …" (2026-11-03): unread
# notifications, your open pull requests, the ones waiting on your review,
# and the issues assigned to you. Through the gh command, signed in as it
# already is (Delphi's way), the four asked at once.
#
#   github.py    { notifications, mine, review, issues } or { error }
#
# Each item: { title, url, repo, number, updated, reason? }. A
# notification's url is the page, not the API's address.

import json
import re
import shutil
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

FIELDS = "title,url,repository,number,updatedAt"


def gh(args):
    r = subprocess.run(["gh"] + args, capture_output=True, text=True, timeout=25)
    if r.returncode != 0:
        raise RuntimeError((r.stderr or "gh failed").strip().splitlines()[-1] if r.stderr.strip() else "gh failed")
    return json.loads(r.stdout or "null")


def found(kind, flags):
    rows = gh(["search", kind] + flags + ["--state=open", "--limit", "30", "--json", FIELDS]) or []
    return [{"title": x.get("title", ""), "url": x.get("url", ""),
             "repo": (x.get("repository") or {}).get("nameWithOwner", ""),
             "number": x.get("number", 0), "updated": x.get("updatedAt", "")} for x in rows]


# "https://api.github.com/repos/o/r/pulls/12" → "https://github.com/o/r/pull/12"
def page_of(subject, repo):
    api = (subject or {}).get("url") or ""
    m = re.match(r"https://api\.github\.com/repos/([^/]+/[^/]+)/(pulls|issues|commits|releases)/(.+)$", api)
    if m:
        kind = {"pulls": "pull", "issues": "issues", "commits": "commit", "releases": "releases"}[m.group(2)]
        # a release's API id is not its tag: the releases page instead
        return "https://github.com/%s/%s" % (m.group(1), "releases" if kind == "releases" else kind + "/" + m.group(3))
    return "https://github.com/" + repo if repo else "https://github.com/notifications"


def notifications():
    rows = gh(["api", "notifications?per_page=30"]) or []
    out = []
    for n in rows:
        repo = (n.get("repository") or {}).get("full_name", "")
        subject = n.get("subject") or {}
        num = re.search(r"/(\d+)$", subject.get("url") or "")
        out.append({"title": subject.get("title", ""), "url": page_of(subject, repo), "repo": repo,
                    "number": int(num.group(1)) if num else 0, "updated": n.get("updated_at", ""),
                    "reason": (n.get("reason") or "").replace("_", " "), "type": subject.get("type", "")})
    return out


def main():
    if not shutil.which("gh"):
        print(json.dumps({"error": "needs gh: pacman -S github-cli"}))
        return
    jobs = {
        "notifications": notifications,
        "mine": lambda: found("prs", ["--author=@me"]),
        "review": lambda: found("prs", ["--review-requested=@me"]),
        "issues": lambda: found("issues", ["--assignee=@me"]),
    }
    out = {}
    try:
        with ThreadPoolExecutor(max_workers=4) as pool:
            futures = {k: pool.submit(f) for k, f in jobs.items()}
            for k, fu in futures.items():
                out[k] = fu.result()
    except (RuntimeError, ValueError, subprocess.TimeoutExpired) as e:
        msg = str(e)
        if "auth" in msg.lower() or "login" in msg.lower():
            msg = "not signed in: gh auth login"
        print(json.dumps({"error": msg}))
        return
    print(json.dumps(out))


if __name__ == "__main__":
    sys.exit(main())
