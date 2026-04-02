// ============================================================
// axi_env.sv  –  UVM environment
// ============================================================
class axi_env extends uvm_env;
  `uvm_component_utils(axi_env)

  axi_agent      agent;
  axi_scoreboard sb;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = axi_agent     ::type_id::create("agent", this);
    sb    = axi_scoreboard::type_id::create("sb",    this);
  endfunction

  function void connect_phase(uvm_phase phase);
    agent.ap.connect(sb.analysis_export);
  endfunction

endclass : axi_env
