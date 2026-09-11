#!/usr/bin/env python3
"""
Generate a contributor stats snippet for the README.

Queries the GitHub API for the ladybug-me/caelestia-dots-kde repository and
counts issues and pull requests authored by each contributor.  Outputs a
Markdown table suitable for pasting between the <!-- contributors-start -->
and <!-- contributors-end --> markers in README.md.

Usage:
    python3 .github/scripts/contributors.py                    # print table only
    python3 .github/scripts/contributors.py --update-readme    # update README.md in-place
    python3 .github/scripts/contributors.py --json             # machine-readable output
"""

import json
import os
import re
import sys
import urllib.request
from collections import defaultdict

REPO = "ladybug-me/caelestia-dots-kde"
API_BASE = f"https://api.github.com/repos/{REPO}"
HEADERS = {
    "User-Agent": "caelestia-contributors-script",
    "Accept": "application/vnd.github+json",
}

# Accounts to exclude from the contributor list (bots, maintainers who prefer
# not to appear in the counts, etc.).
EXCLUDED_LOGINS = {
    "0xSolanaceae",
    "ladybug-me",
    "Copilot",
    "dependabot[bot]",
    "dependabot-preview[bot]",
    "github-actions[bot]",
    "renovate[bot]",
    "imgbot[bot]",
    "pre-commit-ci[bot]",
    "caelestia-automation[bot]",
}


def api_fetch(url: str) -> list[dict]:
    """Fetch all pages from a paginated GitHub API endpoint."""
    results: list[dict] = []
    page = 1
    while True:
        sep = "&" if "?" in url else "?"
        paged = f"{url}{sep}per_page=100&page={page}&state=all&sort=created&direction=desc"
        req = urllib.request.Request(paged, headers=HEADERS)
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                data = json.loads(resp.read().decode("utf-8"))
        except Exception as e:
            print(f"[warn] Failed to fetch page {page}: {e}", file=sys.stderr)
            break

        if not data:
            break
        results.extend(data)
        if len(data) < 100:
            break
        page += 1
    return results


def collect_contributors() -> list[dict[str, int | str]]:
    """
    Return a list of contributor dicts sorted by total contributions
    (issues + PRs) descending.  Each dict has keys:
        login, issues, prs, total
    """
    issues_raw = api_fetch(f"{API_BASE}/issues")
    pulls_raw = api_fetch(f"{API_BASE}/pulls")

    counts: defaultdict[str, dict[str, int]] = defaultdict(
        lambda: {"issues": 0, "prs": 0}
    )

    # PRs also appear in the /issues endpoint, so only count non-PR items
    # from /issues.  /pulls gives us the authoritative PR list.
    for item in issues_raw:
        login = (item.get("user") or {}).get("login", "")
        if not login or login in EXCLUDED_LOGINS:
            continue
        # Skip items that are actually PRs (they have a pull_request key).
        if "pull_request" in item:
            continue
        counts[login]["issues"] += 1

    for pr in pulls_raw:
        login = (pr.get("user") or {}).get("login", "")
        if not login or login in EXCLUDED_LOGINS:
            continue
        counts[login]["prs"] += 1

    contributors: list[dict[str, int | str]] = []
    for login, stats in counts.items():
        contributors.append(
            {
                "login": login,
                "issues": stats["issues"],
                "prs": stats["prs"],
                "total": stats["issues"] + stats["prs"],
            }
        )

    contributors.sort(key=lambda c: c["total"], reverse=True)  # type: ignore[arg-type, return-value]
    return contributors


TOP_N = 8


def _contributor_link(login: str) -> str:
    return f"[{login}](https://github.com/{login})"


def format_markdown(contributors: list[dict[str, int | str]]) -> str:
    """Return side-by-side Markdown tables: overall top 8 + issues leaderboard."""
    if not contributors:
        return "_No contributions found._\n"

    by_prs = sorted(contributors, key=lambda c: c["prs"], reverse=True)  # type: ignore[arg-type, return-value]
    top_prs = by_prs[:TOP_N]
    by_issues = sorted(contributors, key=lambda c: c["issues"], reverse=True)  # type: ignore[arg-type, return-value]
    top_issues = by_issues[:TOP_N]

    def prs_table() -> str:
        lines = [
            "| Contributor | PRs |",
            "| --- | ---: |",
        ]
        for c in top_prs:
            login = str(c['login']) if c['prs'] > 0 else ""
            link = _contributor_link(login) if login else "—"
            lines.append(
                f"| {link} | {c['prs']} |"
            )
        if not top_prs:
            lines.append("| — | — |")
        return "\n".join(lines)

    def issues_table() -> str:
        lines = [
            "| Contributor | Issues |",
            "| --- | ---: |",
        ]
        for c in top_issues:
            lines.append(
                f"| {_contributor_link(str(c['login']))} | {c['issues']} |"
            )
        if not top_issues:
            lines.append("| — | — |")
        return "\n".join(lines)

    return (
        '<table><tr>\n'
        f'<td width="50%">\n\n### PRs\n\n{prs_table()}\n\n</td>\n'
        f'<td width="50%">\n\n### Issues\n\n{issues_table()}\n\n</td>\n'
        '</tr></table>\n'
    )


START_MARKER = "<!-- contributors-start -->"
END_MARKER = "<!-- contributors-end -->"


def update_readme(readme_path: str, table: str):
    """Replace the region between START_MARKER and END_MARKER in the README."""
    with open(readme_path, "r", encoding="utf-8") as f:
        content = f.read()

    new_block = f"{START_MARKER}\n{table}\n{END_MARKER}"
    pattern = re.compile(
        re.escape(START_MARKER) + r".*?" + re.escape(END_MARKER), re.DOTALL
    )

    if pattern.search(content):
        updated = pattern.sub(new_block.replace("\\", "\\\\"), content)
    else:
        # If markers don't exist yet, insert before the Credits section.
        for anchor in ("## Credits", "## License"):
            idx = content.find(anchor)
            if idx != -1:
                section_start = content.rfind("\n", 0, idx)
                if section_start == -1:
                    section_start = idx
                updated = (
                    content[:section_start]
                    + f"\n\n## Thanks to\n\n{new_block}\n"
                    + content[section_start:]
                )
                break
        else:
            updated = content + f"\n## Thanks to\n\n{new_block}\n"

    with open(readme_path, "w", encoding="utf-8") as f:
        f.write(updated)

    print(f"Updated {readme_path}")


def main():
    import argparse

    parser = argparse.ArgumentParser(
        description="Generate contributor stats for the Caelestia README"
    )
    parser.add_argument(
        "--update-readme",
        action="store_true",
        help="Update README.md in-place",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output machine-readable JSON",
    )
    args = parser.parse_args()

    contributors = collect_contributors()

    if args.json:
        json.dump(contributors, sys.stdout, indent=2)
        return

    table = format_markdown(contributors)
    if args.update_readme:
        repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        readme_path = os.path.join(repo_root, "README.md")
        update_readme(readme_path, table)
    else:
        print(table)


if __name__ == "__main__":
    main()
