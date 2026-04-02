// ============================================================
// axi_agent.sv  –  UVM agent (active)
// ============================================================
class axi_agent extends uvm_agent;
  `uvm_component_utils(axi_agent)

  axi_driver  drv;
  axi_monitor mon;
  uvm_sequencer #(axi_seq_item) seqr;

  uvm_analysis_port #(axi_seq_item) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap   = new("ap", this);
    drv  = axi_driver ::type_id::create("drv",  this);
    mon  = axi_monitor::type_id::create("mon",  this);
    seqr = uvm_sequencer #(axi_seq_item)::type_id::create("seqr", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    drv.seq_item_port.connect(seqr.seq_item_export);
    mon.ap.connect(ap);
  endfunction

endclass : axi_agent
