module top (
	input logic clk,
	input logic rst_n,
	input logic btn_raw, // async, noisy
	output logic led_even
);


	// 1) syncrhonise and debounce
	logic btn_meta, btn_sync, btn_d, btn_rise;
	always_ff @(posedge clk) begin
		btn_meta <= btn_raw; // non blocking so RHS evaluated syncrhonously.
		btn_sync <= btn_meta;
		
