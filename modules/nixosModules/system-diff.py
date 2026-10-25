import re
import subprocess
import sys

SECTIONS = {
    "Version changes:": ("~", "33"),
    "Added packages:": ("+", "32"),
    "Removed packages:": ("-", "31"),
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
        check=True, capture_output=True, text=True,
    ).stdout

    rows, summary, section = [], None, None
    for line in out.splitlines():
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


args = sys.argv[1:]
if not args or len(args) % 3:
    sys.exit("usage: system-diff <label> <old> <new> [<label> <old> <new>...]")
for i in range(0, len(args), 3):
    diff(*args[i:i + 3])
