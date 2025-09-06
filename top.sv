module top (
	input logic clk_50,
	input logic rst_n,
	input logic btn_raw, // async, noisy
	output logic led_test
);

	// 24-bit counter (~1.5Hz blink)
	logic [23:0] cnt;
	
	always_ff @(posedge clk_50) begin
		 cnt <= cnt + 1;
	end
		
	assign led_test = cnt[23];  // slow blink

endmodule
	