// ============================================================
// axi_driver.sv  –  UVM driver for AXI4 slave DUT
// ============================================================
class axi_driver extends uvm_driver #(axi_seq_item);
  `uvm_component_utils(axi_driver)

  virtual axi_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual axi_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "axi_driver: virtual interface not found")
  endfunction

  task run_phase(uvm_phase phase);
    axi_seq_item req;
    // Initialise all master outputs to 0
    init_signals();
    // Wait for reset de-assertion
    @(posedge vif.clk iff vif.resetn === 1'b1);
    repeat(2) @(posedge vif.clk);

    forever begin
      seq_item_port.get_next_item(req);
      if (req.kind == axi_seq_item::AXI_WRITE)
        drive_write(req);
      else
        drive_read(req);
      seq_item_port.item_done();
    end
  endtask

  // ----------------------------------------------------------
  // Initialise all master-driven signals
  // ----------------------------------------------------------
  task init_signals();
    vif.master_cb.awvalid <= 0;
    vif.master_cb.awid    <= 0;
    vif.master_cb.awlen   <= 0;
    vif.master_cb.awsize  <= 0;
    vif.master_cb.awaddr  <= 0;
    vif.master_cb.awburst <= 0;
    vif.master_cb.wvalid  <= 0;
    vif.master_cb.wid     <= 0;
    vif.master_cb.wdata   <= 0;
    vif.master_cb.wstrb   <= 0;
    vif.master_cb.wlast   <= 0;
    vif.master_cb.bready  <= 0;
    vif.master_cb.arvalid <= 0;
    vif.master_cb.arid    <= 0;
    vif.master_cb.araddr  <= 0;
    vif.master_cb.arlen   <= 0;
    vif.master_cb.arsize  <= 0;
    vif.master_cb.arburst <= 0;
    vif.master_cb.rready  <= 0;
  endtask

  // ----------------------------------------------------------
  // Drive a complete write transaction (AW + W + B channels)
  // ----------------------------------------------------------
  task drive_write(axi_seq_item req);
    // -- AW channel handshake --
    @(vif.master_cb);
    vif.master_cb.awvalid <= 1;
    vif.master_cb.awid    <= req.id;
    vif.master_cb.awaddr  <= req.addr;
    vif.master_cb.awlen   <= req.burst_len;
    vif.master_cb.awsize  <= req.burst_size;
    vif.master_cb.awburst <= req.burst_type;
    // Wait for awready
    @(vif.master_cb iff vif.master_cb.awready === 1'b1);
    vif.master_cb.awvalid <= 0;

    // -- W channel: send all beats --
    for (int i = 0; i <= req.burst_len; i++) begin
      @(vif.master_cb);
      vif.master_cb.wvalid <= 1;
      vif.master_cb.wid    <= req.id;
      vif.master_cb.wdata  <= req.wdata[i];
      vif.master_cb.wstrb  <= req.wstrb[i];
      vif.master_cb.wlast  <= (i == req.burst_len);
      @(vif.master_cb iff vif.master_cb.wready === 1'b1);
    end
    vif.master_cb.wvalid <= 0;
    vif.master_cb.wlast  <= 0;
    vif.master_cb.wstrb  <= 0;

    // -- B channel: accept response --
    @(vif.master_cb);
    vif.master_cb.bready <= 1;
    @(vif.master_cb iff vif.master_cb.bvalid === 1'b1);
    req.bresp = vif.master_cb.bresp;
    @(vif.master_cb);
    vif.master_cb.bready <= 0;
  endtask

  // ----------------------------------------------------------
  // Drive a complete read transaction (AR + R channels)
  // ----------------------------------------------------------
  task drive_read(axi_seq_item req);
    // -- AR channel handshake --
    @(vif.master_cb);
    vif.master_cb.arvalid <= 1;
    vif.master_cb.arid    <= req.id;
    vif.master_cb.araddr  <= req.addr;
    vif.master_cb.arlen   <= req.burst_len;
    vif.master_cb.arsize  <= req.burst_size;
    vif.master_cb.arburst <= req.burst_type;
    @(vif.master_cb iff vif.master_cb.arready === 1'b1);
    vif.master_cb.arvalid <= 0;

    // -- R channel: receive all beats --
    req.rdata = new[req.burst_len + 1];
    req.rresp = new[req.burst_len + 1];
    for (int i = 0; i <= req.burst_len; i++) begin
      @(vif.master_cb);
      vif.master_cb.rready <= 1;
      @(vif.master_cb iff vif.master_cb.rvalid === 1'b1);
      req.rdata[i] = vif.master_cb.rdata;
      req.rresp[i] = vif.master_cb.rresp;
    end
    @(vif.master_cb);
    vif.master_cb.rready <= 0;
  endtask

endclass : axi_driver
