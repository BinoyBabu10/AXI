// ============================================================
// axi_tb_pkg.sv  –  UVM package (include order matters)
// ============================================================
package axi_tb_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  `include "axi_seq_item.sv"
  `include "axi_driver.sv"
  `include "axi_monitor.sv"
  `include "axi_agent.sv"
  `include "axi_scoreboard.sv"
  `include "axi_env.sv"
  `include "axi_sequences.sv"
  `include "axi_tests.sv"

endpackage : axi_tb_pkg
