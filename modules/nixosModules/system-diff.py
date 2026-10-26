import json
import re
import subprocess
import sys

SECTIONS = {
    "Version changes:": ("~", "33"),
    "Added packages:": ("+", "32"),
    "Removed packages:": ("-", "31"),
    "Selection state changes:": None,
}
ENTRY = re.compile(r"^\[.(.)\]\s+#\d+\s+(\S+)\s+(.*)$")
colour = sys.stdout.isatty()


def paint(code, text):
    return f"\033[{code}m{text}\033[0m" if colour else text


def diff(label, old, new):
    print(paint("1", f"==> {label}"))
    if old == new:
        print("    unchanged")
        return

    out = subprocess.run(
        ["nvd", "--color", "never", "diff", old, new],
        capture_output=True, text=True,
    )
    if out.returncode:
        print(f"    nvd failed: {out.stderr.strip()}")
        return

    rows, summary, section = [], None, None
    for line in out.stdout.splitlines():
        if line in SECTIONS:
            section = SECTIONS[line]
        elif line.startswith("Closure size:"):
            summary = line
        elif (m := ENTRY.match(line)) and section:
            selected, name, version = m.groups()
            # Generated units and config files carry no version, just noise.
            if version != "<none>" or selected in "*+":
                rows.append((section, name, version))

    width = max((len(name) for _, name, _ in rows), default=0)
    for (sign, code), name, version in rows:
        print(f"    {paint(code, sign)} {name.ljust(width)}  {version}")
    if not rows:
        print("    no package changes")
    if summary:
        print(paint("2", f"    {summary}"))


def scan(paths):
    out = subprocess.run(
        ["vulnix", "--closure", "--json", *paths], capture_output=True, text=True,
    )
    # Exit code 2 can mean vulnerabilities were found; only errors leave stdout empty.
    if out.returncode not in (0, 2) or not out.stdout.strip():
        raise RuntimeError((out.stderr.strip().splitlines() or [f"exit code {out.returncode}"])[-1])
    return [
        [cve, entry["pname"], entry["cvssv3_basescore"].get(cve)]
        for entry in json.loads(out.stdout)
        for cve in entry["affected_by"]
    ]


def cves(olds, news):
    print(paint("1", "==> CVEs"))
    try:
        found = [scan(olds), scan(news)]
    except Exception as e:
        print(f"    vulnix failed: {e}")
        return
    old, new = ({(cve, pname): score for cve, pname, score in f} for f in found)

    old_ids = {cve for cve, _ in old}
    new_ids = {cve for cve, _ in new}
    rows = 0
    for sign, code, found, gone in [("\u2713", "32", old, new_ids), ("!", "31", new, old_ids)]:
        packages = {}
        for (cve, pname), score in found.items():
            if cve not in gone:
                packages.setdefault(pname, []).append((score or 0, cve))
        width = max(map(len, packages), default=0)
        for pname, found_cves in sorted(packages.items()):
            found_cves.sort(reverse=True)
            shown = ", ".join(f"{cve} ({score})" for score, cve in found_cves[:3])
            if len(found_cves) > 3:
                shown += f", +{len(found_cves) - 3} more"
            print(f"    {paint(code, sign)} {pname.ljust(width)}  {shown}")
            rows += 1
    if not rows:
        print("    no CVE changes")
    high = len({cve for (cve, _), score in new.items() if (score or 0) >= 7})
    print(paint("2", f"    {len(new_ids)} known CVEs remain, {high} rated 7.0 or higher."))


args = sys.argv[1:]
if not args or len(args) % 3:
    sys.exit("usage: system-diff <label> <old> <new>...")
triples = [args[i:i + 3] for i in range(0, len(args), 3)]
for label, old, new in triples:
    diff(label, old, new)
if any(old != new for _, old, new in triples):
    cves([old for _, old, _ in triples], [new for _, _, new in triples])
