// ================================================================
// Module      : sync_fifo_any_depth
// File        : sync_fifo_any_depth.v
// Description : Synchronous FIFO with arbitrary depth.
//
// Notes:
//   1. This FIFO uses a single clock for both write and read.
//   2. DEPTH can be any positive integer, not necessarily a power of two.
//   3. Because DEPTH may not be a power of two, RAM addresses are managed
//      by independent address counters that wrap at DEPTH - 1.
//   4. The current number of stored entries is tracked by used_cnt.
//      This makes full/empty generation simple and safe.
// ================================================================

module sync_fifo_any_depth #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH      = 10
)(
    input  wire                  clk,       // common clock for both write and read
    input  wire                  rst_n,     // active-low asynchronous reset

    input  wire                  wr_en,     // write request from upstream logic
    input  wire [DATA_WIDTH-1:0] din,       // data written into FIFO
    output wire                  full,      // FIFO full flag, write is blocked when full

    input  wire                  rd_en,     // read request from downstream logic
    output reg  [DATA_WIDTH-1:0] dout,      // data read from FIFO
    output wire                  empty      // FIFO empty flag, read is blocked when empty
);

// ----------------------------------------------------------------
// Verilog-2001 compatible clog2 function.
// It returns the minimum bit width needed to represent value - 1.
// ----------------------------------------------------------------
function integer clog2;
    input integer value;
    integer i;
    begin
        value = value - 1;
        for (i = 0; value > 0; i = i + 1)
            value = value >> 1;
        clog2 = i;
    end
endfunction

localparam ADDR_WIDTH  = (DEPTH <= 1) ? 1 : clog2(DEPTH);
localparam COUNT_WIDTH = clog2(DEPTH + 1);

// Parameter check for simulation.
initial begin
    if (DEPTH < 1) begin
        $error("DEPTH must be greater than or equal to 1");
    end
end

// ----------------------------------------------------------------
// FIFO memory.
// True depth is exactly DEPTH.
// ----------------------------------------------------------------
reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

// ----------------------------------------------------------------
// RAM address counters.
// These counters are not allowed to run through unused addresses.
// For example, when DEPTH = 10, the sequence is:
//
//   0, 1, 2, ..., 8, 9, 0, 1, ...
// ----------------------------------------------------------------
reg [ADDR_WIDTH-1:0] wr_addr;
reg [ADDR_WIDTH-1:0] rd_addr;

// ----------------------------------------------------------------
// used_cnt records how many entries are currently stored in the FIFO.
//
// Range:
//   0      : empty
//   DEPTH  : full
// ----------------------------------------------------------------
reg [COUNT_WIDTH-1:0] used_cnt;

wire wr_fire;
wire rd_fire;

assign full  = (used_cnt == DEPTH);
assign empty = (used_cnt == 0);

assign wr_fire = wr_en && !full;
assign rd_fire = rd_en && !empty;

// Next address values with arbitrary-depth wrap.
wire [ADDR_WIDTH-1:0] wr_addr_next;
wire [ADDR_WIDTH-1:0] rd_addr_next;

assign wr_addr_next = (wr_addr == DEPTH - 1) ? {ADDR_WIDTH{1'b0}} :
                                               wr_addr + 1'b1;

assign rd_addr_next = (rd_addr == DEPTH - 1) ? {ADDR_WIDTH{1'b0}} :
                                               rd_addr + 1'b1;

// ----------------------------------------------------------------
// Main FIFO logic.
// ----------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        wr_addr  <= {ADDR_WIDTH{1'b0}};
        rd_addr  <= {ADDR_WIDTH{1'b0}};
        used_cnt <= {COUNT_WIDTH{1'b0}};
        dout     <= {DATA_WIDTH{1'b0}};
    end
    else begin
        // Write path
        if (wr_fire) begin
            mem[wr_addr] <= din;
            wr_addr <= wr_addr_next;
        end

        // Read path
        if (rd_fire) begin
            dout <= mem[rd_addr];
            rd_addr <= rd_addr_next;
        end

        // Occupancy counter update.
        //
        // Case 1: write only  -> used_cnt + 1
        // Case 2: read only   -> used_cnt - 1
        // Case 3: both happen -> used_cnt unchanged
        // Case 4: none happen -> used_cnt unchanged
        case ({wr_fire, rd_fire})
            2'b10: used_cnt <= used_cnt + 1'b1;
            2'b01: used_cnt <= used_cnt - 1'b1;
            default: used_cnt <= used_cnt;
        endcase
    end
end

endmodule
