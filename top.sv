module top (
    input  logic clk_50,
    input  logic rst_n,      // active low reset (could be tied to a KEY button)
    input  logic btn_raw,    // noisy async button input
    output logic led_test,    // user LED
	 
	 
    // SSD1306 I2C pins
    inout  tri   oled_sda,
    output logic oled_scl
);
    
	 // 1) instantiate button synchronizer + debouncer
	 logic btn_level, btn_rise, btn_fall;
    btn_sync_debounce #(
        .CLK_HZ(50_000_000),
        .DEBOUNCE_MS(5)
    ) u_btn (
        .clk     (clk_50),
        .rst_n   (rst_n),	
        .btn_raw (btn_raw),	// The raw async state of the button
        .level   (btn_level),	// The clean, debounced state of the button.
        .rise    (btn_rise),  // A one-clock-cycle pulse that goes high when btn_level changes from 0 → 1.
        .fall    (btn_fall)   // A one-clock-cycle pulse that goes high when btn_level changes from 1 → 0.
    );

	
	// 2) Toggle LED on each rising edge of debounced button
	logic led_state;
	always_ff @(posedge clk_50, negedge rst_n) begin
		if (!rst_n) begin
			led_state <= 1'b0;	// LED starts off
		end else if (btn_rise) begin
			led_state <= ~led_state; // Toggle LED once per press
		end
	end
	
	assign led_test = led_state; // drive LED on board
		
			
		
endmodule
	