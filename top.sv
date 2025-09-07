module top (
	input  logic clk_50,
	input  logic rst_n,      // active low reset (could be tied to a KEY button)
	input  logic btn_raw,    // noisy async button input		 
		 
	// SSD1306 I2C pins
	inout  tri   i2c_sda,         // Arduino SDA (JP3 pin 2)
	inout  tri   i2c_scl,         // Arduino SCL (JP3 pin 1)

	output logic LED0             // use a board LED to show ACK
);
    i2c_ack_test #(
		.CLK_HZ(50_000_000),
		.I2C_HZ(100_000),
		.ADDR  (7'h3C)
	 ) tester (
		.clk	 (clk_50),
		.rst_n (rst_n),
		.sda	 (i2c_sda),
		.scl	 (i2c_scl),
		.led_ok(LED0)
	 );	 
endmodule