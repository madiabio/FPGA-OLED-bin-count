module btn_sync_debounce #(
	parameter int unsigned CLK_HZ = 50_000_000, // sys clk freq
	parameter int unsigned DEBOUNCE_MS = 5 // debounce interval in ms
)(
	input  logic clk,        // system clock
	input  logic rst_n,      // active-low reset
	input  logic btn_raw,    // noisy, asynchronous button input
	output logic level,      // debounced button level (0 = released, 1 = pressed)
	output logic rise,       // 1-cycle pulse on press
	output logic fall        // 1-cycle pulse on release

);

	// Synchronise the async input
	logic btn_meta, btn_sync;
	always_ff @(posedge clk, negedge rst_n) begin
	  if (!rst_n) begin		// on reset, set variables to known state (0)
			btn_meta <= 1'b0;
			btn_sync <= 1'b0;
	  end else begin			// One tick delay gives the first flip-flop time to settle if it got an unknown state
			btn_meta <= btn_raw;
			btn_sync <= btn_meta;
	  end
	end



	// Debounce: accept change iff stable for ~DEBOUNCE_MS at CLK_HZ
	localparam int unsigned DEBOUNCE_CYCLES = (CLK_HZ/1000) * DEBOUNCE_MS;
	localparam int W = $clog2(DEBOUNCE_CYCLES);		   // width of counter in bits (min num bits needed to count up to DEBOUNCE_CYCLES)
	logic [W-1:0] db_cnt;										// debounce counter register (can count from 0 to 2^18-1 in binary)
	logic btn_level;												// debounced level
	always_ff @(posedge clk or negedge rst_n) begin
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
	
	
	// Edge detection
	logic btn_level_d;
	always_ff @(posedge clk or negedge rst_n) begin // Check on each posedge clk or reset
	  if (!rst_n) begin // If reset, set to known state.
			btn_level_d <= 1'b0;
	  end else begin // Else, check the button's level.
			btn_level_d <= btn_level;
	  end
	end
	
	assign level = btn_level;
	assign rise  =  btn_level & ~btn_level_d;  // rising edge pulse
	assign fall  = ~btn_level &  btn_level_d;  // falling edge pulse
	
endmodule