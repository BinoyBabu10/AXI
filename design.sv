
module axi_slave (
  // Global control signals
  input  logic        clk,
  input  logic        resetn,

  // Write address channel
  input  logic        awvalid,
  output logic        awready,
  input  logic [3:0]  awid,
  input  logic [3:0]  awlen,
  input  logic [2:0]  awsize,
  input  logic [31:0] awaddr,
  input  logic [1:0]  awburst,   // 2'b00=FIXED  2'b01=INCR  2'b10=WRAP

  // Write data channel
  input  logic        wvalid,
  output logic        wready,
  input  logic [3:0]  wid,
  input  logic [31:0] wdata,
  input  logic [3:0]  wstrb,
  input  logic        wlast,

  // Write response channel
  input  logic        bready,
  output logic        bvalid,
  output logic [3:0]  bid,
  output logic [1:0]  bresp,

  // Read address channel
  output logic        arready,
  input  logic [3:0]  arid,
  input  logic [31:0] araddr,
  input  logic [3:0]  arlen,
  input  logic [2:0]  arsize,
  input  logic [1:0]  arburst,
  input  logic        arvalid,

  // Read data channel
  output logic [3:0]  rid,
  output logic [31:0] rdata,
  output logic [1:0]  rresp,
  output logic        rlast,
  output logic        rvalid,
  input  logic        rready
);

  logic [7:0] mem [0:127];

  // =========================================================
  // Latched AW / AR transaction info
  // =========================================================
  logic [31:0] awaddrt;
  logic [3:0]  awidt;
  logic [3:0]  awlent;
  logic [2:0]  awsizet;
  logic [1:0]  awburstt;

  logic [31:0] araddrt;
  logic [3:0]  aridr;
  logic [3:0]  arlenr;
  logic [2:0]  arsizer;
  logic [1:0]  arburstr;

  // =========================================================
  // FSM state types
  // =========================================================
  typedef enum logic [1:0] { AWIDLE=2'b00, AWSTART=2'b01, AWREADY_S=2'b10 } awstate_t;
  typedef enum logic [2:0] { WIDLE=3'd0, WSTART=3'd1, WREADY_S=3'd2, WVALID_S=3'd3 } wstate_t;
  typedef enum logic [1:0] { BIDLE=2'b00, BVALID_S=2'b10 } bstate_t;
  typedef enum logic [1:0] { ARIDLE=2'b00, ARSTART=2'b01, ARREADY_S=2'b10 } arstate_t;
  typedef enum logic [1:0] { RIDLE=2'b00, RVALID_S=2'b01 } rstate_t;

  awstate_t awstate, awnext_state;
  wstate_t  wstate,  wnext_state;
  bstate_t  bstate,  bnext_state;
  arstate_t arstate, arnext_state;
  rstate_t  rstate,  rnext_state;

  // =========================================================
  // Burst counters and address trackers
  // =========================================================
  logic [3:0]  wlen_count;
  logic [3:0]  rlen_count;
  logic [31:0] waddr_cur;
  logic [31:0] raddr_cur;
  logic [7:0]  wboundary;
  logic [7:0]  rboundary;

  // =========================================================
  // Pure helper functions (read-only access to mem[])
  // =========================================================
  function automatic logic [7:0] wrap_boundary (
    input logic [3:0] len_in,
    input logic [2:0] size_in
  );
    return (len_in + 1) << size_in;
  endfunction

  function automatic logic [31:0] data_rd (input logic [31:0] base_addr);
    return { mem[base_addr[6:0]+3],
             mem[base_addr[6:0]+2],
             mem[base_addr[6:0]+1],
             mem[base_addr[6:0]] };
  endfunction

  // =========================================================
  // TASKS – write mem[].
  // Using tasks (not functions) so that mem[] has exactly one
  // procedural driver (the write always_ff block below).
  // next_addr is an output – the caller updates waddr_cur.
  // =========================================================

  // FIXED: address never advances
  task automatic wr_fixed (
    input  logic [3:0]  wstrb_in,
    input  logic [31:0] base_addr,
    input  logic [31:0] wdata_in,
    output logic [31:0] next_addr
  );
    if (wstrb_in[0]) mem[base_addr[6:0]]     <= wdata_in[7:0];
    if (wstrb_in[1]) mem[base_addr[6:0] + 1] <= wdata_in[15:8];
    if (wstrb_in[2]) mem[base_addr[6:0] + 2] <= wdata_in[23:16];
    if (wstrb_in[3]) mem[base_addr[6:0] + 3] <= wdata_in[31:24];
    next_addr = base_addr;
  endtask

  // INCR: advance by transfer width each beat
  task automatic wr_incr (
    input  logic [3:0]  wstrb_in,
    input  logic [31:0] base_addr,
    input  logic [31:0] wdata_in,
    input  logic [2:0]  size_in,
    output logic [31:0] next_addr
  );
    logic [6:0] idx;
    idx = base_addr[6:0];
    if (wstrb_in[0]) mem[idx]     <= wdata_in[7:0];
    if (wstrb_in[1]) mem[idx + 1] <= wdata_in[15:8];
    if (wstrb_in[2]) mem[idx + 2] <= wdata_in[23:16];
    if (wstrb_in[3]) mem[idx + 3] <= wdata_in[31:24];
    next_addr = base_addr + (32'd1 << size_in);
  endtask

  // WRAP: per-byte address wrapping within aligned boundary
  task automatic wr_wrap (
    input  logic [3:0]  wstrb_in,
    input  logic [31:0] base_addr,
    input  logic [31:0] wdata_in,
    input  logic [2:0]  size_in,
    input  logic [7:0]  boundary,
    output logic [31:0] next_addr
  );
    logic [31:0] wrap_base, a0, a1, a2, a3;
    wrap_base = (base_addr / {24'd0, boundary}) * {24'd0, boundary};
    a0 = wrap_base + ((base_addr - wrap_base + 0) % {24'd0, boundary});
    a1 = wrap_base + ((base_addr - wrap_base + 1) % {24'd0, boundary});
    a2 = wrap_base + ((base_addr - wrap_base + 2) % {24'd0, boundary});
    a3 = wrap_base + ((base_addr - wrap_base + 3) % {24'd0, boundary});
    if (wstrb_in[0]) mem[a0[6:0]] <= wdata_in[7:0];
    if (wstrb_in[1]) mem[a1[6:0]] <= wdata_in[15:8];
    if (wstrb_in[2]) mem[a2[6:0]] <= wdata_in[23:16];
    if (wstrb_in[3]) mem[a3[6:0]] <= wdata_in[31:24];
    next_addr = ((base_addr + (32'd1 << size_in) - wrap_base) >= {24'd0, boundary})
                  ? wrap_base
                  : base_addr + (32'd1 << size_in);
  endtask

  // =========================================================
  // Sequential state registers (all FSMs)
  // =========================================================
  always_ff @(posedge clk or negedge resetn) begin
    if (!resetn) begin
      awstate <= AWIDLE;
      wstate  <= WIDLE;
      bstate  <= BIDLE;
      arstate <= ARIDLE;
      rstate  <= RIDLE;
    end else begin
      awstate <= awnext_state;
      wstate  <= wnext_state;
      bstate  <= bnext_state;
      arstate <= arnext_state;
      rstate  <= rnext_state;
    end
  end

  // =========================================================
  // WRITE ADDRESS channel FSM (combinational)
  // =========================================================
  always_comb begin
    awnext_state = awstate;
    awready      = 1'b0;
    case (awstate)
      AWIDLE:    awnext_state = AWSTART;
      AWSTART:   if (awvalid) awnext_state = AWREADY_S;
      AWREADY_S: begin
        awready = 1'b1;
        if (wstate == WREADY_S) awnext_state = AWIDLE;
      end
      default: awnext_state = AWIDLE;
    endcase
  end

  always_ff @(posedge clk or negedge resetn) begin
    if (!resetn) begin
      awaddrt <= '0; awidt <= '0; awlent <= '0; awsizet <= '0; awburstt <= '0;
    end else if (awvalid && awready) begin
      awaddrt  <= awaddr;
      awidt    <= awid;
      awlent   <= awlen;
      awsizet  <= awsize;
      awburstt <= awburst;
    end
  end

  // =========================================================
  // WRITE DATA channel FSM (combinational)
  // =========================================================
  always_comb begin
    wnext_state = wstate;
    wready      = 1'b0;
    case (wstate)
      WIDLE:    wnext_state = WSTART;
      WSTART:   if (awstate == AWREADY_S) wnext_state = WREADY_S;
      WREADY_S: begin
        wready = 1'b1;
        if (wvalid) wnext_state = WVALID_S;
      end
      WVALID_S: begin
        wready = 1'b1;
        if (wvalid && wlast) wnext_state = WIDLE;
      end
      default: wnext_state = WIDLE;
    endcase
  end

  // =========================================================
  // Write data sequential block – THE ONLY DRIVER of mem[]
  // mem[] is reset here (no initial block needed / allowed)
  // =========================================================
  always_ff @(posedge clk or negedge resetn) begin : wr_data_proc
    integer      i;
    logic [31:0] nxt;
    if (!resetn) begin
      waddr_cur  <= '0;
      wlen_count <= '0;
      wboundary  <= '0;
      for (i = 0; i < 128; i = i + 1)
        mem[i] <= 8'h00;
    end else begin
      case (wstate)
        WSTART: begin
          if (awstate == AWREADY_S) begin
            waddr_cur  <= awaddr;
            wlen_count <= '0;
            wboundary  <= wrap_boundary(awlen, awsize);
          end
        end
        WREADY_S,
        WVALID_S: begin
          if (wvalid && wready) begin
            wlen_count <= wlen_count + 1;
            case (awburstt)
              2'b00: wr_fixed(wstrb, waddr_cur, wdata, nxt);
              2'b01: wr_incr (wstrb, waddr_cur, wdata, awsizet, nxt);
              2'b10: wr_wrap (wstrb, waddr_cur, wdata, awsizet, wboundary, nxt);
              default: nxt = waddr_cur;
            endcase
            waddr_cur <= nxt;
          end
        end
        default: ;
      endcase
    end
  end

  // =========================================================
  // WRITE RESPONSE channel FSM (combinational)
  // =========================================================
  always_comb begin
    bnext_state = bstate;
    bvalid      = 1'b0;
    bid         = awidt;
    bresp       = 2'b00;
    case (bstate)
      BIDLE:    if (wstate == WIDLE && wlen_count > 0) bnext_state = BVALID_S;
      BVALID_S: begin
        bvalid = 1'b1;
        if (bready) bnext_state = BIDLE;
      end
      default: bnext_state = BIDLE;
    endcase
  end

  // =========================================================
  // READ ADDRESS channel FSM (combinational)
  // =========================================================
  always_comb begin
    arnext_state = arstate;
    arready      = 1'b0;
    case (arstate)
      ARIDLE:    arnext_state = ARSTART;
      ARSTART:   if (arvalid) arnext_state = ARREADY_S;
      ARREADY_S: begin
        arready = 1'b1;
        if (rstate == RIDLE) arnext_state = ARIDLE;
      end
      default: arnext_state = ARIDLE;
    endcase
  end

  always_ff @(posedge clk or negedge resetn) begin
    if (!resetn) begin
      araddrt <= '0; aridr <= '0; arlenr <= '0; arsizer <= '0; arburstr <= '0;
    end else if (arvalid && arready) begin
      araddrt  <= araddr;
      aridr    <= arid;
      arlenr   <= arlen;
      arsizer  <= arsize;
      arburstr <= arburst;
    end
  end

  // =========================================================
  // READ DATA channel FSM (combinational)
  // data_rd() is a pure function – safe to call in always_comb
  // =========================================================
  always_comb begin
    rnext_state = rstate;
    rvalid      = 1'b0;
    rlast       = 1'b0;
    rdata       = '0;
    rid         = aridr;
    rresp       = 2'b00;
    case (rstate)
      RIDLE: if (arstate == ARREADY_S) rnext_state = RVALID_S;
      RVALID_S: begin
        rvalid = 1'b1;
        rdata  = data_rd(raddr_cur);
        rlast  = (rlen_count == arlenr);
        if (rready && (rlen_count == arlenr)) rnext_state = RIDLE;
      end
      default: rnext_state = RIDLE;
    endcase
  end

  // =========================================================
  // Read address tracking (sequential)
  // Local variable declared at block level to avoid case-branch
  // variable declaration (not supported in all tool versions)
  // =========================================================
  always_ff @(posedge clk or negedge resetn) begin : rd_addr_proc
    logic [31:0] wrap_base_r;
    if (!resetn) begin
      raddr_cur  <= '0;
      rlen_count <= '0;
      rboundary  <= '0;
    end else begin
      case (rstate)
        RIDLE: begin
          if (arstate == ARREADY_S) begin
            raddr_cur  <= araddr;
            rlen_count <= '0;
            rboundary  <= wrap_boundary(arlen, arsize);
          end
        end
        RVALID_S: begin
          if (rvalid && rready) begin
            rlen_count <= rlen_count + 1;
            case (arburstr)
              2'b00: raddr_cur <= raddr_cur;
              2'b01: raddr_cur <= raddr_cur + (32'd1 << arsizer);
              2'b10: begin
                wrap_base_r = (raddr_cur / {24'd0, rboundary}) * {24'd0, rboundary};
                if ((raddr_cur + (32'd1 << arsizer) - wrap_base_r) >= {24'd0, rboundary})
                  raddr_cur <= wrap_base_r;
                else
                  raddr_cur <= raddr_cur + (32'd1 << arsizer);
              end
              default: raddr_cur <= raddr_cur;
            endcase
          end
        end
        default: ;
      endcase
    end
  end

endmodule 
