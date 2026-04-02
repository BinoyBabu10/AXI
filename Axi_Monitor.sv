// ============================================================
// axi_monitor.sv  –  UVM monitor for AXI4 slave DUT
// Observes both write and read channels and broadcasts
// completed transactions on the analysis port.
// ============================================================
class axi_monitor extends uvm_monitor;
  `uvm_component_utils(axi_monitor)

  virtual axi_if vif;
  uvm_analysis_port #(axi_seq_item) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db #(virtual axi_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "axi_monitor: virtual interface not found")
  endfunction

  task run_phase(uvm_phase phase);
    fork
      monitor_write();
      monitor_read();
    join
  endtask

  // ----------------------------------------------------------
  // Observe write address + data + response channels
  // ----------------------------------------------------------
  task monitor_write();
    axi_seq_item txn;
    forever begin
      // Wait for AW handshake
      @(vif.monitor_cb iff (vif.monitor_cb.awvalid && vif.monitor_cb.awready));
      txn            = axi_seq_item::type_id::create("wr_txn");
      txn.kind       = axi_seq_item::AXI_WRITE;
      txn.id         = vif.monitor_cb.awid;
      txn.addr       = vif.monitor_cb.awaddr;
      txn.burst_len  = vif.monitor_cb.awlen;
      txn.burst_size = vif.monitor_cb.awsize;
      txn.burst_type = vif.monitor_cb.awburst;
      txn.wdata      = new[txn.burst_len + 1];
      txn.wstrb      = new[txn.burst_len + 1];

      // Collect write data beats
      for (int i = 0; i <= txn.burst_len; i++) begin
        @(vif.monitor_cb iff (vif.monitor_cb.wvalid && vif.monitor_cb.wready));
        txn.wdata[i] = vif.monitor_cb.wdata;
        txn.wstrb[i] = vif.monitor_cb.wstrb;
      end

      // Collect write response
      @(vif.monitor_cb iff (vif.monitor_cb.bvalid && vif.monitor_cb.bready));
      txn.bresp = vif.monitor_cb.bresp;

      ap.write(txn);
    end
  endtask

  // ----------------------------------------------------------
  // Observe read address + data channels
  // ----------------------------------------------------------
  task monitor_read();
    axi_seq_item txn;
    forever begin
      // Wait for AR handshake
      @(vif.monitor_cb iff (vif.monitor_cb.arvalid && vif.monitor_cb.arready));
      txn            = axi_seq_item::type_id::create("rd_txn");
      txn.kind       = axi_seq_item::AXI_READ;
      txn.id         = vif.monitor_cb.arid;
      txn.addr       = vif.monitor_cb.araddr;
      txn.burst_len  = vif.monitor_cb.arlen;
      txn.burst_size = vif.monitor_cb.arsize;
      txn.burst_type = vif.monitor_cb.arburst;
      txn.rdata      = new[txn.burst_len + 1];
      txn.rresp      = new[txn.burst_len + 1];
      txn.wdata      = new[0];
      txn.wstrb      = new[0];

      // Collect read data beats
      for (int i = 0; i <= txn.burst_len; i++) begin
        @(vif.monitor_cb iff (vif.monitor_cb.rvalid && vif.monitor_cb.rready));
        txn.rdata[i] = vif.monitor_cb.rdata;
        txn.rresp[i] = vif.monitor_cb.rresp;
      end

      ap.write(txn);
    end
  endtask

endclass : axi_monitor
