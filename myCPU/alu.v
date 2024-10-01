module alu(
  input         clk,
  input         reset,
  input  [18:0] alu_op,
  input  [31:0] alu_src1,
  input  [31:0] alu_src2,
  output [31:0] alu_result,
  output [31:0] mul_result,
  output        complete
);

wire op_add;   //add operation
wire op_sub;   //sub operation
wire op_slt;   //signed compared and set less than
wire op_sltu;  //unsigned compared and set less than
wire op_and;   //bitwise and
wire op_nor;   //bitwise nor
wire op_or;    //bitwise or
wire op_xor;   //bitwise xor
wire op_sll;   //logic left shift
wire op_srl;   //logic right shift
wire op_sra;   //arithmetic right shift
wire op_lui;   //Load Upper Immediate
wire op_mul_w;
wire op_mulh_w;
wire op_mulh_wu;
wire op_div_w;
wire op_mod_w;
wire op_div_wu;
wire op_mod_wu;

// control code decomposition
assign op_add  = alu_op[ 0];
assign op_sub  = alu_op[ 1];
assign op_slt  = alu_op[ 2];
assign op_sltu = alu_op[ 3];
assign op_and  = alu_op[ 4];
assign op_nor  = alu_op[ 5];
assign op_or   = alu_op[ 6];
assign op_xor  = alu_op[ 7];
assign op_sll  = alu_op[ 8];
assign op_srl  = alu_op[ 9];
assign op_sra  = alu_op[10];
assign op_lui  = alu_op[11];
assign op_mul_w   = alu_op[12];
assign op_mulh_w  = alu_op[13];
assign op_mulh_wu = alu_op[14];
assign op_div_w   = alu_op[15];
assign op_mod_w   = alu_op[16];
assign op_div_wu  = alu_op[17];
assign op_mod_wu  = alu_op[18];

wire [31:0] add_sub_result;
wire [31:0] slt_result;
wire [31:0] sltu_result;
wire [31:0] and_result;
wire [31:0] nor_result;
wire [31:0] or_result;
wire [31:0] xor_result;
wire [31:0] lui_result;
wire [31:0] sll_result;
wire [63:0] sr64_result;
wire [31:0] sr_result;
wire [63:0] mul_result_origin;
//wire [32:0] mul_src1;
//wire [32:0] mul_src2;


// 32-bit adder
wire [31:0] adder_a;
wire [31:0] adder_b;
wire        adder_cin;
wire [31:0] adder_result;
wire        adder_cout;

assign adder_a   = alu_src1;
assign adder_b   = (op_sub | op_slt | op_sltu) ? ~alu_src2 : alu_src2;  //src1 - src2 rj-rk
assign adder_cin = (op_sub | op_slt | op_sltu) ? 1'b1      : 1'b0;
assign {adder_cout, adder_result} = adder_a + adder_b + adder_cin;

// ADD, SUB result
assign add_sub_result = adder_result;

// SLT result
assign slt_result[31:1] = 31'b0;   //rj < rk 1
assign slt_result[0]    = (alu_src1[31] & ~alu_src2[31])
                        | ((alu_src1[31] ~^ alu_src2[31]) & adder_result[31]);

// SLTU result
assign sltu_result[31:1] = 31'b0;
assign sltu_result[0]    = ~adder_cout;

// bitwise operation
assign and_result = alu_src1 & alu_src2;
assign or_result  = alu_src1 | alu_src2;
assign nor_result = ~or_result;
assign xor_result = alu_src1 ^ alu_src2;
assign lui_result = alu_src2;

// SLL result
assign sll_result = alu_src1 << alu_src2[4:0];   

// SRL, SRA result
assign sr64_result = {{32{op_sra & alu_src1[31]}}, alu_src1[31:0]} >> alu_src2[4:0]; 

assign sr_result   = sr64_result[31:0];

// MUL_OPERATION
//assign mul_src1 = {op_mulh_w & alu_src1[31], alu_src1[31:0]};
//assign mul_src2 = {op_mulh_w & alu_src2[31], alu_src2[31:0]};
//assign mul_result = $signed(mul_src1) * $signed(mul_src2); 
reg op_mul_w_r;
reg op_mulh_w_r;
reg op_mulh_wu_r;
always @(posedge clk)begin
    if(reset)begin
        op_mul_w_r   <= 0;
        op_mulh_w_r  <= 0;
        op_mulh_wu_r <= 0;
    end
    else begin
        op_mul_w_r   <= op_mul_w;
        op_mulh_w_r  <= op_mulh_w;
        op_mulh_wu_r <= op_mulh_wu;
    end
end
mul mul_module(
    .mul_clk(clk),
    .reset(reset), 
    .mul_signed(op_mul_w | op_mulh_w),
    .x(alu_src1),
    .y(alu_src2),
    .result(mul_result_origin)
);
// DIV_OPERATION
reg dividend_valid;
reg divisor_valid;
wire dividend_ready;
wire divisor_ready;
wire [63:0] div_result;

reg u_dividend_valid;
reg u_divisor_valid;
wire u_dividend_ready;
wire u_divisor_ready;
wire [63:0] u_div_result;
reg signal;

wire div_complete;
wire u_div_complete;

assign complete = div_complete | u_div_complete;

always @(posedge clk) begin
  if(reset | complete) begin
    signal <= 0;
  end
  else if(dividend_valid & dividend_ready | u_dividend_ready & u_dividend_valid) begin
    signal <= 1;
  end
end

always@(posedge clk) begin
  if(reset | signal) begin
    dividend_valid <= 0;
    divisor_valid  <= 0;
  end
  else if((op_div_w | op_mod_w ) & ~dividend_ready & ~divisor_ready & ~signal) begin
    dividend_valid <= 1;
    divisor_valid  <= 1;
  end
  else if(dividend_ready | divisor_ready) begin
    dividend_valid <= 0;
    divisor_valid  <= 0;
  end
end

always@(posedge clk) begin
  if(reset | signal) begin
    u_dividend_valid <= 0;
    u_divisor_valid  <= 0;
  end
  else if((op_div_wu | op_mod_wu) & ~u_dividend_ready & ~u_divisor_ready & ~signal) begin
    u_dividend_valid <= 1;
    u_divisor_valid  <= 1;
  end
  else if(u_dividend_ready | u_divisor_ready) begin
    u_dividend_valid <= 0;
    u_divisor_valid  <= 0;
  end
end

mydiv_s sdiv_module(
  .aclk                     (clk),
  .s_axis_dividend_tvalid   (dividend_valid),
  .s_axis_divisor_tvalid    (divisor_valid),
  .s_axis_dividend_tready   (dividend_ready),
  .s_axis_divisor_tready    (divisor_ready),
  .s_axis_dividend_tdata    (alu_src1),
  .s_axis_divisor_tdata     (alu_src2),
  .m_axis_dout_tvalid       (div_complete),
  .m_axis_dout_tdata        (div_result)
);

mydiv_u udiv_module(
  .aclk                     (clk),
  .s_axis_dividend_tvalid   (u_dividend_valid),
  .s_axis_divisor_tvalid    (u_divisor_valid),
  .s_axis_dividend_tready   (u_dividend_ready),
  .s_axis_divisor_tready    (u_divisor_ready),
  .s_axis_dividend_tdata    (alu_src1),
  .s_axis_divisor_tdata     (alu_src2),
  .m_axis_dout_tvalid       (u_div_complete),
  .m_axis_dout_tdata        (u_div_result)
);

// final result mux
assign alu_result = ({32{op_add|op_sub}} & add_sub_result)
                  | ({32{op_slt       }} & slt_result)
                  | ({32{op_sltu      }} & sltu_result)
                  | ({32{op_and       }} & and_result)
                  | ({32{op_nor       }} & nor_result)
                  | ({32{op_or        }} & or_result)
                  | ({32{op_xor       }} & xor_result)
                  | ({32{op_lui       }} & lui_result)
                  | ({32{op_sll       }} & sll_result)
                  | ({32{op_srl|op_sra}} & sr_result)
                 // | ({32{op_mul_w     }} & mul_result[31:0])
                 // | ({32{op_mulh_w | op_mulh_wu}} & mul_result[63:32])
                  | ({32{op_div_w}}   & div_result[63:32])
                  | ({32{op_mod_w}}   & div_result[31:0])
                  | ({32{op_div_wu}}  & u_div_result[63:32])
                  | ({32{op_mod_wu}}  & u_div_result[31:0]);
                  
assign mul_result = ({32{op_mul_w_r     }} & mul_result_origin[31:0])
                  | ({32{op_mulh_w_r | op_mulh_wu_r}} & mul_result_origin[63:32]);
endmodule