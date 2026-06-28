// Bind FIFO assertions only when explicitly enabled.
// ./run.sh sva 1 adds +define+FIFO_ENABLE_SVA.
`ifdef FIFO_ENABLE_SVA

bind sync_fifo_any_depth fifo_sva #(
    .DATA_WIDTH(DATA_WIDTH),
    .DEPTH     (DEPTH)
) fifo_sva_i (
    .clk      (clk),
    .rst_n    (rst_n),
    .wr_en    (wr_en),
    .rd_en    (rd_en),
    .dout     (dout),
    .full     (full),
    .empty    (empty),
    .wr_fire  (wr_fire),
    .rd_fire  (rd_fire),
    .wr_addr  (wr_addr),
    .rd_addr  (rd_addr),
    .used_cnt (used_cnt)
);

`endif
