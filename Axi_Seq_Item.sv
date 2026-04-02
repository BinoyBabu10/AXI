// ============================================================
// axi_seq_item.sv  –  UVM sequence item for AXI4 transactions
// ============================================================
class axi_seq_item extends uvm_sequence_item;
  `uvm_object_utils(axi_seq_item)

  // ----------------------------------------------------------
  // Transaction kind
  // ----------------------------------------------------------
  typedef enum { AXI_WRITE, AXI_READ } axi_txn_kind_e;
  rand axi_txn_kind_e kind;

  // ----------------------------------------------------------
  // Address / burst fields
  // ----------------------------------------------------------
  rand logic [3:0]  id;
  rand logic [31:0] addr;
  rand logic [3:0]  burst_len;   // actual beats = burst_len + 1
  rand logic [2:0]  burst_size;  // bytes per beat = 2^burst_size
  rand logic [1:0]  burst_type;  // 0=FIXED 1=INCR 2=WRAP

  // ----------------------------------------------------------
  // Write data (one entry per beat; max 16 beats)
  // ----------------------------------------------------------
  rand logic [31:0] wdata [];
  rand logic [3:0]  wstrb [];

  // ----------------------------------------------------------
  // Response fields (driven by monitor, not randomised)
  // ----------------------------------------------------------
  logic [1:0]  bresp;
  logic [31:0] rdata [];
  logic [1:0]  rresp [];

  // ----------------------------------------------------------
  // Constraints
  // ----------------------------------------------------------
  // Keep addresses inside the 128-byte memory window
  constraint c_addr        { addr       inside {[32'h0000_0000 : 32'h0000_007C]}; }
  // Limit bursts to fit inside memory
  constraint c_burst_len   { burst_len  inside {[0:3]}; }
  // Only byte/halfword/word transfers
  constraint c_burst_size  { burst_size inside {3'b000, 3'b001, 3'b010}; }
  // All three burst types
  constraint c_burst_type  { burst_type inside {2'b00, 2'b01, 2'b10}; }
  // WRAP requires power-of-2 length (2,4,8,16 beats)
  constraint c_wrap_len    {
    (burst_type == 2'b10) -> burst_len inside {4'h1, 4'h3, 4'h7, 4'hF};
  }
  // Data array size == number of beats
  constraint c_wdata_size  {
    wdata.size() == burst_len + 1;
    wstrb.size() == burst_len + 1;
  }
  // At least one byte active per strobe
  constraint c_wstrb       { foreach (wstrb[i]) wstrb[i] != 4'b0000; }
  // Align address for WRAP bursts
  constraint c_wrap_align  {
    (burst_type == 2'b10) ->
      (addr % ((burst_len + 1) * (1 << burst_size)) == 0);
  }

  // ----------------------------------------------------------
  function new(string name = "axi_seq_item");
    super.new(name);
  endfunction

  // ----------------------------------------------------------
  function void do_copy(uvm_object rhs);
    axi_seq_item rhs_;
    super.do_copy(rhs);
    if (!$cast(rhs_, rhs))
      `uvm_fatal("CAST", "do_copy cast failed")
    kind       = rhs_.kind;
    id         = rhs_.id;
    addr       = rhs_.addr;
    burst_len  = rhs_.burst_len;
    burst_size = rhs_.burst_size;
    burst_type = rhs_.burst_type;
    wdata      = rhs_.wdata;
    wstrb      = rhs_.wstrb;
    bresp      = rhs_.bresp;
    rdata      = rhs_.rdata;
    rresp      = rhs_.rresp;
  endfunction

  function bit do_compare(uvm_object rhs, uvm_comparer comparer);
    axi_seq_item rhs_;
    if (!$cast(rhs_, rhs)) return 0;
    return (super.do_compare(rhs, comparer) &&
            kind       === rhs_.kind       &&
            id         === rhs_.id         &&
            addr       === rhs_.addr       &&
            burst_len  === rhs_.burst_len  &&
            burst_size === rhs_.burst_size &&
            burst_type === rhs_.burst_type);
  endfunction

  function string convert2string();
    string s;
    s = $sformatf("[%s] id=%0h addr=%08h len=%0d size=%0d burst=%0d",
                  (kind == AXI_WRITE) ? "WR" : "RD",
                  id, addr, burst_len, burst_size, burst_type);
    if (kind == AXI_WRITE) begin
      foreach (wdata[i])
        s = {s, $sformatf(" D[%0d]=%08h/S=%04b", i, wdata[i], wstrb[i])};
      s = {s, $sformatf(" bresp=%02b", bresp)};
    end else begin
      foreach (rdata[i])
        s = {s, $sformatf(" R[%0d]=%08h/rresp=%02b", i, rdata[i], rresp[i])};
    end
    return s;
  endfunction

endclass : axi_seq_item
