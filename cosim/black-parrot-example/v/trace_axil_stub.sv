module trace_axil_stub
  #(parameter addr_width_p = 32
    , parameter data_width_p = 32
    )
  (input  logic                     clk_i
   , input logic                    reset_i

   , input  logic [addr_width_p-1:0]  s_axil_awaddr
   , input  logic [2:0]               s_axil_awprot
   , input  logic                     s_axil_awvalid
   , output logic                     s_axil_awready

   , input  logic [data_width_p-1:0]  s_axil_wdata
   , input  logic [(data_width_p/8)-1:0] s_axil_wstrb
   , input  logic                     s_axil_wvalid
   , output logic                     s_axil_wready

   , output logic [1:0]               s_axil_bresp
   , output logic                     s_axil_bvalid
   , input  logic                     s_axil_bready

   , input  logic [addr_width_p-1:0]  s_axil_araddr
   , input  logic [2:0]               s_axil_arprot
   , input  logic                     s_axil_arvalid
   , output logic                     s_axil_arready

   , output logic [data_width_p-1:0]  s_axil_rdata
   , output logic [1:0]               s_axil_rresp
   , output logic                     s_axil_rvalid
   , input  logic                     s_axil_rready
   );

  localparam TRACE_CTRL_ADDR      = 32'h0000;
  localparam TRACE_STATUS_ADDR    = 32'h0000;
  localparam TRACE_DATA_ADDR      = 32'h0004;
  localparam TRACE_COUNT_ADDR     = 32'h0008;
  localparam TRACE_DROPPED_ADDR   = 32'h000C;
  localparam TRACE_PKT_COUNT_ADDR = 32'h0010;

  logic        trace_enable_r;
  logic [31:0] trace_data_r;
  logic [31:0] trace_count_r;
  logic [31:0] trace_dropped_r;
  logic [31:0] trace_pkt_count_r;

  // very simple synthetic source
  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      trace_enable_r    <= 1'b0;
      trace_data_r      <= 32'h1000_0000;
      trace_count_r     <= 32'd0;
      trace_dropped_r   <= 32'd0;
      trace_pkt_count_r <= 32'd0;
    end else begin
      if (trace_enable_r) begin
        trace_data_r      <= trace_data_r + 32'h1;
        trace_count_r     <= 32'd1; // pretend 1 word available
        trace_pkt_count_r <= trace_pkt_count_r + 32'd1;
      end else begin
        trace_count_r <= 32'd0;
      end

      if (s_axil_awvalid && s_axil_wvalid && s_axil_awready && s_axil_wready) begin
        if (s_axil_awaddr == TRACE_CTRL_ADDR) begin
          trace_enable_r <= s_axil_wdata[0];
          if (s_axil_wdata[2]) begin
            trace_data_r      <= 32'h1000_0000;
            trace_count_r     <= 32'd0;
            trace_dropped_r   <= 32'd0;
            trace_pkt_count_r <= 32'd0;
          end
        end
      end

      if (s_axil_arvalid && s_axil_arready && s_axil_araddr == TRACE_DATA_ADDR && trace_count_r != 0) begin
        trace_count_r <= 32'd0; // consume the synthetic word
      end
    end
  end

  always_comb begin
    s_axil_awready = 1'b1;
    s_axil_wready  = 1'b1;
    s_axil_bresp   = 2'b00;
    s_axil_bvalid  = s_axil_awvalid & s_axil_wvalid;

    s_axil_arready = 1'b1;
    s_axil_rresp   = 2'b00;
    s_axil_rvalid  = s_axil_arvalid;

    unique case (s_axil_araddr)
      TRACE_STATUS_ADDR:    s_axil_rdata = {28'b0, 1'b0, (trace_count_r == 0), 1'b0, (trace_count_r != 0)};
      TRACE_DATA_ADDR:      s_axil_rdata = trace_data_r;
      TRACE_COUNT_ADDR:     s_axil_rdata = trace_count_r;
      TRACE_DROPPED_ADDR:   s_axil_rdata = trace_dropped_r;
      TRACE_PKT_COUNT_ADDR: s_axil_rdata = trace_pkt_count_r;
      default:              s_axil_rdata = 32'hDEAD_BEEF;
    endcase
  end

endmodule
