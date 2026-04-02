// ============================================================
// axi_tests.sv  –  All UVM tests
// ============================================================

// ------------------------------------------------------------
// Base test
// ------------------------------------------------------------
class axi_base_test extends uvm_test;
  `uvm_component_utils(axi_base_test)

  axi_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = axi_env::type_id::create("env", this);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    run_test_body(phase);
    #100;
    phase.drop_objection(this);
  endtask

  // Override in derived tests
  virtual task run_test_body(uvm_phase phase);
  endtask

  function void report_phase(uvm_phase phase);
    uvm_report_server svr = uvm_report_server::get_server();
    if (svr.get_severity_count(UVM_ERROR) == 0)
      `uvm_info("TEST", "*** TEST PASSED ***", UVM_NONE)
    else
      `uvm_error("TEST", "*** TEST FAILED ***")
  endfunction
endclass

// ------------------------------------------------------------
// Write-read test: single transactions
// ------------------------------------------------------------
class axi_wr_rd_test extends axi_base_test;
  `uvm_component_utils(axi_wr_rd_test)

  function new(string name, uvm_component parent); super.new(name, parent); endfunction

  virtual task run_test_body(uvm_phase phase);
    axi_wr_rd_seq seq;
    seq = axi_wr_rd_seq::type_id::create("seq");
    seq.num_txns = 10;
    seq.start(env.agent.seqr);
  endtask
endclass

// ------------------------------------------------------------
// INCR burst test
// ------------------------------------------------------------
class axi_incr_test extends axi_base_test;
  `uvm_component_utils(axi_incr_test)

  function new(string name, uvm_component parent); super.new(name, parent); endfunction

  virtual task run_test_body(uvm_phase phase);
    axi_incr_burst_seq seq;
    seq = axi_incr_burst_seq::type_id::create("seq");
    seq.start(env.agent.seqr);
  endtask
endclass

// ------------------------------------------------------------
// FIXED burst test
// ------------------------------------------------------------
class axi_fixed_test extends axi_base_test;
  `uvm_component_utils(axi_fixed_test)

  function new(string name, uvm_component parent); super.new(name, parent); endfunction

  virtual task run_test_body(uvm_phase phase);
    axi_fixed_burst_seq seq;
    seq = axi_fixed_burst_seq::type_id::create("seq");
    seq.start(env.agent.seqr);
  endtask
endclass

// ------------------------------------------------------------
// WRAP burst test
// ------------------------------------------------------------
class axi_wrap_test extends axi_base_test;
  `uvm_component_utils(axi_wrap_test)

  function new(string name, uvm_component parent); super.new(name, parent); endfunction

  virtual task run_test_body(uvm_phase phase);
    axi_wrap_burst_seq seq;
    seq = axi_wrap_burst_seq::type_id::create("seq");
    seq.start(env.agent.seqr);
  endtask
endclass

// ------------------------------------------------------------
// Strobe corner-case test
// ------------------------------------------------------------
class axi_strobe_test extends axi_base_test;
  `uvm_component_utils(axi_strobe_test)

  function new(string name, uvm_component parent); super.new(name, parent); endfunction

  virtual task run_test_body(uvm_phase phase);
    axi_strobe_seq seq;
    seq = axi_strobe_seq::type_id::create("seq");
    seq.start(env.agent.seqr);
  endtask
endclass

// ------------------------------------------------------------
// Full random stress test
// ------------------------------------------------------------
class axi_random_test extends axi_base_test;
  `uvm_component_utils(axi_random_test)

  function new(string name, uvm_component parent); super.new(name, parent); endfunction

  virtual task run_test_body(uvm_phase phase);
    axi_random_seq seq;
    seq = axi_random_seq::type_id::create("seq");
    seq.num_txns = 50;
    seq.start(env.agent.seqr);
  endtask
endclass

// ------------------------------------------------------------
// Regression test: runs all sequences back-to-back
// ------------------------------------------------------------
class axi_regression_test extends axi_base_test;
  `uvm_component_utils(axi_regression_test)

  function new(string name, uvm_component parent); super.new(name, parent); endfunction

  virtual task run_test_body(uvm_phase phase);
    axi_wr_rd_seq       wr_rd_seq;
    axi_incr_burst_seq  incr_seq;
    axi_fixed_burst_seq fixed_seq;
    axi_wrap_burst_seq  wrap_seq;
    axi_strobe_seq      strobe_seq;
    axi_random_seq      rand_seq;

    `uvm_info("REGR", "Starting regression", UVM_NONE)

    wr_rd_seq  = axi_wr_rd_seq      ::type_id::create("wr_rd_seq");
    incr_seq   = axi_incr_burst_seq ::type_id::create("incr_seq");
    fixed_seq  = axi_fixed_burst_seq::type_id::create("fixed_seq");
    wrap_seq   = axi_wrap_burst_seq ::type_id::create("wrap_seq");
    strobe_seq = axi_strobe_seq     ::type_id::create("strobe_seq");
    rand_seq   = axi_random_seq     ::type_id::create("rand_seq");

    wr_rd_seq.num_txns  = 8;
    rand_seq.num_txns   = 30;

    wr_rd_seq .start(env.agent.seqr);
    incr_seq  .start(env.agent.seqr);
    fixed_seq .start(env.agent.seqr);
    wrap_seq  .start(env.agent.seqr);
    strobe_seq.start(env.agent.seqr);
    rand_seq  .start(env.agent.seqr);

    `uvm_info("REGR", "Regression complete", UVM_NONE)
  endtask
endclass
