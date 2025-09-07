module i2c_ack_test #(
	parameter int CLK_HZ = 50_000_000,
	parameter int I2C_HZ = 100_000,
	parameter logic [6:0] ADDR = 7'h3C 

)(
	input logic clk, rst_n,
	inout tri	sda, scl,	// tri-state nets meaning multiple devices can drive them (FPGA open-drain, OLED ack)
	output logic led_ok
);

	// open-drain drivers 
	// most digital outputs work like this (push-pull):
	// when a signal is 1, a transistor connects the pin to +3.3V, when signal = 0 a different transistor connects the pin to GND.
	// open-drain is different:
	// it can only pull the line low (connect it to GND)
	// When it wants to output a 1, it doesn't actually drive high, it just lets go.
	// An external pull-up resistor to 3.3V brings the line high when nothing is pulling it down.
	// In this setup, multiple devices can share the same wire without fighitng. If any device pulls it low, the line goes low.
	// Only if EVERYONE lets go does the line float high.
	// Many chips can connect to the same two wires.
	logic sda0, scl0;
	assign sda = sda0 ? 1'b0 : 1'bz; // If sda0 == 1, drive 0 volts. Else drive high impedance (Z).
	assign scl = scl0 ? 1'b0 : 1'bz; // If scl0 == 1, drive 0 volts. Else drive high impedance (Z).
	wire sda_in = sda; // Wires can have multiple drivers, whereas logics can have only one source. SDA can be driven by both the FPGA and the OLED.
	
	
	
	// quarter-period tick for I2C bit timing (clock divider)
	localparam int TQ = CLK_HZ / (I2C_HZ * 4); // How many FPGA cycles make up one quarter of an I2C bit time.
	localparam int W = $clog2(TQ); 				 // How many bits needed to count up to TQ-1. (width)
	
	logic [W-1:0] q;  // Counter register thats wide enough to count up to TQ-1.
	logic tick;			// Goes high for 1 cycle when q hits TQ-1.
	
	always_ff @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			q <= '0;
			tick <= 0;
		end else begin
			tick <= (q == TQ-1);		 // Check q has hit max count or not.
			q	  <= tick ? '0 : q+1; // If tick is high, then q just hit max count, so need to reset. Else, incriment.
		end
	end
	
	
	// FSM to drive out an I2C transaction to the OLED
	typedef enum logic [3:0] {
	IDLE, START_A, START_B,
	BIT_L, BIT_HA, BIT_HB, BIT_HC,
	ACK_L, ACK_HA, ACK_HB, ACK_HC,
	STOP_A, STOP_B, DONE
	} st_t; // All possible states
	st_t st;
	
	logic [7:0] sh;  // "shift register" – holds the address byte to send
	logic [2:0] i;   // bit counter (counts down from 7 to 0)
	logic ack_n;     // flag to capture whether device ACK'd (0 = ACK, 1 = NACK)
	
	
	always_ff @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			st 		<= IDLE;
			sda0 		<= 0;
			scl0		<= 0;
			led_ok	<=	0;
		end else case(st)
			IDLE: // When a timing tick arrives, load the address into the shift register and go to START state.
				if (tick) begin
					sh			<= {ADDR,1'b0};	// load 7bit address and write bit
					i			<= 3'd7;				// start from MSB
					led_ok	<= 0;					// keep LED off.
					st 	   <= START_A;			// move to next state			
				end
			START_A:
				if (tick) begin
					sda0		<= 1;					// SDA falls while SCL high
					st			<= START_B;			// move to next state
				end
			START_B:
				if (tick) begin
					scl0		<= 1;					// pull SCL low
					st			<= BIT_L;			// next state (low phase)
				end
			
			// Send 8 Bits
			BIT_L: // Low phase
				if (tick) begin
					sda0		<= ~sh[i];			// shift reg contains bit we want to send, but since driver logic is inverted, need to flip it.
					st			<= BIT_HA;			// go to high phase A
				end
			BIT_HA:
				if (tick) begin
					scl0		<=	0;					// let SCL go high (driver logic is inverted)
					st			<= BIT_HB;			// next state (high phase B)
				end
			BIT_HB:
				if (tick) begin
					st			<= BIT_HC;			// Hold high for one tick and go to high pahse C
				end
			BIT_HC:
				if (tick) begin
					scl0		<=	1;					// pull low again
					if (i == 0) 
						st		<= ACK_L;		// If reach 0, need to handle ACK after last bit was sent.
					else begin
						i		<= i-1;			// decrement counter if i != 0
						st		<= BIT_L;		// go send next bit
					end
				end
			
			// Acknowledge Cycle
			ACK_L:
				if (tick) begin
					sda0		<= 0;					// release SDA
					st			<= ACK_HA;			// Move to ACK high phase A
				end
			ACK_HA:
				if (tick) begin
					scl0		<= 0;					// let SCL go high
					st			<= ACK_HB;			// move to ACK high phase B
				end
			ACK_HB:
				if	(tick) begin
					ack_n		<= sda_in;			// sample ACK
					st			<= ACK_HC;			// move to ACK high phase C
				end
			ACK_HC:
				if (tick) begin
					scl0	  <= 1;					 // put SCL low
					led_ok  <= (ack_n == 1'b0); // If ACK, light the LED
					st		  <= STOP_A; 		    // enter stop state.
				end
			
			// STOP condition
			STOP_A:
				if (tick) begin
					sda0	  	<= 1;					// put SDA low
					scl0		<= 0;					// Let SCL go high
					st			<= STOP_B;			// enter stop state B
				end
			STOP_B:
				if (tick) begin
					sda0		<= 0;					// release SDA
					st			<= DONE;					
				end
			
			DONE: // end state, LED holds the result.
				;
			
		endcase		
	end
endmodule
	

	
	
