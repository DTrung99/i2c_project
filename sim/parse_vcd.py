# Parse VCD and report timing for tb_i2c
import sys, re, collections

path = "/home/dtrung/Desktop/i2c_project/sim/tb_i2c.vcd"

SIGS = {
    "3":("clk",1), "6":("rst_n",1), "B":("wr_en",1), "5":("rd_en",1),
    "2":("addr",2), "A":("wdata",8), "@":("sr_val",8), "4":("dr_val",8),
    ")":("rdata",8), "!":("scl_fall",1), '"':("scl_rise",1),
    "&":("sda",1), "(":("scl",1),
    "H":("start",1), "E":("write",1), "J":("read",1),
    "i":("done_sticky",1), "g":("ack_err_sticky",1),
    "c":("mstate",4), "O":("busy",1), "<":("srx",8), "o":("pcnt",32),
    ">":("sstate",3), ";":("smatch",1),
}
W = {c:w for c,(_,w) in SIGS.items()}
MST = {0:"IDLE",1:"START",2:"TX_ADDR",3:"ACK_ADDR",4:"TX_DATA",
       5:"ACK_DATA",6:"RX_DATA",7:"ACK_RX",8:"STOP_A",9:"STOP_B",10:"STOP_C"}
SLV = {0:"S_IDLE",1:"S_ADDR",2:"S_ACK_A",3:"S_DATA",
       4:"S_ACK_D",5:"S_RDATA",6:"S_ACK_R"}

def p(v,w):
    if v in "xXzZ": return v*w if w>1 else v
    return v.zfill(w)

vals = {}
prev = {}
t = 0
cr_active = False
out_lines = []

def emit(s):
    out_lines.append(s)

def flush_buf(buf):
    global cr_active
    for c,v in buf:
        vals[c] = v

    # CR write detection
    we = vals.get("B")
    ad = p(vals.get("2",""),2)
    if we == "1" and ad == "00" and not cr_active:
        wd = p(vals.get("A","?"),8)
        emit(f"\n=== CR WRITE @ t={t} ps ({t/1000:.1f} ns) ===")
        emit(f"    wdata=0b{wd}  write={vals.get('E','?')}  read={vals.get('J','?')}  start={vals.get('H','?')}  busy={vals.get('O','?')}")
        cr_active = True
    elif we != "1" or ad != "00":
        cr_active = False

    for c,v in buf:
        pv = prev.get(c)
        if c == "i":
            if pv == "0" and v == "1": emit(f">> done_sticky 0->1  @ t={t} ps ({t/1000:.1f} ns)")
            elif pv == "1" and v == "0": emit(f"   done_sticky 1->0  @ t={t} ps")
            elif pv is None: pass
        elif c == "g":
            if pv == "0" and v == "1": emit(f">> ack_err_sticky 0->1  @ t={t} ps ({t/1000:.1f} ns)")
            elif pv == "1" and v == "0": emit(f"   ack_err_sticky 1->0  @ t={t} ps")
            elif pv is None: pass
        elif c == "O" and pv != v:
            emit(f"   busy -> {v}  @ t={t} ps")
        elif c == "c":
            sv = int(v,2) if v not in "xXzZ" else -1
            emit(f"   master.state = {MST.get(sv,'?')} (0b{p(v,4)})  @ t={t} ps")
        elif c == ">":
            sv = int(v,2) if v not in "xXzZ" else -1
            emit(f"   slave.state = {SLV.get(sv,'?')}  @ t={t} ps")
        elif c == '"' and v == "1": emit(f"   scl_rise  @ t={t} ps")
        elif c == "!" and v == "1": emit(f"   scl_fall  @ t={t} ps")
        elif c == "&" and pv is not None and v != pv: emit(f"   sda -> {v}  @ t={t} ps")
        elif c == "(" and pv is not None and v != pv: emit(f"   scl -> {v}  @ t={t} ps")
        elif c == "@":
            vp = p(v,8)
            emit(f"   sr_val = 0b{vp}  @ t={t} ps")
        elif c == "<":
            tv = int(v,2) if v not in "xXzZ" else -1
            emit(f"   slave_rx_byte = 0b{p(v,8)} (0x{tv:02x})  @ t={t} ps")
        elif c == ";":
            emit(f"   slave.match = {v}  @ t={t} ps")

    for c,v in buf:
        prev[c] = v

buf = []
with open(path) as fh:
    for line in fh:
        line = line.strip()
        if not line: continue
        if line[0] == "#":
            flush_buf(buf)
            t = int(line[1:])
            buf = []
        elif line[0] == "b":
            parts = line.split()
            if len(parts) >= 2 and parts[1] in W:
                buf.append((parts[1], parts[0][1:]))
        elif line[0] in "01xzXZ" and len(line) >= 2 and line[1:] in W:
            buf.append((line[1:], line[0]))
flush_buf(buf)

print("=" * 70)
print("VCD TIMING TRACE  |  tb_i2c.vcd")
print("=" * 70)
print()
for l in out_lines:
    print(l)

print()
print("=" * 70)
print("FINAL VALUES")
print("=" * 70)
for c in sorted(W):
    nm, w = SIGS[c]
    v = p(vals.get(c,"?"), w)
    x = ""
    if c == "c": x = f" ({MST.get(int(vals.get(c,'?'),2) if vals.get(c,'?') not in 'xXzZ' else -1, '?')})"
    if c == ">": x = f" ({SLV.get(int(vals.get(c,'?'),2) if vals.get(c,'?') not in 'xXzZ' else -1, '?')})"
    print(f"  {nm:20s} = {v}{x}")

print()
print("=" * 70)
print("ANSWERS TO YOUR QUESTIONS")
print("=" * 70)
print()
print("Q1: When wr_en=1 and addr=00 (CR write):")
# Find CR writes from output
cr_times = []
for l in out_lines:
    if "CR WRITE" in l:
        # extract time
        m = re.search(r't=(\d+)', l)
        if m:
            cr_times.append(int(m.group(1)))
for l in out_lines:
    if "CR WRITE" in l:
        print(f"  {l}")
        continue
    # print the next few lines after a CR write
    # (skip this, we already have the info)
print()

print("Q2: done_sticky 0->1 transitions:")
for l in out_lines:
    if "done_sticky 0->1" in l:
        print(f"  {l}")

print()
print("Q3: ack_err_sticky 0->1 transitions:")
for l in out_lines:
    if "ack_err_sticky 0->1" in l:
        print(f"  {l}")

print()
print("Q4: FAIL/TIMEOUT are $display() statements in the testbench.")
print("    They DO NOT appear in the VCD. They appear in simulation stdout.")
print("    The VCD shows when conditions for FAIL/TIMEOUT are met:")
print("    - ack_err_sticky set -> FAIL(ack_err) condition met")
print("    - poll_cnt >= 5000 -> TIMEOUT")
print("    - done_sticky NOT set during poll window -> TIMEOUT")
print()
print("KEY INSIGHT: The master samples sda_i on scl_fall (see i2c_master.v:110),")
print("but the slave drives sla_sda_driven via NBA on the same scl_fall.")
print("The NBA hasn't taken effect yet when the master samples -> sees NACK.")
print("This is an RTL vs TB race condition in the slave model.")
