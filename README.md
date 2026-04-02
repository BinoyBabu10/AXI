# AXI
# AXI4 Slave – UVM Verification Testbench

A complete UVM-1.2 testbench for the `axi_slave` SystemVerilog module.  
Covers all three AXI4 burst types (FIXED, INCR, WRAP), all 15 write-strobe  
combinations, and includes a self-checking scoreboard with a byte-accurate  
reference memory model.

---

## Directory Layout

```
project/
├── axi_slave.sv          ← DUT (lives one level above the tb folder)
└── uvm_tb/
    ├── README.md
    ├── Makefile
    ├── axi_if.sv         ← AXI4 interface + clocking blocks
    ├── axi_tb_pkg.sv     ← Package: imports UVM, includes all TB files
    ├── axi_seq_item.sv   ← Sequence item (transaction descriptor)
    ├── axi_driver.sv     ← UVM driver  – stimulus generation
    ├── axi_monitor.sv    ← UVM monitor – passive observation
    ├── axi_scoreboard.sv ← Self-checking scoreboard + reference model
    ├── axi_agent.sv      ← Active agent (driver + monitor + sequencer)
    ├── axi_env.sv        ← Environment (agent + scoreboard)
    ├── axi_sequences.sv  ← All sequence classes
    ├── axi_tests.sv      ← All test classes
    └── tb_top.sv         ← Top-level module (DUT + interface + UVM start)
```

---

## DUT Overview

`axi_slave` is a 128-byte AXI4 memory slave with:

| Channel | Signals |
|---------|---------|
| Write address (AW) | `awvalid/ready`, `awid[3:0]`, `awaddr[31:0]`, `awlen[3:0]`, `awsize[2:0]`, `awburst[1:0]` |
| Write data (W)     | `wvalid/ready`, `wid[3:0]`, `wdata[31:0]`, `wstrb[3:0]`, `wlast` |
| Write response (B) | `bvalid/ready`, `bid[3:0]`, `bresp[1:0]` |
| Read address (AR)  | `arvalid/ready`, `arid[3:0]`, `araddr[31:0]`, `arlen[3:0]`, `arsize[2:0]`, `arburst[1:0]` |
| Read data (R)      | `rvalid/ready`, `rid[3:0]`, `rdata[31:0]`, `rresp[1:0]`, `rlast` |

**Supported burst types:**

| `awburst` / `arburst` | Type  | Behaviour |
|-----------------------|-------|-----------|
| `2'b00` | FIXED | Every beat accesses the same address |
| `2'b01` | INCR  | Address increments by transfer size each beat |
| `2'b10` | WRAP  | Address increments but wraps at an aligned boundary |

---

## Testbench Architecture

```
tb_top
 └── axi_env
      ├── axi_agent (active)
      │    ├── uvm_sequencer  ←── sequences feed items here
      │    ├── axi_driver     ←── drives AW/W/B and AR/R handshakes
      │    └── axi_monitor    ──► analysis port
      │                              │
      └── axi_scoreboard  ◄──────────┘
           (reference memory model + pass/fail checking)
```

### Component Responsibilities

**`axi_if`**  
SystemVerilog interface holding all AXI signals plus two clocking blocks:
- `master_cb`  – used by the driver (output on negedge, sample on posedge)
- `monitor_cb` – used by the monitor (sample only on posedge)

**`axi_seq_item`**  
The transaction descriptor. Fields cover address, burst parameters, per-beat
write data/strobe arrays, and captured response fields. Key constraints:
- Address kept within `[0x00 : 0x7C]` (128-byte memory window)
- WRAP bursts constrained to power-of-2 lengths and boundary-aligned addresses
- Every strobe has at least one active lane

**`axi_driver`**  
Executes full AXI handshake sequences:
1. Assert AW signals → wait for `awready`
2. Send W beats one per cycle → wait for `wready` each beat, assert `wlast` on final beat
3. Assert `bready` → capture `bresp` on `bvalid`

For reads: assert AR → wait `arready` → assert `rready` → capture each R beat.

**`axi_monitor`**  
Two parallel threads watch write and read channels independently.  
A complete transaction is assembled across all handshakes and broadcast on
`ap` (analysis port) to the scoreboard.

**`axi_scoreboard`**  
Maintains a `ref_mem[0:127]` byte array mirroring the DUT's internal memory.
- **On write:** updates `ref_mem` using the same FIXED/INCR/WRAP address  
  arithmetic as the DUT; checks `bresp == OKAY`.
- **On read:** reconstructs the expected 32-bit word from `ref_mem` for each  
  beat and compares against `rdata`; checks `rresp == OKAY`.
- Prints a `PASS / FAIL` summary in the report phase.

---

## Sequences

| Class | Description |
|-------|-------------|
| `axi_write_seq`       | Single-beat INCR write to a specified address |
| `axi_read_seq`        | Single-beat INCR read from a specified address |
| `axi_wr_rd_seq`       | Write N locations then read them all back |
| `axi_incr_burst_seq`  | 4-beat INCR write + read-back at address `0x00` |
| `axi_fixed_burst_seq` | 4-beat FIXED write + single read at address `0x10` |
| `axi_wrap_burst_seq`  | 4-beat WRAP write + read-back at address `0x20` |
| `axi_strobe_seq`      | All 15 non-zero strobe patterns, write + read-back |
| `axi_random_seq`      | Fully randomised write/read mix (configurable count) |

---

## Tests

| Test | Sequences run | Default txn count |
|------|---------------|-------------------|
| `axi_wr_rd_test`    | `axi_wr_rd_seq`       | 10 write + 10 read |
| `axi_incr_test`     | `axi_incr_burst_seq`  | 1 burst pair |
| `axi_fixed_test`    | `axi_fixed_burst_seq` | 1 burst pair |
| `axi_wrap_test`     | `axi_wrap_burst_seq`  | 1 burst pair |
| `axi_strobe_test`   | `axi_strobe_seq`      | 15 strobe patterns |
| `axi_random_test`   | `axi_random_seq`      | 50 transactions |
| `axi_regression_test` | All of the above in order | ~110 transactions |

---

## Prerequisites

| Tool | Minimum version |
|------|----------------|
| Questa / ModelSim | 10.7 or later |
| Synopsys VCS | 2019.06 or later |
| UVM library | 1.2 (bundled with both tools) |
| SystemVerilog | IEEE 1800-2012 |

---

## Running Simulations

All commands are run from inside the `uvm_tb/` directory.

### Questa / ModelSim

```bash
# Run the full regression (default)
make questa

# Run a specific test
make questa TEST=axi_wrap_test

# Run with a fixed random seed
make questa TEST=axi_random_test SEED=42

# Enable VCD waveform dump
make questa TEST=axi_wr_rd_test EXTRA="+DUMP"
```

### Synopsys VCS

```bash
make vcs TEST=axi_regression_test
make vcs TEST=axi_strobe_test SEED=7
```

### Manual compilation (Questa)

```bash
vlib work
vmap work work

# Compile design
vlog -sv axi_slave.sv

# Compile UVM package and testbench
vlog -sv +incdir+$UVM_HOME/src $UVM_HOME/src/uvm_pkg.sv \
     axi_if.sv axi_tb_pkg.sv tb_top.sv

# Simulate
vsim -c tb_top \
     +UVM_TESTNAME=axi_regression_test \
     +UVM_VERBOSITY=UVM_MEDIUM \
     -sv_seed 1 \
     -do "run -all; quit -f"
```

### Changing verbosity

| Flag | Output level |
|------|-------------|
| `+UVM_VERBOSITY=UVM_NONE`   | Errors and fatals only |
| `+UVM_VERBOSITY=UVM_LOW`    | Minimal progress messages |
| `+UVM_VERBOSITY=UVM_MEDIUM` | Default – scoreboard hits/misses |
| `+UVM_VERBOSITY=UVM_HIGH`   | Every beat comparison |
| `+UVM_VERBOSITY=UVM_DEBUG`  | Full UVM internals |

---

## Scoreboard Output

A passing run ends with:

```
UVM_INFO axi_scoreboard.sv(xx) @ ...: uvm_test_top.env.sb [SB_SUMMARY]
    Scoreboard: PASS=84  FAIL=0
UVM_INFO axi_tests.sv(xx) @ ...: uvm_test_top [TEST]
    *** TEST PASSED ***

--- UVM Report Summary ---
UVM_INFO :   ...
UVM_WARNING :  0
UVM_ERROR :    0
UVM_FATAL :    0
```

A failing run prints a mismatch message per failed beat:

```
UVM_ERROR axi_scoreboard.sv(xx) @ ...: [SB_RD_MISMATCH]
    Read mismatch beat[0]: addr=00000010 got=aabbccdd exp=11223344
```

---

## Extending the Testbench

### Adding a new sequence

```systemverilog
class my_seq extends axi_base_seq;
  `uvm_object_utils(my_seq)
  function new(string name = "my_seq"); super.new(name); endfunction

  task body();
    axi_seq_item item = axi_seq_item::type_id::create("item");
    start_item(item);
    if (!item.randomize() with { kind == axi_seq_item::AXI_WRITE; ... })
      `uvm_fatal("RAND", "failed")
    finish_item(item);
  endtask
endclass
```

Add `\`include "my_seq.sv"` inside `axi_tb_pkg.sv` after `axi_sequences.sv`.

### Adding a new test

```systemverilog
class my_test extends axi_base_test;
  `uvm_component_utils(my_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction

  virtual task run_test_body(uvm_phase phase);
    my_seq seq = my_seq::type_id::create("seq");
    seq.start(env.agent.seqr);
  endtask
endclass
```

Run it with `+UVM_TESTNAME=my_test`.

### Increasing memory size

Change the array size in both `axi_slave.sv` (`mem[0:N-1]`) and  
`axi_scoreboard.sv` (`ref_mem[0:N-1]`), and update the address constraint  
in `axi_seq_item.sv` (`addr inside {[0 : N-4]}`).

---

## Known Limitations

- The DUT memory is 128 bytes. Addresses outside this range are not checked.
- Simultaneous interleaved read and write transactions are not tested  
  (the DUT processes them sequentially by design).
- Out-of-order transaction IDs are not exercised.

---
