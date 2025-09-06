module top (
	input logic clk_50,
	input logic rst_n,		// active low reset from a button
	input logic btn_raw, 	// async, noisy
	output logic led_test	// user LED
);

	// 1) Synchronise the async button to clk_50
	logic btn_meta, btn_sync;
	always_ff @(posedge clk_50, negedge rst_n) begin
		if (!rst_n) begin // If the reset button is pushed, force both signals to known state (0)
			btn_meta <= 1'b0; 
			btn_sync <= 1'b0;
		end else begin // One tick delay gives the first flip-flop time to settle if it got an unknown state
			btn_meta <= btn_raw;  // Let meta get the raw value
			btn_sync <= btn_meta; // and the synced button gets the previous meta value.
		end
	end
	
	// 2) Debounce: accept change iff stable for ~5ms at 50MHz
	localparam int unsigned DEBOUNCE_CYCLES = 250_000; // 5ms * 50*(10^6), num clock cycles to wait for stability check
	localparam int W = $clog2(DEBOUNCE_CYCLES);		   // width of counter in bits (min num bits needed to count up to DEBOUNCE_CYCLES)
	logic [W-1:0] db_cnt;										// debounce counter register (can count from 0 to 2^18-1 in binary)
	logic btn_level;												// debounced level
	
	
	always_ff @(posedge clk_50, negedge rst_n) begin
		if (!rst_n) begin // If reset button is pushed, force db_cnt and btn_lvl to known state (0)
			db_cnt <= '0;
			btn_level <= 1'b0;
		end else if (btn_sync == btn_level) begin // If the raw synchronised button is equal to clean debounced value
			db_cnt <= '0; // Then reset the counter to start fresh. Only want to wait when btn is different to previous trusted value (when it might be bouncing)
		end else begin // Otherwise if its different,
			if (db_cnt == DEBOUNCE_CYCLES-1) begin // If the button has been stable for long enough,
				btn_level <= btn_sync; // Commit the new state
				db_cnt <= '0; // Reset the counter
			end else begin 
				db_cnt <= db_cnt+1; // Keep counting
			end
		end
	end
	
	
	// 3) Edge detect + toggle: one-cycle pulse on rising edge
	logic btn_level_d, btn_rise, led_state;
	always_ff @(posedge clk_50, negedge rst_n) begin
		if (!rst_n) begin
			btn_level_d <= 1'b0;
			led_state <= 1'b0; // LED off
		end else begin
			btn_level_d <= btn_level;
			if (btn_level & ~btn_level_d) // rising edge
				led_state <= ~led_state;   // toggle once per press
		end
	end
	
	assign led_test = led_state; // drive LED on board
		
endmodule
	