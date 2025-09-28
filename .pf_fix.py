#!/usr/bin/env python3
import sys, io, os
p = "/usr/local/bin/pf"
old = (
    "    if op == \"shell\":\n"
    "        cmd = \" \\".join(args)\n"
    "        if not cmd: raise ValueError(\"shell needs a command\")\n"
    "        return run(cmd)\n"
)
new = (
    "    if op == \"shell\":\n"
    "        if not args:\n"
    "            raise ValueError(\"shell needs a command\")\n"
    "        # Preserve quoting for bash/sh -c/-lc: re-quote the command string token\n"
    "        if len(args) >= 3 and args[0] in (\"bash\", \"sh\", \"zsh\") and args[1] in (\"-c\", \"-lc\"):\n"
    "            cmd_str = args[2]\n"
    "            cmd = \"{} {} {}\".format(args[0], args[1], shlex.quote(cmd_str))\n"
    "            if len(args) > 3:\n"
    "                cmd += \" \" + \" \".join(args[3:])\n"
    "        else:\n"
    "            cmd = \" \".join(args)\n"
    "        return run(cmd)\n"
)

def main():
    try:
        s = open(p, "r", encoding="utf-8").read()
    except Exception as e:
        print(f"ERROR: cannot read {p}: {e}", file=sys.stderr)
        sys.exit(1)
    if old not in s:
        print("ERROR: target block not found; aborting", file=sys.stderr)
        sys.exit(2)
    s2 = s.replace(old, new)
    # Write to temp and atomically replace with proper mode
    tmp = "/tmp/pf.patched"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(s2)
    os.chmod(tmp, 0o755)
    os.replace(tmp, p)
    print("Patched /usr/local/bin/pf successfully.")

if __name__ == "__main__":
    main()
