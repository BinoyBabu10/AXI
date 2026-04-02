// ============================================================
// axi_scoreboard.sv  –  UVM scoreboard
// Maintains a software model of the 128-byte memory.
// On every write txn: updates the model.
// On every read  txn: compares DUT data against model.
// ============================================================
class axi_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(axi_scoreboard)

  uvm_analysis_imp #(axi_seq_item, axi_scoreboard) analysis_export;

  // Reference memory model (byte-addressable, 128 bytes)
  logic [7:0] ref_mem [0:127];

  int unsigned pass_cnt;
  int unsigned fail_cnt;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_export = new("analysis_export", this);
    foreach (ref_mem[i]) ref_mem[i] = 8'h00;
    pass_cnt = 0;
    fail_cnt = 0;
  endfunction

  // ----------------------------------------------------------
  // Receive and process observed transactions
  // ----------------------------------------------------------
  function void write(axi_seq_item txn);
    if (txn.kind == axi_seq_item::AXI_WRITE)
      process_write(txn);
    else
      process_read(txn);
  endfunction

  // ----------------------------------------------------------
  // Update reference memory for a write transaction
  // ----------------------------------------------------------
  function void process_write(axi_seq_item txn);
    logic [31:0] cur_addr;
    logic [31:0] wrap_base;
    logic [31:0] boundary;
    logic [7:0]  b;

    // Check response
    if (txn.bresp !== 2'b00)
      `uvm_error("SB_BRESP",
        $sformatf("Write bresp=%02b expected OKAY(00) addr=%08h",
                  txn.bresp, txn.addr))

    cur_addr  = txn.addr;
    boundary  = (txn.burst_len + 1) * (1 << txn.burst_size);
    wrap_base = (cur_addr / boundary) * boundary;

    for (int beat = 0; beat <= txn.burst_len; beat++) begin
      // Apply strobe lanes
      for (int lane = 0; lane < 4; lane++) begin
        if (txn.wstrb[beat][lane]) begin
          logic [31:0] byte_addr;
          // Compute per-byte address with wrapping
          case (txn.burst_type)
            2'b00: byte_addr = cur_addr + lane; // FIXED
            2'b01: byte_addr = cur_addr + lane; // INCR
            2'b10: begin // WRAP
              byte_addr = wrap_base +
                          ((cur_addr - wrap_base + lane) % boundary);
            end
            default: byte_addr = cur_addr + lane;
          endcase
          if (byte_addr < 128)
            ref_mem[byte_addr[6:0]] =
              txn.wdata[beat][lane*8 +: 8];
        end
      end
      // Advance address
      case (txn.burst_type)
        2'b00: ; // FIXED: no advance
        2'b01: cur_addr = cur_addr + (1 << txn.burst_size); // INCR
        2'b10: begin // WRAP
          cur_addr = cur_addr + (1 << txn.burst_size);
          if ((cur_addr - wrap_base) >= boundary)
            cur_addr = wrap_base;
        end
        default: ;
      endcase
    end

    `uvm_info("SB_WR",
      $sformatf("Write committed: addr=%08h len=%0d type=%0d",
                txn.addr, txn.burst_len, txn.burst_type), UVM_MEDIUM)
  endfunction

  // ----------------------------------------------------------
  // Compare DUT read data against reference memory
  // ----------------------------------------------------------
  function void process_read(axi_seq_item txn);
    logic [31:0] cur_addr;
    logic [31:0] wrap_base;
    logic [31:0] boundary;
    logic [31:0] exp_word;

    cur_addr  = txn.addr;
    boundary  = (txn.burst_len + 1) * (1 << txn.burst_size);
    wrap_base = (cur_addr / boundary) * boundary;

    for (int beat = 0; beat <= txn.burst_len; beat++) begin
      // Build expected 32-bit word from reference memory
      exp_word = '0;
      for (int lane = 0; lane < 4; lane++) begin
        logic [31:0] byte_addr;
        case (txn.burst_type)
          2'b00: byte_addr = cur_addr + lane;
          2'b01: byte_addr = cur_addr + lane;
          2'b10: byte_addr = wrap_base +
                             ((cur_addr - wrap_base + lane) % boundary);
          default: byte_addr = cur_addr + lane;
        endcase
        if (byte_addr < 128)
          exp_word[lane*8 +: 8] = ref_mem[byte_addr[6:0]];
      end

      // Compare
      if (txn.rdata[beat] !== exp_word) begin
        `uvm_error("SB_RD_MISMATCH",
          $sformatf("Read mismatch beat[%0d]: addr=%08h got=%08h exp=%08h",
                    beat, cur_addr, txn.rdata[beat], exp_word))
        fail_cnt++;
      end else begin
        `uvm_info("SB_RD_OK",
          $sformatf("Read match beat[%0d]: addr=%08h data=%08h",
                    beat, cur_addr, txn.rdata[beat]), UVM_HIGH)
        pass_cnt++;
      end

      if (txn.rresp[beat] !== 2'b00)
        `uvm_error("SB_RRESP",
          $sformatf("rresp=%02b expected OKAY(00) beat=%0d",
                    txn.rresp[beat], beat))

      // Advance expected address
      case (txn.burst_type)
        2'b00: ;
        2'b01: cur_addr = cur_addr + (1 << txn.burst_size);
        2'b10: begin
          cur_addr = cur_addr + (1 << txn.burst_size);
          if ((cur_addr - wrap_base) >= boundary)
            cur_addr = wrap_base;
        end
        default: ;
      endcase
    end
  endfunction

  // ----------------------------------------------------------
  // Report pass/fail summary
  // ----------------------------------------------------------
  function void report_phase(uvm_phase phase);
    `uvm_info("SB_SUMMARY",
      $sformatf("Scoreboard: PASS=%0d  FAIL=%0d", pass_cnt, fail_cnt),
      UVM_NONE)
    if (fail_cnt > 0)
      `uvm_error("SB_FAIL", "One or more scoreboard checks FAILED")
  endfunction

endclass : axi_scoreboard
