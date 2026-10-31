




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


// creating the plain text from a single one wire transmitter 
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


// This just updates the text so that it can go through the encyption 32 times

module current_text(
    input wire clk,
    input wire [63:0] plain_txt,
    input wire [63:0] p_layer_output,
    output reg [63:0] current_plain_txt


);
    
    initial begin
        i = 0;
    end

    genvar i;

    always @(posedge clk) begin
        if (i == 0) begin
            
            current_plain_txt <= plain_txt;

            i = i + 1;
        end

        else if ( (i > 0) & (i < 31) ) begin

            current_plain_txt <= p_layer_output;

            i <= i + 1;

        end 

        else if ( i > 31) begin

            i = 0;
        end

    end

endmodule



// this is the part that jsut does XOR with the current top 64 bits of the key
module XOR_round(
    input wire clk,
    input wire [63:0] plain_txt,
    input wire [63:0] current_plain_txt
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

endmodule


module cypher(

   // this is just the clock to time the rounds
   input wire clk
   
   // this is the key that has undergone the the changes
   input wire [63:0] current_key,
   
   // this is the current 64 bit input that is wating to be encypted
   input wire [63:0] current_text,
   
   // this is the encpryted text that has gone though the 32 rounds of encyption
   output wire [63:0] cypher_text,
   
   // this is the current encrytpion round number so that the controller will know when to feed the next text input in
   output wire [4:0] current_round
);

   // just counts the rounds
   reg [4:0] round;
   assign current_round = round;
   
   // connecting the inputs so that they can be used
   wire [63:0] text;
   assign text = current_text;
   wire {63:0] key;
   assign key = current_key;
   
   
  // just the register for the first layer
   reg [63:0] add_round_key_done;
   
   // This is the s box reg it is basically just a 2 dimensinal reg
   // The reason that it has to be split is so that each nibble can be changed
   reg [3:0] s_box_input [0:15];
   
   
   
   // this is going to be the main loop that just does the encyryption 32 times
    always @(posedge clk) begin
      
      // the counting loop
       if ( round < 32) begin
         
         // the add key round basically just doing XOR to the key and text
         add_round_key_done <= key ^ text
         
         // This is the s box layer what is does is it swaps each nibble with another predfned one
         for(i = 0; i <16; i = i + 1) begin
         
            // this splits the input into 16 nibbles
            s_box_input[i] = add_round_key_done[63 4*i -: 4];
            
            case (s_box_input[i])
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
         
         
           
         
       
        
           
       
       
       
    
    


  






        




