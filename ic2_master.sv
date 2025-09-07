module i2c_master #(
    parameter int CLK_HZ = 50_000_000,
    parameter int I2C_HZ = 100_000
)(
    input  logic clk,
    input  logic rst_n,

    // Byte interface
    input  logic [7:0] data_in,
    input  logic       start,   // pulse to start sending
    input  logic       last,    // set=1 for final byte (send stop after)
    output logic       busy,
    output logic       done,    // 1-cycle pulse when finished

    // I2C pins (open-drain style)
    output logic scl,
    inout  tri   sda
);

    // -------------------------------------------------------
    // Clock divider for SCL
    // -------------------------------------------------------
    localparam int DIV = CLK_HZ / (I2C_HZ * 4); // 4 phases per bit
    logic [$clog2(DIV)-1:0] divcnt;
    logic tick;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            divcnt <= '0;
            tick   <= 0;
        end else begin
            if (divcnt == DIV-1) begin
                divcnt <= '0;
                tick   <= 1;
            end else begin
                divcnt <= divcnt + 1;
                tick   <= 0;
            end
        end
    end

    // -------------------------------------------------------
    // FSM
    // -------------------------------------------------------
    typedef enum logic [2:0] {
        IDLE, START_COND, SEND_BITS, ACK_BIT, STOP_COND, DONE
    } state_t;

    state_t state;
    logic [3:0] bit_cnt;
    logic [7:0] shreg;

    logic scl_o, sda_o;
    assign scl = scl_o ? 1'bz : 1'b0; // open-drain
    assign sda = sda_o ? 1'bz : 1'b0; // open-drain

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state   <= IDLE;
            scl_o   <= 1;
            sda_o   <= 1;
            busy    <= 0;
            done    <= 0;
        end else begin
            done <= 0;
            if (tick) begin
                case (state)
                    IDLE: begin
                        if (start) begin
                            busy  <= 1;
                            shreg <= data_in;
                            bit_cnt <= 8;
                            // Start condition: SDA low while SCL high
                            sda_o <= 0;
                            scl_o <= 1;
                            state <= START_COND;
                        end
                    end
                    START_COND: begin
                        scl_o <= 0; // drop clock
                        state <= SEND_BITS;
                    end
                    SEND_BITS: begin
                        if (bit_cnt > 0) begin
                            sda_o <= shreg[7];   // MSB first
                            shreg <= {shreg[6:0],1'b0};
                            scl_o <= 1;          // clock high
                            bit_cnt <= bit_cnt - 1;
                        end else begin
                            scl_o <= 0;
                            state <= ACK_BIT;
                        end
                    end
                    ACK_BIT: begin
                        // ignore slave ACK for simplicity
                        scl_o <= 1;
                        sda_o <= 1; // release SDA
                        state <= last ? STOP_COND : DONE;
                    end
                    STOP_COND: begin
                        // Stop condition: SDA high while SCL high
                        scl_o <= 1;
                        sda_o <= 0;
                        sda_o <= 1;
                        state <= DONE;
                    end
                    DONE: begin
                        busy <= 0;
                        done <= 1;
                        state<= IDLE;
                        scl_o <= 1;
                        sda_o <= 1;
                    end
                endcase
            end
        end
    end
endmodule
