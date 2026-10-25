




// Generating the key
module KeyGen(
    input wire clk,
    input wire start_key
    input wire rst,
    input wire key_in,
    input wire external_clk,
    output wire [79:0] full_key_for_reg,
    output wire key_ready
);

reg [79:0] key;
reg [7:0] count;
reg [7:0] bit_place;
reg key_done;
reg key_start;
assign key_ready = key_done;

initial begin
    count = 0;
    bit_place = 0;
    key_done = 0;
    key_start = 1'b1
    
end

always @(*) begin

    if(start_key) begin
        
        key_start = 1'b1;
    end

end


always @(posedge external_clk) begin

    if(start_key) begin

        if(rst) begin

            key = 80'h0000000000000000;

            start_key = 1'b1;


        end


       if (key_done == 0) begin

           // Front buffer
           if (count <= 8'd99) begin

               if (key_in == 1'b1) begin
                   count <= count + 1;
               end

           end

           // Actually transferring the key
           else if ((count >= 8'd100) && (count <= 8'd180)) begin
               key[bit_place] <= key_in;

               bit_place <= bit_place + 1;
               count <= count + 1;

           end

           // Acknowledging the key is done so that it only happens once
           else begin
               key_done <= 1;
           end

       end
    end

end

endmodule


// creating the plain text
module plain_text_gen(
    input wire clk,
    input wire external_clk,
    input wire text_in,
    input wire key_ready,
    output wire [63:0] plain_txt
);

    reg [63:0] plain_txt_reg;
    reg [5:0] j;

    assign plain_txt_for_reg = plain_txt

    initial begin
        j = 0;
    end




    always @(posedge external_clk) begin
        if (key_ready ) begin

            if(j < 64) begin
               
               plain_txt_reg[j] <= text_in;
               j <= j + 1;
            end

       end
    end


endmodule

module 


// this is the part that jsut does XOR with the current top 64 bits of the key
module XOR_round(
    input wire clk,
    input wire [63:0] plain_txt,
    input wire [63:0] current_key,
    output wire [63:0] XOR_round_done
);


   assign XOR_round_done = plain_txt ^ current_key;

endmodule


// this is the part that just swaps the bits with other bits based of a table
module S_box(
    input wire clk,
    input wire [63:0] XOR_round_done,
    output reg [63:0] S_box_done
);

    reg [3:0] S_box_input [0:15];

    reg [63:0] s_box_ouput;

   always @(*) begin


       // sorting input data
       for(i = 0; i < 16; i = i + 1) begin
           S_box_input[i] = XOR_round_done[63 - 4*i -: 4];


           // s box step
           case (S_box_input[i])

           // this is box array
           /* its basicall just
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

             4'h0: s_box_output[63 - 4*i -: 4] = 4'hC;
             4'h1: s_box_output[63 - 4*i -: 4] = 4'h5;
             4'h2: s_box_output[63 - 4*i -: 4] = 4'h6;
             4'h3: s_box_output[63 - 4*i -: 4] = 4'hB;
             4'h4: s_box_output[63 - 4*i -: 4] = 4'h9;
             4'h5: s_box_output[63 - 4*i -: 4] = 4'h0;
             4'h6: s_box_output[63 - 4*i -: 4] = 4'hA;
             4'h7: s_box_output[63 - 4*i -: 4] = 4'hD;
             4'h8: s_box_output[63 - 4*i -: 4] = 4'h3;
             4'h9: s_box_output[63 - 4*i -: 4] = 4'hE;
             4'hA: s_box_output[63 - 4*i -: 4] = 4'hF;
             4'hB: s_box_output[63 - 4*i -: 4] = 4'h8;
             4'hC: s_box_output[63 - 4*i -: 4] = 4'h4;
             4'hD: s_box_output[63 - 4*i -: 4] = 4'h7;
             4'hE: s_box_output[63 - 4*i -: 4] = 4'h1;
             4'hF: s_box_output[63 - 4*i -: 4] = 4'h2;
             default: s_box_ouput[63 - 4*1 -: 4] = 4'h0;
        
          endcase

        end


    end

endmodule


// this is the p_layer 
/* what is basically does is that it moves the bits around based on the calculatoin:

   p(i) = (16 x i) mod 63

   p is the the position that the bit will move to and i is the current bit

*/

module p_layer (
    input wire [63:0] s_box_ouput,
    input wire clk,
    output wire [63:0] p_layer_output
);


    genvar i;

    generate 

        // This is the calculation bit
        
        for (i = 0; i < 63; i = i + 1) begin
            assign p_layer_output[(16*i) % 63] = s_box_done[i];
        end

    endgenerate


    assign p_layer_output[63] = s_box_output[63];








        




