// ============================================================
// tb_top.sv  –  Top-level testbench module
// ============================================================
`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"
import axi_tb_pkg::*;

module tb_top;

  // ----------------------------------------------------------
  // Clock and reset generation
  // ----------------------------------------------------------
  logic clk;
  logic resetn;

  initial clk = 0;
  always #5 clk = ~clk;  // 100 MHz

  initial begin
    resetn = 0;
    repeat(10) @(posedge clk);
    resetn = 1;
  end

  // ----------------------------------------------------------
  // Interface instance
  // ----------------------------------------------------------
  axi_if axi_bus (.clk(clk), .resetn(resetn));

  // ----------------------------------------------------------
  // DUT instance
  // ----------------------------------------------------------
  axi_slave dut (
    .clk      (clk),
    .resetn   (resetn),
    // Write address channel
    .awvalid  (axi_bus.awvalid),
    .awready  (axi_bus.awready),
    .awid     (axi_bus.awid),
    .awlen    (axi_bus.awlen),
    .awsize   (axi_bus.awsize),
    .awaddr   (axi_bus.awaddr),
    .awburst  (axi_bus.awburst),
    // Write data channel
    .wvalid   (axi_bus.wvalid),
    .wready   (axi_bus.wready),
    .wid      (axi_bus.wid),
    .wdata    (axi_bus.wdata),
    .wstrb    (axi_bus.wstrb),
    .wlast    (axi_bus.wlast),
    // Write response channel
    .bready   (axi_bus.bready),
    .bvalid   (axi_bus.bvalid),
    .bid      (axi_bus.bid),
    .bresp    (axi_bus.bresp),
    // Read address channel
    .arready  (axi_bus.arready),
    .arid     (axi_bus.arid),
    .araddr   (axi_bus.araddr),
    .arlen    (axi_bus.arlen),
    .arsize   (axi_bus.arsize),
    .arburst  (axi_bus.arburst),
    .arvalid  (axi_bus.arvalid),
    // Read data channel
    .rid      (axi_bus.rid),
    .rdata    (axi_bus.rdata),
    .rresp    (axi_bus.rresp),
    .rlast    (axi_bus.rlast),
    .rvalid   (axi_bus.rvalid),
    .rready   (axi_bus.rready)
  );

  // ----------------------------------------------------------
  // Pass interface to UVM config_db and start UVM
  // ----------------------------------------------------------
  initial begin
    uvm_config_db #(virtual axi_if)::set(null, "uvm_test_top.*", "vif", axi_bus);
    run_test();   // test name passed via +UVM_TESTNAME on command line
  end

  // ----------------------------------------------------------
  // Optional: VCD dump
  // ----------------------------------------------------------
  initial begin
    if ($test$plusargs("DUMP")) begin
      $dumpfile("axi_slave.vcd");
      $dumpvars(0, tb_top);
    end
  end

  // ----------------------------------------------------------
  // Timeout watchdog
  // ----------------------------------------------------------
  initial begin
    #500000;
    `uvm_fatal("TIMEOUT", "Simulation timeout after 500us")
  end

endmodule : tb_top
