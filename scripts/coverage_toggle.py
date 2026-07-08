#!/usr/bin/env python3
"""Toggle coverage from VCD — count signal transitions per net."""

import sys, gzip
from collections import defaultdict

def main():
    path = sys.argv[1] if len(sys.argv) > 1 else "sim/tb_i2c.vcd"
    try:
        f = gzip.open(path, "rt") if path.endswith(".gz") else open(path, "r")
    except FileNotFoundError:
        print(f"VCD not found: {path}")
        sys.exit(1)

    symbols, toggles, cur_vals = {}, defaultdict(int), {}
    total_nets = toggled_nets = 0

    for line in f:
        if line.startswith("$var "):
            parts = line.split()
            if len(parts) >= 4:
                symbols[parts[3]] = parts[4]
                total_nets += 1
        elif line[0] in "01xXzZ":
            val, id_ = line[0], line[1:].strip().rstrip()
            if id_ in symbols:
                prev = cur_vals.get(id_)
                if prev is not None and prev != val and prev in "01" and val in "01":
                    if toggles[id_] == 0:
                        toggled_nets += 1
                    toggles[id_] += 1
                cur_vals[id_] = val

    f.close()
    print(f"Total nets: {total_nets}, Toggled: {toggled_nets} ({100*toggled_nets/max(total_nets,1):.1f}%)")
    for id_, cnt in sorted(toggles.items(), key=lambda x: -x[1])[:20]:
        print(f"  {symbols.get(id_, id_):<30s} {cnt:>6d}")

if __name__ == "__main__":
    main()
