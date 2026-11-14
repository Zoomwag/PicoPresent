
module cypher(
    clk,
    reset,
    start,
    current_key,
    current_text,
    cypher_text,
    current_round,
    done
);

    // this is just the clock to time the rounds
    input clk;

    input reset;
    input start;

    // this is the key that has undergone the the changes
    input [79:0] current_key;

    // this is the current 64 bit input that is wating to be encypted
    input [63:0] current_text;

    // this is the encpryted text that has gone though the 32 rounds of encyption
    output [63:0] cypher_text;
    reg [63:0] cypher_text;

    // this is the current encrytpion round number so that the controller will know when to feed the next text input in
    output [5:0] current_round;
    reg [5:0] current_round;

    output done;
    reg done;


    // just counts the rounds
    reg busy;

    // registers for storing the current key and text
    reg [79:0] key_register;
    reg [63:0] text_register;

    // connecting the inputs so that they can be used
    wire [79:0] next_key;
    wire [63:0] round_key;
    wire [63:0] next_text;


    // connecting the cipher round and key manipulator
    cypher_round round_logic(
        .current_key(round_key),
        .current_text(text_register),
        .next_text(next_text)
    );

    key_manipulater key_logic(
        .key_in(key_register),
        .round_counter(current_round[4:0]),
        .key_out(next_key),
        .round_key(round_key)
    );


    // this is going to be the main loop that just does the encryption 32 times
    always @(posedge clk) begin

        if (reset) begin

            key_register <= 80'd0;
            text_register <= 64'd0;
            cypher_text <= 64'd0;

            current_round <= 6'd0;

            busy <= 1'b0;
            done <= 1'b0;

        end

        else begin

            // load a new encryption when start is activated
            done <= 1'b0;

            if (!busy) begin

                if (start) begin

                    key_register <= current_key;
                    text_register <= current_text;

                    current_round <= 6'd1;

                    cypher_text <= 64'd0;

                    busy <= 1'b1;

                end

            end

            else begin

                // the counting loop
                if (current_round <= 6'd31) begin

                    // store the result of the current encryption round
                    text_register <= next_text;

                    // update the key for the next round
                    key_register <= next_key;

                    current_round <= current_round + 6'd1;

                end

                // This just only outputs the cypher answer after it has gone through all the rounds
                else if (current_round == 6'd32) begin

                    // final XOR with the 32nd round key
                    cypher_text <= text_register ^ round_key;

                    done <= 1'b1;

                    busy <= 1'b0;

                end

                else begin

                    busy <= 1'b0;

                end

            end

        end

    end

endmodule



// This module performs one complete encryption round

module cypher_round(
    current_key,
    current_text,
    next_text
);

    input [63:0] current_key;
    input [63:0] current_text;

    output [63:0] next_text;
    reg [63:0] next_text;


    // just the register for the first layer
    reg [63:0] add_round_key_done;

    // This is the s box reg it is basically just a 2 dimensional reg
    // The reason that it has to be split is so that each nibble can be changed
    reg [3:0] s_box_input [0:15];

    // the S box output
    reg [63:0] s_box_output;

    // temporary S-box value
    reg [3:0] s_box_value;

    // this is the output from the p layer
    reg [63:0] p_layer_output;

    integer i;
    integer j;


    // this is the main combinational encryption logic
    always @(current_key or current_text) begin

        // the add key round basically just doing XOR to the key and text
        add_round_key_done = current_text ^ current_key;

        // This is the s box layer what it does is it swaps each nibble with another predefined one
        s_box_output = 64'd0;

        for(i = 0; i < 16; i = i + 1) begin

            // this splits the input into 16 nibbles
            // using a shift because indexed part-selects are not supported here
            s_box_input[i] = add_round_key_done >> (60 - (4*i));

            s_box_value = 4'h0;

            case (s_box_input[i])

                // this is box array
                /*
                 its basically just
                 0 = C
                 1 = 5
                 2 = 6
                 3 = B
                 4 = 9
                 5 = 0
                 6 = A
                 7 = D
                 8 = 3
                 9 = E
                 A = F
                 B = 8
                 C = 4
                 D = 7
                 E = 1
                 F = 2
                */

                4'h0: s_box_value = 4'hC;
                4'h1: s_box_value = 4'h5;
                4'h2: s_box_value = 4'h6;
                4'h3: s_box_value = 4'hB;
                4'h4: s_box_value = 4'h9;
                4'h5: s_box_value = 4'h0;
                4'h6: s_box_value = 4'hA;
                4'h7: s_box_value = 4'hD;
                4'h8: s_box_value = 4'h3;
                4'h9: s_box_value = 4'hE;
                4'hA: s_box_value = 4'hF;
                4'hB: s_box_value = 4'h8;
                4'hC: s_box_value = 4'h4;
                4'hD: s_box_value = 4'h7;
                4'hE: s_box_value = 4'h1;
                4'hF: s_box_value = 4'h2;

                default: s_box_value = 4'h0;

            endcase

            // put the substituted nibble back into its original position
            s_box_output = s_box_output |
                           ({60'd0, s_box_value} << (60 - (4*i)));

        end


        // This is the p layer calculation

        p_layer_output = 64'd0;

        for (j = 0; j < 63; j = j + 1) begin

            // PRESENT permutation: bit j moves to bit (16*j) modulo 63
            p_layer_output[(16*j) % 63] = s_box_output[j];

        end

        // bit 63 remains in its original position
        p_layer_output[63] = s_box_output[63];

        // output of this encryption round
        next_text = p_layer_output;

    end

endmodule



module key_manipulater(
    key_in,
    round_counter,
    key_out,
    round_key
);

    input [79:0] key_in;
    input [4:0] round_counter;

    output [79:0] key_out;
    output [63:0] round_key;

    wire [79:0] rotated_key;
    wire [79:0] s_box_key;

    reg [3:0] s_box_out;


    // rotate the key left by 61 bits
    assign rotated_key = {key_in[18:0], key_in[79:19]};


    // S-box the highest nibble
    always @(rotated_key) begin

        case (rotated_key[79:76])

            4'h0: s_box_out = 4'hC;
            4'h1: s_box_out = 4'h5;
            4'h2: s_box_out = 4'h6;
            4'h3: s_box_out = 4'hB;
            4'h4: s_box_out = 4'h9;
            4'h5: s_box_out = 4'h0;
            4'h6: s_box_out = 4'hA;
            4'h7: s_box_out = 4'hD;
            4'h8: s_box_out = 4'h3;
            4'h9: s_box_out = 4'hE;
            4'hA: s_box_out = 4'hF;
            4'hB: s_box_out = 4'h8;
            4'hC: s_box_out = 4'h4;
            4'hD: s_box_out = 4'h7;
            4'hE: s_box_out = 4'h1;
            4'hF: s_box_out = 4'h2;

            default: s_box_out = 4'h0;

        endcase

    end


    // replace the highest nibble with the S-box output
    assign s_box_key = {s_box_out, rotated_key[75:0]};


    // XOR the round counter into bits 19:15
    // all other bits remain unchanged
    assign key_out = {
        s_box_key[79:20],
        (s_box_key[19:15] ^ round_counter),
        s_box_key[14:0]
    };


    // the current 64-bit round key
    assign round_key = key_in[79:16];

endmodule
