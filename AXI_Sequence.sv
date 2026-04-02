// ============================================================
// axi_sequences.sv  –  All test sequences
// ============================================================

// ------------------------------------------------------------
// Base sequence
// ------------------------------------------------------------
class axi_base_seq extends uvm_sequence #(axi_seq_item);
  `uvm_object_utils(axi_base_seq)
  function new(string name = "axi_base_seq"); super.new(name); endfunction
endclass

// ------------------------------------------------------------
// Single write sequence
// ------------------------------------------------------------
class axi_write_seq extends axi_base_seq;
  `uvm_object_utils(axi_write_seq)

  rand logic [31:0] addr;
  rand logic [31:0] data;
  rand logic [3:0]  wstrb;
  rand logic [3:0]  id;

  constraint c_addr  { addr  inside {[32'h0:32'h7C]}; }
  constraint c_wstrb { wstrb != 4'b0000; }

  function new(string name = "axi_write_seq"); super.new(name); endfunction

  task body();
    axi_seq_item item;
    item = axi_seq_item::type_id::create("item");
    start_item(item);
    if (!item.randomize() with {
      kind       == axi_seq_item::AXI_WRITE;
      burst_type == 2'b01;  // INCR
      burst_len  == 4'h0;   // single beat
      burst_size == 3'b010; // 4 bytes
      addr       == local::addr;
      wdata[0]   == local::data;
      wstrb[0]   == local::wstrb;
      id         == local::id;
    }) `uvm_fatal("RAND", "Randomisation failed in axi_write_seq")
    finish_item(item);
  endtask
endclass

// ------------------------------------------------------------
// Single read sequence
// ------------------------------------------------------------
class axi_read_seq extends axi_base_seq;
  `uvm_object_utils(axi_read_seq)

  rand logic [31:0] addr;
  rand logic [3:0]  id;

  constraint c_addr { addr inside {[32'h0:32'h7C]}; }

  function new(string name = "axi_read_seq"); super.new(name); endfunction

  task body();
    axi_seq_item item;
    item = axi_seq_item::type_id::create("item");
    start_item(item);
    if (!item.randomize() with {
      kind       == axi_seq_item::AXI_READ;
      burst_type == 2'b01;
      burst_len  == 4'h0;
      burst_size == 3'b010;
      addr       == local::addr;
      id         == local::id;
    }) `uvm_fatal("RAND", "Randomisation failed in axi_read_seq")
    finish_item(item);
  endtask
endclass

// ------------------------------------------------------------
// Write-then-read-back sequence (verifies written data)
// ------------------------------------------------------------
class axi_wr_rd_seq extends axi_base_seq;
  `uvm_object_utils(axi_wr_rd_seq)

  int unsigned num_txns;
  function new(string name = "axi_wr_rd_seq");
    super.new(name);
    num_txns = 8;
  endfunction

  task body();
    axi_seq_item wr_item, rd_item;
    logic [31:0] addrs[$];
    logic [31:0] base_a;

    // Write a set of word-aligned locations
    for (int i = 0; i < num_txns; i++) begin
      base_a = (i * 4) % 128;
      wr_item = axi_seq_item::type_id::create($sformatf("wr_%0d", i));
      start_item(wr_item);
      if (!wr_item.randomize() with {
        kind       == axi_seq_item::AXI_WRITE;
        burst_type == 2'b01;
        burst_len  == 4'h0;
        burst_size == 3'b010;
        addr       == base_a;
        wstrb[0]   == 4'b1111;
      }) `uvm_fatal("RAND", "Write randomise failed")
      finish_item(wr_item);
      addrs.push_back(base_a);
    end

    // Read back every address
    foreach (addrs[i]) begin
      rd_item = axi_seq_item::type_id::create($sformatf("rd_%0d", i));
      start_item(rd_item);
      if (!rd_item.randomize() with {
        kind       == axi_seq_item::AXI_READ;
        burst_type == 2'b01;
        burst_len  == 4'h0;
        burst_size == 3'b010;
        addr       == addrs[i];
      }) `uvm_fatal("RAND", "Read randomise failed")
      finish_item(rd_item);
    end
  endtask
endclass

// ------------------------------------------------------------
// INCR burst write + read sequence
// ------------------------------------------------------------
class axi_incr_burst_seq extends axi_base_seq;
  `uvm_object_utils(axi_incr_burst_seq)

  function new(string name = "axi_incr_burst_seq"); super.new(name); endfunction

  task body();
    axi_seq_item wr_item, rd_item;

    // 4-beat INCR write starting at 0x00
    wr_item = axi_seq_item::type_id::create("incr_wr");
    start_item(wr_item);
    if (!wr_item.randomize() with {
      kind       == axi_seq_item::AXI_WRITE;
      burst_type == 2'b01;
      burst_len  == 4'h3;   // 4 beats
      burst_size == 3'b010; // 4 bytes each
      addr       == 32'h00;
      foreach (wstrb[i]) wstrb[i] == 4'b1111;
    }) `uvm_fatal("RAND", "INCR write randomise failed")
    finish_item(wr_item);

    // Read back with same parameters
    rd_item = axi_seq_item::type_id::create("incr_rd");
    start_item(rd_item);
    if (!rd_item.randomize() with {
      kind       == axi_seq_item::AXI_READ;
      burst_type == 2'b01;
      burst_len  == 4'h3;
      burst_size == 3'b010;
      addr       == 32'h00;
    }) `uvm_fatal("RAND", "INCR read randomise failed")
    finish_item(rd_item);
  endtask
endclass

// ------------------------------------------------------------
// FIXED burst sequence
// ------------------------------------------------------------
class axi_fixed_burst_seq extends axi_base_seq;
  `uvm_object_utils(axi_fixed_burst_seq)

  function new(string name = "axi_fixed_burst_seq"); super.new(name); endfunction

  task body();
    axi_seq_item wr_item, rd_item;

    // 4-beat FIXED write – all beats to same address
    wr_item = axi_seq_item::type_id::create("fixed_wr");
    start_item(wr_item);
    if (!wr_item.randomize() with {
      kind       == axi_seq_item::AXI_WRITE;
      burst_type == 2'b00;  // FIXED
      burst_len  == 4'h3;
      burst_size == 3'b010;
      addr       == 32'h10;
      foreach (wstrb[i]) wstrb[i] == 4'b1111;
    }) `uvm_fatal("RAND", "FIXED write randomise failed")
    finish_item(wr_item);

    // Single read from same address (reads last written value)
    rd_item = axi_seq_item::type_id::create("fixed_rd");
    start_item(rd_item);
    if (!rd_item.randomize() with {
      kind       == axi_seq_item::AXI_READ;
      burst_type == 2'b01;
      burst_len  == 4'h0;
      burst_size == 3'b010;
      addr       == 32'h10;
    }) `uvm_fatal("RAND", "FIXED read randomise failed")
    finish_item(rd_item);
  endtask
endclass

// ------------------------------------------------------------
// WRAP burst sequence
// ------------------------------------------------------------
class axi_wrap_burst_seq extends axi_base_seq;
  `uvm_object_utils(axi_wrap_burst_seq)

  function new(string name = "axi_wrap_burst_seq"); super.new(name); endfunction

  task body();
    axi_seq_item wr_item, rd_item;

    // 4-beat WRAP, 4-byte transfers: boundary = 4*4 = 16 bytes
    // Starting address must be boundary-aligned: use 0x20 (32)
    wr_item = axi_seq_item::type_id::create("wrap_wr");
    start_item(wr_item);
    if (!wr_item.randomize() with {
      kind       == axi_seq_item::AXI_WRITE;
      burst_type == 2'b10;  // WRAP
      burst_len  == 4'h3;   // 4 beats
      burst_size == 3'b010; // 4 bytes
      addr       == 32'h20; // aligned to 16-byte boundary
      foreach (wstrb[i]) wstrb[i] == 4'b1111;
    }) `uvm_fatal("RAND", "WRAP write randomise failed")
    finish_item(wr_item);

    // Read back the full wrapped region
    rd_item = axi_seq_item::type_id::create("wrap_rd");
    start_item(rd_item);
    if (!rd_item.randomize() with {
      kind       == axi_seq_item::AXI_READ;
      burst_type == 2'b10;
      burst_len  == 4'h3;
      burst_size == 3'b010;
      addr       == 32'h20;
    }) `uvm_fatal("RAND", "WRAP read randomise failed")
    finish_item(rd_item);
  endtask
endclass

// ------------------------------------------------------------
// Fully randomised stress sequence
// ------------------------------------------------------------
class axi_random_seq extends axi_base_seq;
  `uvm_object_utils(axi_random_seq)

  int unsigned num_txns;
  function new(string name = "axi_random_seq");
    super.new(name);
    num_txns = 20;
  endfunction

  task body();
    axi_seq_item item;
    for (int i = 0; i < num_txns; i++) begin
      item = axi_seq_item::type_id::create($sformatf("rnd_%0d", i));
      start_item(item);
      if (!item.randomize())
        `uvm_fatal("RAND", $sformatf("Randomisation failed at iteration %0d", i))
      finish_item(item);
    end
  endtask
endclass

// ------------------------------------------------------------
// Strobe corner-case sequence (all 15 non-zero strobe patterns)
// ------------------------------------------------------------
class axi_strobe_seq extends axi_base_seq;
  `uvm_object_utils(axi_strobe_seq)

  function new(string name = "axi_strobe_seq"); super.new(name); endfunction

  task body();
    axi_seq_item wr_item, rd_item;
    for (int strb = 1; strb < 16; strb++) begin
      wr_item = axi_seq_item::type_id::create($sformatf("strb_wr_%0d", strb));
      start_item(wr_item);
      if (!wr_item.randomize() with {
        kind       == axi_seq_item::AXI_WRITE;
        burst_type == 2'b01;
        burst_len  == 4'h0;
        burst_size == 3'b010;
        addr       == 32'h40;
        wstrb[0]   == strb[3:0];
      }) `uvm_fatal("RAND", "strobe write randomise failed")
      finish_item(wr_item);

      rd_item = axi_seq_item::type_id::create($sformatf("strb_rd_%0d", strb));
      start_item(rd_item);
      if (!rd_item.randomize() with {
        kind       == axi_seq_item::AXI_READ;
        burst_type == 2'b01;
        burst_len  == 4'h0;
        burst_size == 3'b010;
        addr       == 32'h40;
      }) `uvm_fatal("RAND", "strobe read randomise failed")
      finish_item(rd_item);
    end
  endtask
endclass
