`ifndef FIFO_SVA_SV
`define FIFO_SVA_SV

// Bound assertion checker for sync_fifo_any_depth.
// Scoreboard checks data ordering; this module checks cycle-level
// protocol, count, address, and reset properties.
module fifo_sva #(
    parameter int DATA_WIDTH  = 8,
    parameter int DEPTH       = 10,
    parameter int ADDR_WIDTH  = (DEPTH <= 1) ? 1 : $clog2(DEPTH),
    parameter int COUNT_WIDTH = $clog2(DEPTH + 1)
)(
    input logic                  clk,
    input logic                  rst_n,
    input logic                  wr_en,
    input logic                  rd_en,
    input logic [DATA_WIDTH-1:0] dout,
    input logic                  full,
    input logic                  empty,
    input logic                  wr_fire,
    input logic                  rd_fire,
    input logic [ADDR_WIDTH-1:0]  wr_addr,
    input logic [ADDR_WIDTH-1:0]  rd_addr,
    input logic [COUNT_WIDTH-1:0] used_cnt
);

    function automatic logic [ADDR_WIDTH-1:0] next_addr(
        input logic [ADDR_WIDTH-1:0] current_addr
    );
        if (current_addr == (DEPTH - 1)) begin
            next_addr = '0;
        end
        else begin
            next_addr = current_addr + 1'b1;
        end
    endfunction

    a_flags_mutually_exclusive:
    assert property (@(posedge clk) disable iff (!rst_n) !(full && empty))
    else $error("FIFO_SVA: full and empty are both asserted");

    a_used_count_in_range:
    assert property (@(posedge clk) disable iff (!rst_n) used_cnt <= DEPTH)
    else $error("FIFO_SVA: used_cnt exceeds DEPTH");

    // Reset checks are deliberately not disabled by reset.
    a_reset_active_state:
    assert property (@(posedge clk) !rst_n |-> (empty && !full && (dout == '0) && (used_cnt == '0) && (wr_addr == '0) && (rd_addr == '0)))
    else $error("FIFO_SVA: reset state is incorrect");

    a_reset_release_state:
    assert property (@(posedge clk) $rose(rst_n) |-> (empty && !full && (dout == '0) && (used_cnt == '0)))
    else $error("FIFO_SVA: FIFO state is incorrect when reset is released");

    a_write_only_count:
    assert property (@(posedge clk) disable iff (!rst_n) (wr_fire && !rd_fire) |=> (used_cnt == ($past(used_cnt) + 1'b1)))
    else $error("FIFO_SVA: write-only operation did not increment used_cnt");

    a_read_only_count:
    assert property (@(posedge clk) disable iff (!rst_n) (!wr_fire && rd_fire) |=> (used_cnt == ($past(used_cnt) - 1'b1)))
    else $error("FIFO_SVA: read-only operation did not decrement used_cnt");

    a_simultaneous_count:
    assert property (@(posedge clk) disable iff (!rst_n) (wr_fire && rd_fire) |=> (used_cnt == $past(used_cnt)))
    else $error("FIFO_SVA: simultaneous read/write changed used_cnt");

    a_write_address_progress:
    assert property (@(posedge clk) disable iff (!rst_n) wr_fire |=> (wr_addr == next_addr($past(wr_addr))))
    else $error("FIFO_SVA: write address did not advance correctly");

    a_read_address_progress:
    assert property (@(posedge clk) disable iff (!rst_n) rd_fire |=> (rd_addr == next_addr($past(rd_addr))))
    else $error("FIFO_SVA: read address did not advance correctly");

    a_empty_read_rejected:
    assert property (@(posedge clk) disable iff (!rst_n) (empty && rd_en && !wr_en) |=> (empty && (used_cnt == $past(used_cnt)) && (wr_addr == $past(wr_addr)) && (rd_addr == $past(rd_addr)) && (dout == $past(dout))))
    else $error("FIFO_SVA: empty read request changed FIFO state");

    a_full_write_rejected:
    assert property (@(posedge clk) disable iff (!rst_n) (full && wr_en && !rd_en) |=> (full && (used_cnt == $past(used_cnt)) && (wr_addr == $past(wr_addr)) && (rd_addr == $past(rd_addr))))
    else $error("FIFO_SVA: full write request changed FIFO state");

    a_empty_simultaneous_request:
    assert property (@(posedge clk) disable iff (!rst_n) (empty && wr_en && rd_en) |=> (!empty && (used_cnt == ($past(used_cnt) + 1'b1)) && (wr_addr == next_addr($past(wr_addr))) && (rd_addr == $past(rd_addr))))
    else $error("FIFO_SVA: empty-state simultaneous request behavior is incorrect");

    a_full_simultaneous_request:
    assert property (@(posedge clk) disable iff (!rst_n) (full && wr_en && rd_en) |=> (!full && (used_cnt == ($past(used_cnt) - 1'b1)) && (wr_addr == $past(wr_addr)) && (rd_addr == next_addr($past(rd_addr)))))
    else $error("FIFO_SVA: full-state simultaneous request behavior is incorrect");

    a_middle_simultaneous_request:
    assert property (@(posedge clk) disable iff (!rst_n) (!empty && !full && wr_en && rd_en) |=> ((used_cnt == $past(used_cnt)) && (wr_addr == next_addr($past(wr_addr))) && (rd_addr == next_addr($past(rd_addr)))))
    else $error("FIFO_SVA: middle-state simultaneous request behavior is incorrect");

    a_dout_holds_without_accepted_read:
    assert property (@(posedge clk) disable iff (!rst_n) !rd_fire |=> (dout == $past(dout)))
    else $error("FIFO_SVA: dout changed without an accepted read");

    // cover property items avoid relying on vacuous assertion pass.
    c_empty_read:       cover property (@(posedge clk) disable iff (!rst_n) empty && rd_en && !wr_en);
    c_full_write:       cover property (@(posedge clk) disable iff (!rst_n) full && wr_en && !rd_en);
    c_empty_read_write: cover property (@(posedge clk) disable iff (!rst_n) empty && wr_en && rd_en);
    c_full_read_write:  cover property (@(posedge clk) disable iff (!rst_n) full && wr_en && rd_en);
    c_middle_read_write:cover property (@(posedge clk) disable iff (!rst_n) !empty && !full && wr_en && rd_en);
    c_write_wrap:       cover property (@(posedge clk) disable iff (!rst_n) wr_fire && (wr_addr == (DEPTH - 1)));
    c_read_wrap:        cover property (@(posedge clk) disable iff (!rst_n) rd_fire && (rd_addr == (DEPTH - 1)));

endmodule

`endif
