module ssd1306_toggle_i2c (
    input  logic clk,
    input  logic rst_n,
    input  logic update,     // pulse to toggle

    output logic scl,
    inout  tri   sda
);
    // ------------------------------------------
    // Instantiate simple I2C master
    // ------------------------------------------
    logic [7:0] data_in;
    logic start, last, busy, done;

    i2c_master #(
        .CLK_HZ(50_000_000),
        .I2C_HZ(100_000)
    ) u_i2c (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(data_in),
        .start(start),
        .last(last),
        .busy(busy),
        .done(done),
        .scl(scl),
        .sda(sda)
    );

    // ------------------------------------------
    // OLED FSM
    // ------------------------------------------
    typedef enum logic [3:0] {
        RESET,
        INIT1, INIT2, INIT3, INIT4,  // init commands
        CLEAR, NEXT_PAGE, NEXT_COL,  // optional RAM clear
        IDLE,
        SEND_CTRL, SEND_CMD
    } state_t;

    state_t state;
    logic full_on;
    logic [7:0] cmd_byte;
    logic [6:0] col;
    logic [2:0] page;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state   <= RESET;
            full_on <= 0;
            start   <= 0;
            col     <= 0;
            page    <= 0;
        end else begin
            start <= 0; // default

            case (state)
                // -------------------------
                // Init sequence
                // -------------------------
                RESET: begin
                    if (!busy) begin
                        data_in <= 8'hAE;  // Display OFF
                        last    <= 1;
                        start   <= 1;
                        state   <= INIT1;
                    end
                end
                INIT1: if (done) begin
                    data_in <= 8'h20;  // Memory mode
                    last    <= 0;
                    start   <= 1;
                    state   <= INIT2;
                end
                INIT2: if (done) begin
                    data_in <= 8'h00;  // Horizontal addressing
                    last    <= 1;
                    start   <= 1;
                    state   <= INIT3;
                end
                INIT3: if (done) begin
                    data_in <= 8'h8D;  // Charge pump
                    last    <= 0;
                    start   <= 1;
                    state   <= INIT4;
                end
                INIT4: if (done) begin
                    data_in <= 8'h14;  // Enable charge pump
                    last    <= 1;
                    start   <= 1;
                    state   <= CLEAR;  // go clear RAM
                end

                // -------------------------
                // Clear GDDRAM
                // -------------------------
                CLEAR: if (done) begin
                    if (page < 8) begin
                        if (col < 128) begin
                            data_in <= 8'h00;
                            last    <= (col == 127);
                            start   <= 1;
                            col     <= col + 1;
                        end else begin
                            col <= 0;
                            page <= page + 1;
                        end
                    end else begin
                        // done clearing → turn ON
                        data_in <= 8'hAF; // Display ON
                        last    <= 1;
                        start   <= 1;
                        state   <= IDLE;
                    end
                end

                // -------------------------
                // Idle / toggle logic
                // -------------------------
                IDLE: begin
                    if (update) begin
                        full_on  <= ~full_on;
                        cmd_byte <= full_on ? 8'hA5 : 8'hA4;
                        data_in  <= 8'h00;  // control
                        last     <= 0;
                        start    <= 1;
                        state    <= SEND_CTRL;
                    end
                end

                SEND_CTRL: if (done) begin
                    data_in <= cmd_byte;
                    last    <= 1;
                    start   <= 1;
                    state   <= SEND_CMD;
                end

                SEND_CMD: if (done) begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule
