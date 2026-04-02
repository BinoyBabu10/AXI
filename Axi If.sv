// ============================================================
// axi_if.sv  –  AXI4 interface (write + read channels)
// ============================================================
interface axi_if (input logic clk, input logic resetn);

  // ----------------------------------------------------------
  // Write address channel
  // ----------------------------------------------------------
  logic        awvalid;
  logic        awready;
  logic [3:0]  awid;
  logic [3:0]  awlen;
  logic [2:0]  awsize;
  logic [31:0] awaddr;
  logic [1:0]  awburst;

  // ----------------------------------------------------------
  // Write data channel
  // ----------------------------------------------------------
  logic        wvalid;
  logic        wready;
  logic [3:0]  wid;
  logic [31:0] wdata;
  logic [3:0]  wstrb;
  logic        wlast;

  // ----------------------------------------------------------
  // Write response channel
  // ----------------------------------------------------------
  logic        bready;
  logic        bvalid;
  logic [3:0]  bid;
  logic [1:0]  bresp;

  // ----------------------------------------------------------
  // Read address channel
  // ----------------------------------------------------------
  logic        arvalid;
  logic        arready;
  logic [3:0]  arid;
  logic [31:0] araddr;
  logic [3:0]  arlen;
  logic [2:0]  arsize;
  logic [1:0]  arburst;

  // ----------------------------------------------------------
  // Read data channel
  // ----------------------------------------------------------
  logic        rready;
  logic        rvalid;
  logic [3:0]  rid;
  logic [31:0] rdata;
  logic [1:0]  rresp;
  logic        rlast;

  // ----------------------------------------------------------
  // Master clocking block  (driver drives on negedge, samples on posedge)
  // ----------------------------------------------------------
  clocking master_cb @(posedge clk);
    default input #1 output #1;
    // Write address
    output awvalid, awid, awlen, awsize, awaddr, awburst;
    input  awready;
    // Write data
    output wvalid, wid, wdata, wstrb, wlast;
    input  wready;
    // Write response
    output bready;
    input  bvalid, bid, bresp;
    // Read address
    output arvalid, arid, araddr, arlen, arsize, arburst;
    input  arready;
    // Read data
    output rready;
    input  rvalid, rid, rdata, rresp, rlast;
  endclocking

  // ----------------------------------------------------------
  // Monitor clocking block  (sample only)
  // ----------------------------------------------------------
  clocking monitor_cb @(posedge clk);
    default input #1;
    input awvalid, awready, awid, awlen, awsize, awaddr, awburst;
    input wvalid,  wready,  wid,  wdata, wstrb,  wlast;
    input bready,  bvalid,  bid,  bresp;
    input arvalid, arready, arid, araddr, arlen,  arsize, arburst;
    input rready,  rvalid,  rid,  rdata, rresp,  rlast;
  endclocking

  modport MASTER  (clocking master_cb,  input clk, resetn);
  modport MONITOR (clocking monitor_cb, input clk, resetn);

endinterface : axi_if
