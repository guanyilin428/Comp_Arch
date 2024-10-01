`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/11/27 19:42:58
// Design Name: 
// Module Name: tlb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
module tlb
#(
    parameter TLBNUM = 16
)
(
    input clk,
    // search port 0 (for fetch)
    input [ 18:0] s0_vppn,
    input s0_va_bit12,
    input [ 9:0] s0_asid,
    output s0_found,
    output [$clog2(TLBNUM)-1:0] s0_index,
    output [ 19:0] s0_ppn,
    output [ 5:0] s0_ps,
    output [ 1:0] s0_plv,
    output [ 1:0] s0_mat,
    output s0_d,
    output s0_v,
    // search port 1 (for load/store)
    input [ 18:0] s1_vppn,
    input s1_va_bit12,
    input [ 9:0] s1_asid,
    output s1_found,
    output [$clog2(TLBNUM)-1:0] s1_index,
    output [ 19:0] s1_ppn,
    output [ 5:0] s1_ps,
    output [ 1:0] s1_plv,
    output [ 1:0] s1_mat,
    output s1_d,
    output s1_v,
    // invtlb opcode
    input        invtlb_valid,
    input [ 4:0] invtlb_op,
    // write port
    input we, //w(rite) e(nable)
    input [$clog2(TLBNUM)-1:0] w_index,
    input w_e,
    input [ 18:0] w_vppn,
    input [ 5:0] w_ps,
    input [ 9:0] w_asid,
    input w_g,
    input [ 19:0] w_ppn0,
    input [ 1:0] w_plv0,
    input [ 1:0] w_mat0,
    input w_d0,
    input w_v0,
    input [ 19:0] w_ppn1,
    input [ 1:0] w_plv1,
    input [ 1:0] w_mat1,
    input w_d1,
    input w_v1,
    // read port
    input [$clog2(TLBNUM)-1:0] r_index,
    output r_e,
    output [ 18:0] r_vppn,
    output [ 5:0] r_ps,
    output [ 9:0] r_asid,
    output r_g,
    output [ 19:0] r_ppn0,
    output [ 1:0] r_plv0,
    output [ 1:0] r_mat0,
    output r_d0,
    output r_v0,
    output [ 19:0] r_ppn1,
    output [ 1:0] r_plv1,
    output [ 1:0] r_mat1,
    output r_d1,
    output r_v1
);
reg [TLBNUM-1:0] tlb_e;
reg [TLBNUM-1:0] tlb_ps4MB; //pagesize 1:4MB, 0:4KB
reg [ 18:0] tlb_vppn [TLBNUM-1:0];
reg [ 9:0] tlb_asid [TLBNUM-1:0];
reg tlb_g [TLBNUM-1:0];

reg [ 19:0] tlb_ppn0 [TLBNUM-1:0];
reg [ 1:0] tlb_plv0 [TLBNUM-1:0];
reg [ 1:0] tlb_mat0 [TLBNUM-1:0];
reg tlb_d0 [TLBNUM-1:0];
reg tlb_v0 [TLBNUM-1:0];

reg [ 19:0] tlb_ppn1 [TLBNUM-1:0];
reg [ 1:0] tlb_plv1 [TLBNUM-1:0];
reg [ 1:0] tlb_mat1 [TLBNUM-1:0];
reg tlb_d1 [TLBNUM-1:0];
reg tlb_v1 [TLBNUM-1:0];

wire [TLBNUM-1:0] match0;
wire [TLBNUM-1:0] match1;
wire s0_ps_is_22;
wire s1_ps_is_22;

genvar i;
generate
    for (i = 0; i < TLBNUM; i = i + 1) begin
        assign match0[i] = (s0_vppn[18:10]==tlb_vppn[i][18:10])
                        && (tlb_ps4MB[i] || s0_vppn[9:0]==tlb_vppn[i][9:0])
                        && ((s0_asid==tlb_asid[i]) || tlb_g[i])
                        && tlb_e[i];
        assign match1[i] = (s1_vppn[18:10]==tlb_vppn[i][18:10])
                        && (tlb_ps4MB[i] || s1_vppn[9:0]==tlb_vppn[i][9:0])
                        && ((s1_asid==tlb_asid[i]) || tlb_g[i])
                        && tlb_e[i];
    end
endgenerate

always @(posedge clk)begin
  if(we)begin
    tlb_ps4MB[w_index] <= w_ps[4];//22=10110,12=01100
    tlb_vppn [w_index] <= w_vppn;
    tlb_asid [w_index] <= w_asid;
    tlb_g    [w_index] <= w_g;
    tlb_ppn0 [w_index] <= w_ppn0;
    tlb_ppn1 [w_index] <= w_ppn1;
    tlb_plv0 [w_index] <= w_plv0;
    tlb_plv1 [w_index] <= w_plv1;
    tlb_mat0 [w_index] <= w_mat0;
    tlb_mat1 [w_index] <= w_mat1;
    tlb_d0   [w_index] <= w_d0;
    tlb_d1   [w_index] <= w_d1;
    tlb_v0   [w_index] <= w_v0;
    tlb_v1   [w_index] <= w_v1;
  end
end

assign r_e    = tlb_e    [r_index];
assign r_vppn = tlb_vppn [r_index];
assign r_ps   = tlb_ps4MB[r_index] ? 6'd22 : 6'd12;
assign r_asid = tlb_asid [r_index];
assign r_g    = tlb_g    [r_index];
assign r_ppn0 = tlb_ppn0 [r_index];
assign r_ppn1 = tlb_ppn1 [r_index];
assign r_plv0 = tlb_plv0 [r_index];
assign r_plv1 = tlb_plv1 [r_index];
assign r_mat0 = tlb_mat0 [r_index];
assign r_mat1 = tlb_mat1 [r_index];
assign r_d0   = tlb_d0   [r_index];
assign r_d1   = tlb_d1   [r_index];
assign r_v0   = tlb_v0   [r_index];
assign r_v1   = tlb_v1   [r_index];

assign s0_found = |match0;
assign s1_found = |match1;

assign s0_index = ({4{match0[ 0]}} & 4'd0)
                | ({4{match0[ 1]}} & 4'd1)
                | ({4{match0[ 2]}} & 4'd2)
                | ({4{match0[ 3]}} & 4'd3)
                | ({4{match0[ 4]}} & 4'd4)
                | ({4{match0[ 5]}} & 4'd5)
                | ({4{match0[ 6]}} & 4'd6)
                | ({4{match0[ 7]}} & 4'd7)
                | ({4{match0[ 8]}} & 4'd8)
                | ({4{match0[ 9]}} & 4'd9)
                | ({4{match0[10]}} & 4'd10)
                | ({4{match0[11]}} & 4'd11)
                | ({4{match0[12]}} & 4'd12)
                | ({4{match0[13]}} & 4'd13)
                | ({4{match0[14]}} & 4'd14)
                | ({4{match0[15]}} & 4'd15);

assign s1_index = ({4{match1[ 0]}} & 4'd0)
                | ({4{match1[ 1]}} & 4'd1)
                | ({4{match1[ 2]}} & 4'd2)
                | ({4{match1[ 3]}} & 4'd3)
                | ({4{match1[ 4]}} & 4'd4)
                | ({4{match1[ 5]}} & 4'd5)
                | ({4{match1[ 6]}} & 4'd6)
                | ({4{match1[ 7]}} & 4'd7)
                | ({4{match1[ 8]}} & 4'd8)
                | ({4{match1[ 9]}} & 4'd9)
                | ({4{match1[10]}} & 4'd10)
                | ({4{match1[11]}} & 4'd11)
                | ({4{match1[12]}} & 4'd12)
                | ({4{match1[13]}} & 4'd13)
                | ({4{match1[14]}} & 4'd14)
                | ({4{match1[15]}} & 4'd15);            
  
assign s0_ppn = ({20{match0[ 0]}} & (tlb_ps4MB[ 0] ? (s0_vppn[9] ? tlb_ppn1[ 0] : tlb_ppn0[ 0]) : (s0_va_bit12 ? tlb_ppn1[ 0] : tlb_ppn0[ 0])))
              | ({20{match0[ 1]}} & (tlb_ps4MB[ 1] ? (s0_vppn[9] ? tlb_ppn1[ 1] : tlb_ppn0[ 1]) : (s0_va_bit12 ? tlb_ppn1[ 1] : tlb_ppn0[ 1])))
              | ({20{match0[ 2]}} & (tlb_ps4MB[ 2] ? (s0_vppn[9] ? tlb_ppn1[ 2] : tlb_ppn0[ 2]) : (s0_va_bit12 ? tlb_ppn1[ 2] : tlb_ppn0[ 2])))
              | ({20{match0[ 3]}} & (tlb_ps4MB[ 3] ? (s0_vppn[9] ? tlb_ppn1[ 3] : tlb_ppn0[ 3]) : (s0_va_bit12 ? tlb_ppn1[ 3] : tlb_ppn0[ 3])))
              | ({20{match0[ 4]}} & (tlb_ps4MB[ 4] ? (s0_vppn[9] ? tlb_ppn1[ 4] : tlb_ppn0[ 4]) : (s0_va_bit12 ? tlb_ppn1[ 4] : tlb_ppn0[ 4])))
              | ({20{match0[ 5]}} & (tlb_ps4MB[ 5] ? (s0_vppn[9] ? tlb_ppn1[ 5] : tlb_ppn0[ 5]) : (s0_va_bit12 ? tlb_ppn1[ 5] : tlb_ppn0[ 5])))
              | ({20{match0[ 6]}} & (tlb_ps4MB[ 6] ? (s0_vppn[9] ? tlb_ppn1[ 6] : tlb_ppn0[ 6]) : (s0_va_bit12 ? tlb_ppn1[ 6] : tlb_ppn0[ 6])))
              | ({20{match0[ 7]}} & (tlb_ps4MB[ 7] ? (s0_vppn[9] ? tlb_ppn1[ 7] : tlb_ppn0[ 7]) : (s0_va_bit12 ? tlb_ppn1[ 7] : tlb_ppn0[ 7])))
              | ({20{match0[ 8]}} & (tlb_ps4MB[ 8] ? (s0_vppn[9] ? tlb_ppn1[ 8] : tlb_ppn0[ 8]) : (s0_va_bit12 ? tlb_ppn1[ 8] : tlb_ppn0[ 8])))
              | ({20{match0[ 9]}} & (tlb_ps4MB[ 9] ? (s0_vppn[9] ? tlb_ppn1[ 9] : tlb_ppn0[ 9]) : (s0_va_bit12 ? tlb_ppn1[ 9] : tlb_ppn0[ 9])))
              | ({20{match0[10]}} & (tlb_ps4MB[10] ? (s0_vppn[9] ? tlb_ppn1[10] : tlb_ppn0[10]) : (s0_va_bit12 ? tlb_ppn1[10] : tlb_ppn0[10])))
              | ({20{match0[11]}} & (tlb_ps4MB[11] ? (s0_vppn[9] ? tlb_ppn1[11] : tlb_ppn0[11]) : (s0_va_bit12 ? tlb_ppn1[11] : tlb_ppn0[11])))
              | ({20{match0[12]}} & (tlb_ps4MB[12] ? (s0_vppn[9] ? tlb_ppn1[12] : tlb_ppn0[12]) : (s0_va_bit12 ? tlb_ppn1[12] : tlb_ppn0[12])))
              | ({20{match0[13]}} & (tlb_ps4MB[13] ? (s0_vppn[9] ? tlb_ppn1[13] : tlb_ppn0[13]) : (s0_va_bit12 ? tlb_ppn1[13] : tlb_ppn0[13])))
              | ({20{match0[14]}} & (tlb_ps4MB[14] ? (s0_vppn[9] ? tlb_ppn1[14] : tlb_ppn0[14]) : (s0_va_bit12 ? tlb_ppn1[14] : tlb_ppn0[14])))
              | ({20{match0[15]}} & (tlb_ps4MB[15] ? (s0_vppn[9] ? tlb_ppn1[15] : tlb_ppn0[15]) : (s0_va_bit12 ? tlb_ppn1[15] : tlb_ppn0[15])));

assign s1_ppn = ({20{match1[ 0]}} & (tlb_ps4MB[ 0] ? (s1_vppn[9] ? tlb_ppn1[ 0] : tlb_ppn0[ 0]) : (s1_va_bit12 ? tlb_ppn1[ 0] : tlb_ppn0[ 0])))
              | ({20{match1[ 1]}} & (tlb_ps4MB[ 1] ? (s1_vppn[9] ? tlb_ppn1[ 1] : tlb_ppn0[ 1]) : (s1_va_bit12 ? tlb_ppn1[ 1] : tlb_ppn0[ 1]))) 
              | ({20{match1[ 2]}} & (tlb_ps4MB[ 2] ? (s1_vppn[9] ? tlb_ppn1[ 2] : tlb_ppn0[ 2]) : (s1_va_bit12 ? tlb_ppn1[ 2] : tlb_ppn0[ 2])))
              | ({20{match1[ 3]}} & (tlb_ps4MB[ 3] ? (s1_vppn[9] ? tlb_ppn1[ 3] : tlb_ppn0[ 3]) : (s1_va_bit12 ? tlb_ppn1[ 3] : tlb_ppn0[ 3])))
              | ({20{match1[ 4]}} & (tlb_ps4MB[ 4] ? (s1_vppn[9] ? tlb_ppn1[ 4] : tlb_ppn0[ 4]) : (s1_va_bit12 ? tlb_ppn1[ 4] : tlb_ppn0[ 4])))
              | ({20{match1[ 5]}} & (tlb_ps4MB[ 5] ? (s1_vppn[9] ? tlb_ppn1[ 5] : tlb_ppn0[ 5]) : (s1_va_bit12 ? tlb_ppn1[ 5] : tlb_ppn0[ 5])))
              | ({20{match1[ 6]}} & (tlb_ps4MB[ 6] ? (s1_vppn[9] ? tlb_ppn1[ 6] : tlb_ppn0[ 6]) : (s1_va_bit12 ? tlb_ppn1[ 6] : tlb_ppn0[ 6])))
              | ({20{match1[ 7]}} & (tlb_ps4MB[ 7] ? (s1_vppn[9] ? tlb_ppn1[ 7] : tlb_ppn0[ 7]) : (s1_va_bit12 ? tlb_ppn1[ 7] : tlb_ppn0[ 7])))
              | ({20{match1[ 8]}} & (tlb_ps4MB[ 8] ? (s1_vppn[9] ? tlb_ppn1[ 8] : tlb_ppn0[ 8]) : (s1_va_bit12 ? tlb_ppn1[ 8] : tlb_ppn0[ 8])))
              | ({20{match1[ 9]}} & (tlb_ps4MB[ 9] ? (s1_vppn[9] ? tlb_ppn1[ 9] : tlb_ppn0[ 9]) : (s1_va_bit12 ? tlb_ppn1[ 9] : tlb_ppn0[ 9])))
              | ({20{match1[10]}} & (tlb_ps4MB[10] ? (s1_vppn[9] ? tlb_ppn1[10] : tlb_ppn0[10]) : (s1_va_bit12 ? tlb_ppn1[10] : tlb_ppn0[10])))
              | ({20{match1[11]}} & (tlb_ps4MB[11] ? (s1_vppn[9] ? tlb_ppn1[11] : tlb_ppn0[11]) : (s1_va_bit12 ? tlb_ppn1[11] : tlb_ppn0[11])))
              | ({20{match1[12]}} & (tlb_ps4MB[12] ? (s1_vppn[9] ? tlb_ppn1[12] : tlb_ppn0[12]) : (s1_va_bit12 ? tlb_ppn1[12] : tlb_ppn0[12])))
              | ({20{match1[13]}} & (tlb_ps4MB[13] ? (s1_vppn[9] ? tlb_ppn1[13] : tlb_ppn0[13]) : (s1_va_bit12 ? tlb_ppn1[13] : tlb_ppn0[13])))
              | ({20{match1[14]}} & (tlb_ps4MB[14] ? (s1_vppn[9] ? tlb_ppn1[14] : tlb_ppn0[14]) : (s1_va_bit12 ? tlb_ppn1[14] : tlb_ppn0[14])))
              | ({20{match1[15]}} & (tlb_ps4MB[15] ? (s1_vppn[9] ? tlb_ppn1[15] : tlb_ppn0[15]) : (s1_va_bit12 ? tlb_ppn1[15] : tlb_ppn0[15])));

assign s0_plv = ({2{match0[ 0]}} & (tlb_ps4MB[ 0] ? (s0_vppn[9] ? tlb_plv1[ 0] : tlb_plv0[ 0]) : (s0_va_bit12 ? tlb_plv1[ 0] : tlb_plv0[ 0])))
              | ({2{match0[ 1]}} & (tlb_ps4MB[ 1] ? (s0_vppn[9] ? tlb_plv1[ 1] : tlb_plv0[ 1]) : (s0_va_bit12 ? tlb_plv1[ 1] : tlb_plv0[ 1]))) 
              | ({2{match0[ 2]}} & (tlb_ps4MB[ 2] ? (s0_vppn[9] ? tlb_plv1[ 2] : tlb_plv0[ 2]) : (s0_va_bit12 ? tlb_plv1[ 2] : tlb_plv0[ 2])))
              | ({2{match0[ 3]}} & (tlb_ps4MB[ 3] ? (s0_vppn[9] ? tlb_plv1[ 3] : tlb_plv0[ 3]) : (s0_va_bit12 ? tlb_plv1[ 3] : tlb_plv0[ 3])))
              | ({2{match0[ 4]}} & (tlb_ps4MB[ 4] ? (s0_vppn[9] ? tlb_plv1[ 4] : tlb_plv0[ 4]) : (s0_va_bit12 ? tlb_plv1[ 4] : tlb_plv0[ 4])))
              | ({2{match0[ 5]}} & (tlb_ps4MB[ 5] ? (s0_vppn[9] ? tlb_plv1[ 5] : tlb_plv0[ 5]) : (s0_va_bit12 ? tlb_plv1[ 5] : tlb_plv0[ 5])))
              | ({2{match0[ 6]}} & (tlb_ps4MB[ 6] ? (s0_vppn[9] ? tlb_plv1[ 6] : tlb_plv0[ 6]) : (s0_va_bit12 ? tlb_plv1[ 6] : tlb_plv0[ 6])))
              | ({2{match0[ 7]}} & (tlb_ps4MB[ 7] ? (s0_vppn[9] ? tlb_plv1[ 7] : tlb_plv0[ 7]) : (s0_va_bit12 ? tlb_plv1[ 7] : tlb_plv0[ 7])))
              | ({2{match0[ 8]}} & (tlb_ps4MB[ 8] ? (s0_vppn[9] ? tlb_plv1[ 8] : tlb_plv0[ 8]) : (s0_va_bit12 ? tlb_plv1[ 8] : tlb_plv0[ 8])))
              | ({2{match0[ 9]}} & (tlb_ps4MB[ 9] ? (s0_vppn[9] ? tlb_plv1[ 9] : tlb_plv0[ 9]) : (s0_va_bit12 ? tlb_plv1[ 9] : tlb_plv0[ 9])))
              | ({2{match0[10]}} & (tlb_ps4MB[10] ? (s0_vppn[9] ? tlb_plv1[10] : tlb_plv0[10]) : (s0_va_bit12 ? tlb_plv1[10] : tlb_plv0[10])))
              | ({2{match0[11]}} & (tlb_ps4MB[11] ? (s0_vppn[9] ? tlb_plv1[11] : tlb_plv0[11]) : (s0_va_bit12 ? tlb_plv1[11] : tlb_plv0[11])))
              | ({2{match0[12]}} & (tlb_ps4MB[12] ? (s0_vppn[9] ? tlb_plv1[12] : tlb_plv0[12]) : (s0_va_bit12 ? tlb_plv1[12] : tlb_plv0[12])))
              | ({2{match0[13]}} & (tlb_ps4MB[13] ? (s0_vppn[9] ? tlb_plv1[13] : tlb_plv0[13]) : (s0_va_bit12 ? tlb_plv1[13] : tlb_plv0[13])))
              | ({2{match0[14]}} & (tlb_ps4MB[14] ? (s0_vppn[9] ? tlb_plv1[14] : tlb_plv0[14]) : (s0_va_bit12 ? tlb_plv1[14] : tlb_plv0[14])))
              | ({2{match0[15]}} & (tlb_ps4MB[15] ? (s0_vppn[9] ? tlb_plv1[15] : tlb_plv0[15]) : (s0_va_bit12 ? tlb_plv1[15] : tlb_plv0[15])));
              
assign s1_plv = ({2{match1[ 0]}} & (tlb_ps4MB[ 0] ? (s1_vppn[9] ? tlb_plv1[ 0] : tlb_plv0[ 0]) : (s1_va_bit12 ? tlb_plv1[ 0] : tlb_plv0[ 0])))
              | ({2{match1[ 1]}} & (tlb_ps4MB[ 1] ? (s1_vppn[9] ? tlb_plv1[ 1] : tlb_plv0[ 1]) : (s1_va_bit12 ? tlb_plv1[ 1] : tlb_plv0[ 1]))) 
              | ({2{match1[ 2]}} & (tlb_ps4MB[ 2] ? (s1_vppn[9] ? tlb_plv1[ 2] : tlb_plv0[ 2]) : (s1_va_bit12 ? tlb_plv1[ 2] : tlb_plv0[ 2])))
              | ({2{match1[ 3]}} & (tlb_ps4MB[ 3] ? (s1_vppn[9] ? tlb_plv1[ 3] : tlb_plv0[ 3]) : (s1_va_bit12 ? tlb_plv1[ 3] : tlb_plv0[ 3])))
              | ({2{match1[ 4]}} & (tlb_ps4MB[ 4] ? (s1_vppn[9] ? tlb_plv1[ 4] : tlb_plv0[ 4]) : (s1_va_bit12 ? tlb_plv1[ 4] : tlb_plv0[ 4])))
              | ({2{match1[ 5]}} & (tlb_ps4MB[ 5] ? (s1_vppn[9] ? tlb_plv1[ 5] : tlb_plv0[ 5]) : (s1_va_bit12 ? tlb_plv1[ 5] : tlb_plv0[ 5])))
              | ({2{match1[ 6]}} & (tlb_ps4MB[ 6] ? (s1_vppn[9] ? tlb_plv1[ 6] : tlb_plv0[ 6]) : (s1_va_bit12 ? tlb_plv1[ 6] : tlb_plv0[ 6])))
              | ({2{match1[ 7]}} & (tlb_ps4MB[ 7] ? (s1_vppn[9] ? tlb_plv1[ 7] : tlb_plv0[ 7]) : (s1_va_bit12 ? tlb_plv1[ 7] : tlb_plv0[ 7])))
              | ({2{match1[ 8]}} & (tlb_ps4MB[ 8] ? (s1_vppn[9] ? tlb_plv1[ 8] : tlb_plv0[ 8]) : (s1_va_bit12 ? tlb_plv1[ 8] : tlb_plv0[ 8])))
              | ({2{match1[ 9]}} & (tlb_ps4MB[ 9] ? (s1_vppn[9] ? tlb_plv1[ 9] : tlb_plv0[ 9]) : (s1_va_bit12 ? tlb_plv1[ 9] : tlb_plv0[ 9])))
              | ({2{match1[10]}} & (tlb_ps4MB[10] ? (s1_vppn[9] ? tlb_plv1[10] : tlb_plv0[10]) : (s1_va_bit12 ? tlb_plv1[10] : tlb_plv0[10])))
              | ({2{match1[11]}} & (tlb_ps4MB[11] ? (s1_vppn[9] ? tlb_plv1[11] : tlb_plv0[11]) : (s1_va_bit12 ? tlb_plv1[11] : tlb_plv0[11])))
              | ({2{match1[12]}} & (tlb_ps4MB[12] ? (s1_vppn[9] ? tlb_plv1[12] : tlb_plv0[12]) : (s1_va_bit12 ? tlb_plv1[12] : tlb_plv0[12])))
              | ({2{match1[13]}} & (tlb_ps4MB[13] ? (s1_vppn[9] ? tlb_plv1[13] : tlb_plv0[13]) : (s1_va_bit12 ? tlb_plv1[13] : tlb_plv0[13])))
              | ({2{match1[14]}} & (tlb_ps4MB[14] ? (s1_vppn[9] ? tlb_plv1[14] : tlb_plv0[14]) : (s1_va_bit12 ? tlb_plv1[14] : tlb_plv0[14])))
              | ({2{match1[15]}} & (tlb_ps4MB[15] ? (s1_vppn[9] ? tlb_plv1[15] : tlb_plv0[15]) : (s1_va_bit12 ? tlb_plv1[15] : tlb_plv0[15])));

assign s0_mat = ({2{match0[ 0]}} & (tlb_ps4MB[ 0] ? (s0_vppn[9] ? tlb_mat1[ 0] : tlb_mat0[ 0]) : (s0_va_bit12 ? tlb_mat1[ 0] : tlb_mat0[ 0])))
              | ({2{match0[ 1]}} & (tlb_ps4MB[ 1] ? (s0_vppn[9] ? tlb_mat1[ 1] : tlb_mat0[ 1]) : (s0_va_bit12 ? tlb_mat1[ 1] : tlb_mat0[ 1]))) 
              | ({2{match0[ 2]}} & (tlb_ps4MB[ 2] ? (s0_vppn[9] ? tlb_mat1[ 2] : tlb_mat0[ 2]) : (s0_va_bit12 ? tlb_mat1[ 2] : tlb_mat0[ 2])))
              | ({2{match0[ 3]}} & (tlb_ps4MB[ 3] ? (s0_vppn[9] ? tlb_mat1[ 3] : tlb_mat0[ 3]) : (s0_va_bit12 ? tlb_mat1[ 3] : tlb_mat0[ 3])))
              | ({2{match0[ 4]}} & (tlb_ps4MB[ 4] ? (s0_vppn[9] ? tlb_mat1[ 4] : tlb_mat0[ 4]) : (s0_va_bit12 ? tlb_mat1[ 4] : tlb_mat0[ 4])))
              | ({2{match0[ 5]}} & (tlb_ps4MB[ 5] ? (s0_vppn[9] ? tlb_mat1[ 5] : tlb_mat0[ 5]) : (s0_va_bit12 ? tlb_mat1[ 5] : tlb_mat0[ 5])))
              | ({2{match0[ 6]}} & (tlb_ps4MB[ 6] ? (s0_vppn[9] ? tlb_mat1[ 6] : tlb_mat0[ 6]) : (s0_va_bit12 ? tlb_mat1[ 6] : tlb_mat0[ 6])))
              | ({2{match0[ 7]}} & (tlb_ps4MB[ 7] ? (s0_vppn[9] ? tlb_mat1[ 7] : tlb_mat0[ 7]) : (s0_va_bit12 ? tlb_mat1[ 7] : tlb_mat0[ 7])))
              | ({2{match0[ 8]}} & (tlb_ps4MB[ 8] ? (s0_vppn[9] ? tlb_mat1[ 8] : tlb_mat0[ 8]) : (s0_va_bit12 ? tlb_mat1[ 8] : tlb_mat0[ 8])))
              | ({2{match0[ 9]}} & (tlb_ps4MB[ 9] ? (s0_vppn[9] ? tlb_mat1[ 9] : tlb_mat0[ 9]) : (s0_va_bit12 ? tlb_mat1[ 9] : tlb_mat0[ 9])))
              | ({2{match0[10]}} & (tlb_ps4MB[10] ? (s0_vppn[9] ? tlb_mat1[10] : tlb_mat0[10]) : (s0_va_bit12 ? tlb_mat1[10] : tlb_mat0[10])))
              | ({2{match0[11]}} & (tlb_ps4MB[11] ? (s0_vppn[9] ? tlb_mat1[11] : tlb_mat0[11]) : (s0_va_bit12 ? tlb_mat1[11] : tlb_mat0[11])))
              | ({2{match0[12]}} & (tlb_ps4MB[12] ? (s0_vppn[9] ? tlb_mat1[12] : tlb_mat0[12]) : (s0_va_bit12 ? tlb_mat1[12] : tlb_mat0[12])))
              | ({2{match0[13]}} & (tlb_ps4MB[13] ? (s0_vppn[9] ? tlb_mat1[13] : tlb_mat0[13]) : (s0_va_bit12 ? tlb_mat1[13] : tlb_mat0[13])))
              | ({2{match0[14]}} & (tlb_ps4MB[14] ? (s0_vppn[9] ? tlb_mat1[14] : tlb_mat0[14]) : (s0_va_bit12 ? tlb_mat1[14] : tlb_mat0[14])))
              | ({2{match0[15]}} & (tlb_ps4MB[15] ? (s0_vppn[9] ? tlb_mat1[15] : tlb_mat0[15]) : (s0_va_bit12 ? tlb_mat1[15] : tlb_mat0[15])));

assign s1_mat = ({2{match1[ 0]}} & (tlb_ps4MB[ 0] ? (s1_vppn[9] ? tlb_mat1[ 0] : tlb_mat0[ 0]) : (s1_va_bit12 ? tlb_mat1[ 0] : tlb_mat0[ 0])))
              | ({2{match1[ 1]}} & (tlb_ps4MB[ 1] ? (s1_vppn[9] ? tlb_mat1[ 1] : tlb_mat0[ 1]) : (s1_va_bit12 ? tlb_mat1[ 1] : tlb_mat0[ 1]))) 
              | ({2{match1[ 2]}} & (tlb_ps4MB[ 2] ? (s1_vppn[9] ? tlb_mat1[ 2] : tlb_mat0[ 2]) : (s1_va_bit12 ? tlb_mat1[ 2] : tlb_mat0[ 2])))
              | ({2{match1[ 3]}} & (tlb_ps4MB[ 3] ? (s1_vppn[9] ? tlb_mat1[ 3] : tlb_mat0[ 3]) : (s1_va_bit12 ? tlb_mat1[ 3] : tlb_mat0[ 3])))
              | ({2{match1[ 4]}} & (tlb_ps4MB[ 4] ? (s1_vppn[9] ? tlb_mat1[ 4] : tlb_mat0[ 4]) : (s1_va_bit12 ? tlb_mat1[ 4] : tlb_mat0[ 4])))
              | ({2{match1[ 5]}} & (tlb_ps4MB[ 5] ? (s1_vppn[9] ? tlb_mat1[ 5] : tlb_mat0[ 5]) : (s1_va_bit12 ? tlb_mat1[ 5] : tlb_mat0[ 5])))
              | ({2{match1[ 6]}} & (tlb_ps4MB[ 6] ? (s1_vppn[9] ? tlb_mat1[ 6] : tlb_mat0[ 6]) : (s1_va_bit12 ? tlb_mat1[ 6] : tlb_mat0[ 6])))
              | ({2{match1[ 7]}} & (tlb_ps4MB[ 7] ? (s1_vppn[9] ? tlb_mat1[ 7] : tlb_mat0[ 7]) : (s1_va_bit12 ? tlb_mat1[ 7] : tlb_mat0[ 7])))
              | ({2{match1[ 8]}} & (tlb_ps4MB[ 8] ? (s1_vppn[9] ? tlb_mat1[ 8] : tlb_mat0[ 8]) : (s1_va_bit12 ? tlb_mat1[ 8] : tlb_mat0[ 8])))
              | ({2{match1[ 9]}} & (tlb_ps4MB[ 9] ? (s1_vppn[9] ? tlb_mat1[ 9] : tlb_mat0[ 9]) : (s1_va_bit12 ? tlb_mat1[ 9] : tlb_mat0[ 9])))
              | ({2{match1[10]}} & (tlb_ps4MB[10] ? (s1_vppn[9] ? tlb_mat1[10] : tlb_mat0[10]) : (s1_va_bit12 ? tlb_mat1[10] : tlb_mat0[10])))
              | ({2{match1[11]}} & (tlb_ps4MB[11] ? (s1_vppn[9] ? tlb_mat1[11] : tlb_mat0[11]) : (s1_va_bit12 ? tlb_mat1[11] : tlb_mat0[11])))
              | ({2{match1[12]}} & (tlb_ps4MB[12] ? (s1_vppn[9] ? tlb_mat1[12] : tlb_mat0[12]) : (s1_va_bit12 ? tlb_mat1[12] : tlb_mat0[12])))
              | ({2{match1[13]}} & (tlb_ps4MB[13] ? (s1_vppn[9] ? tlb_mat1[13] : tlb_mat0[13]) : (s1_va_bit12 ? tlb_mat1[13] : tlb_mat0[13])))
              | ({2{match1[14]}} & (tlb_ps4MB[14] ? (s1_vppn[9] ? tlb_mat1[14] : tlb_mat0[14]) : (s1_va_bit12 ? tlb_mat1[14] : tlb_mat0[14])))
              | ({2{match1[15]}} & (tlb_ps4MB[15] ? (s1_vppn[9] ? tlb_mat1[15] : tlb_mat0[15]) : (s1_va_bit12 ? tlb_mat1[15] : tlb_mat0[15])));                          

assign s0_d   = (match0[ 0] & (tlb_ps4MB[ 0] ? (s0_vppn[9] ? tlb_d1[ 0] : tlb_d0[ 0]) : (s0_va_bit12 ? tlb_d1[ 0] : tlb_d0[ 0])))
              | (match0[ 1] & (tlb_ps4MB[ 1] ? (s0_vppn[9] ? tlb_d1[ 1] : tlb_d0[ 1]) : (s0_va_bit12 ? tlb_d1[ 1] : tlb_d0[ 1]))) 
              | (match0[ 2] & (tlb_ps4MB[ 2] ? (s0_vppn[9] ? tlb_d1[ 2] : tlb_d0[ 2]) : (s0_va_bit12 ? tlb_d1[ 2] : tlb_d0[ 2])))
              | (match0[ 3] & (tlb_ps4MB[ 3] ? (s0_vppn[9] ? tlb_d1[ 3] : tlb_d0[ 3]) : (s0_va_bit12 ? tlb_d1[ 3] : tlb_d0[ 3])))
              | (match0[ 4] & (tlb_ps4MB[ 4] ? (s0_vppn[9] ? tlb_d1[ 4] : tlb_d0[ 4]) : (s0_va_bit12 ? tlb_d1[ 4] : tlb_d0[ 4])))
              | (match0[ 5] & (tlb_ps4MB[ 5] ? (s0_vppn[9] ? tlb_d1[ 5] : tlb_d0[ 5]) : (s0_va_bit12 ? tlb_d1[ 5] : tlb_d0[ 5])))
              | (match0[ 6] & (tlb_ps4MB[ 6] ? (s0_vppn[9] ? tlb_d1[ 6] : tlb_d0[ 6]) : (s0_va_bit12 ? tlb_d1[ 6] : tlb_d0[ 6])))
              | (match0[ 7] & (tlb_ps4MB[ 7] ? (s0_vppn[9] ? tlb_d1[ 7] : tlb_d0[ 7]) : (s0_va_bit12 ? tlb_d1[ 7] : tlb_d0[ 7])))
              | (match0[ 8] & (tlb_ps4MB[ 8] ? (s0_vppn[9] ? tlb_d1[ 8] : tlb_d0[ 8]) : (s0_va_bit12 ? tlb_d1[ 8] : tlb_d0[ 8])))
              | (match0[ 9] & (tlb_ps4MB[ 9] ? (s0_vppn[9] ? tlb_d1[ 9] : tlb_d0[ 9]) : (s0_va_bit12 ? tlb_d1[ 9] : tlb_d0[ 9])))
              | (match0[10] & (tlb_ps4MB[10] ? (s0_vppn[9] ? tlb_d1[10] : tlb_d0[10]) : (s0_va_bit12 ? tlb_d1[10] : tlb_d0[10])))
              | (match0[11] & (tlb_ps4MB[11] ? (s0_vppn[9] ? tlb_d1[11] : tlb_d0[11]) : (s0_va_bit12 ? tlb_d1[11] : tlb_d0[11])))
              | (match0[12] & (tlb_ps4MB[12] ? (s0_vppn[9] ? tlb_d1[12] : tlb_d0[12]) : (s0_va_bit12 ? tlb_d1[12] : tlb_d0[12])))
              | (match0[13] & (tlb_ps4MB[13] ? (s0_vppn[9] ? tlb_d1[13] : tlb_d0[13]) : (s0_va_bit12 ? tlb_d1[13] : tlb_d0[13])))
              | (match0[14] & (tlb_ps4MB[14] ? (s0_vppn[9] ? tlb_d1[14] : tlb_d0[14]) : (s0_va_bit12 ? tlb_d1[14] : tlb_d0[14])))
              | (match0[15] & (tlb_ps4MB[15] ? (s0_vppn[9] ? tlb_d1[15] : tlb_d0[15]) : (s0_va_bit12 ? tlb_d1[15] : tlb_d0[15])));

assign s1_d   = (match1[ 0] & (tlb_ps4MB[ 0] ? (s1_vppn[9] ? tlb_d1[ 0] : tlb_d0[ 0]) : (s1_va_bit12 ? tlb_d1[ 0] : tlb_d0[ 0])))
              | (match1[ 1] & (tlb_ps4MB[ 1] ? (s1_vppn[9] ? tlb_d1[ 1] : tlb_d0[ 1]) : (s1_va_bit12 ? tlb_d1[ 1] : tlb_d0[ 1]))) 
              | (match1[ 2] & (tlb_ps4MB[ 2] ? (s1_vppn[9] ? tlb_d1[ 2] : tlb_d0[ 2]) : (s1_va_bit12 ? tlb_d1[ 2] : tlb_d0[ 2])))
              | (match1[ 3] & (tlb_ps4MB[ 3] ? (s1_vppn[9] ? tlb_d1[ 3] : tlb_d0[ 3]) : (s1_va_bit12 ? tlb_d1[ 3] : tlb_d0[ 3])))
              | (match1[ 4] & (tlb_ps4MB[ 4] ? (s1_vppn[9] ? tlb_d1[ 4] : tlb_d0[ 4]) : (s1_va_bit12 ? tlb_d1[ 4] : tlb_d0[ 4])))
              | (match1[ 5] & (tlb_ps4MB[ 5] ? (s1_vppn[9] ? tlb_d1[ 5] : tlb_d0[ 5]) : (s1_va_bit12 ? tlb_d1[ 5] : tlb_d0[ 5])))
              | (match1[ 6] & (tlb_ps4MB[ 6] ? (s1_vppn[9] ? tlb_d1[ 6] : tlb_d0[ 6]) : (s1_va_bit12 ? tlb_d1[ 6] : tlb_d0[ 6])))
              | (match1[ 7] & (tlb_ps4MB[ 7] ? (s1_vppn[9] ? tlb_d1[ 7] : tlb_d0[ 7]) : (s1_va_bit12 ? tlb_d1[ 7] : tlb_d0[ 7])))
              | (match1[ 8] & (tlb_ps4MB[ 8] ? (s1_vppn[9] ? tlb_d1[ 8] : tlb_d0[ 8]) : (s1_va_bit12 ? tlb_d1[ 8] : tlb_d0[ 8])))
              | (match1[ 9] & (tlb_ps4MB[ 9] ? (s1_vppn[9] ? tlb_d1[ 9] : tlb_d0[ 9]) : (s1_va_bit12 ? tlb_d1[ 9] : tlb_d0[ 9])))
              | (match1[10] & (tlb_ps4MB[10] ? (s1_vppn[9] ? tlb_d1[10] : tlb_d0[10]) : (s1_va_bit12 ? tlb_d1[10] : tlb_d0[10])))
              | (match1[11] & (tlb_ps4MB[11] ? (s1_vppn[9] ? tlb_d1[11] : tlb_d0[11]) : (s1_va_bit12 ? tlb_d1[11] : tlb_d0[11])))
              | (match1[12] & (tlb_ps4MB[12] ? (s1_vppn[9] ? tlb_d1[12] : tlb_d0[12]) : (s1_va_bit12 ? tlb_d1[12] : tlb_d0[12])))
              | (match1[13] & (tlb_ps4MB[13] ? (s1_vppn[9] ? tlb_d1[13] : tlb_d0[13]) : (s1_va_bit12 ? tlb_d1[13] : tlb_d0[13])))
              | (match1[14] & (tlb_ps4MB[14] ? (s1_vppn[9] ? tlb_d1[14] : tlb_d0[14]) : (s1_va_bit12 ? tlb_d1[14] : tlb_d0[14])))
              | (match1[15] & (tlb_ps4MB[15] ? (s1_vppn[9] ? tlb_d1[15] : tlb_d0[15]) : (s1_va_bit12 ? tlb_d1[15] : tlb_d0[15])));                          

assign s0_v   = (match0[ 0] & (tlb_ps4MB[ 0] ? (s0_vppn[9] ? tlb_v1[ 0] : tlb_v0[ 0]) : (s0_va_bit12 ? tlb_v1[ 0] : tlb_v0[ 0])))
              | (match0[ 1] & (tlb_ps4MB[ 1] ? (s0_vppn[9] ? tlb_v1[ 1] : tlb_v0[ 1]) : (s0_va_bit12 ? tlb_v1[ 1] : tlb_v0[ 1]))) 
              | (match0[ 2] & (tlb_ps4MB[ 2] ? (s0_vppn[9] ? tlb_v1[ 2] : tlb_v0[ 2]) : (s0_va_bit12 ? tlb_v1[ 2] : tlb_v0[ 2])))
              | (match0[ 3] & (tlb_ps4MB[ 3] ? (s0_vppn[9] ? tlb_v1[ 3] : tlb_v0[ 3]) : (s0_va_bit12 ? tlb_v1[ 3] : tlb_v0[ 3])))
              | (match0[ 4] & (tlb_ps4MB[ 4] ? (s0_vppn[9] ? tlb_v1[ 4] : tlb_v0[ 4]) : (s0_va_bit12 ? tlb_v1[ 4] : tlb_v0[ 4])))
              | (match0[ 5] & (tlb_ps4MB[ 5] ? (s0_vppn[9] ? tlb_v1[ 5] : tlb_v0[ 5]) : (s0_va_bit12 ? tlb_v1[ 5] : tlb_v0[ 5])))
              | (match0[ 6] & (tlb_ps4MB[ 6] ? (s0_vppn[9] ? tlb_v1[ 6] : tlb_v0[ 6]) : (s0_va_bit12 ? tlb_v1[ 6] : tlb_v0[ 6])))
              | (match0[ 7] & (tlb_ps4MB[ 7] ? (s0_vppn[9] ? tlb_v1[ 7] : tlb_v0[ 7]) : (s0_va_bit12 ? tlb_v1[ 7] : tlb_v0[ 7])))
              | (match0[ 8] & (tlb_ps4MB[ 8] ? (s0_vppn[9] ? tlb_v1[ 8] : tlb_v0[ 8]) : (s0_va_bit12 ? tlb_v1[ 8] : tlb_v0[ 8])))
              | (match0[ 9] & (tlb_ps4MB[ 9] ? (s0_vppn[9] ? tlb_v1[ 9] : tlb_v0[ 9]) : (s0_va_bit12 ? tlb_v1[ 9] : tlb_v0[ 9])))
              | (match0[10] & (tlb_ps4MB[10] ? (s0_vppn[9] ? tlb_v1[10] : tlb_v0[10]) : (s0_va_bit12 ? tlb_v1[10] : tlb_v0[10])))
              | (match0[11] & (tlb_ps4MB[11] ? (s0_vppn[9] ? tlb_v1[11] : tlb_v0[11]) : (s0_va_bit12 ? tlb_v1[11] : tlb_v0[11])))
              | (match0[12] & (tlb_ps4MB[12] ? (s0_vppn[9] ? tlb_v1[12] : tlb_v0[12]) : (s0_va_bit12 ? tlb_v1[12] : tlb_v0[12])))
              | (match0[13] & (tlb_ps4MB[13] ? (s0_vppn[9] ? tlb_v1[13] : tlb_v0[13]) : (s0_va_bit12 ? tlb_v1[13] : tlb_v0[13])))
              | (match0[14] & (tlb_ps4MB[14] ? (s0_vppn[9] ? tlb_v1[14] : tlb_v0[14]) : (s0_va_bit12 ? tlb_v1[14] : tlb_v0[14])))
              | (match0[15] & (tlb_ps4MB[15] ? (s0_vppn[9] ? tlb_v1[15] : tlb_v0[15]) : (s0_va_bit12 ? tlb_v1[15] : tlb_v0[15])));

assign s1_v   = (match1[ 0] & (tlb_ps4MB[ 0] ? (s1_vppn[9] ? tlb_v1[ 0] : tlb_v0[ 0]) : (s1_va_bit12 ? tlb_v1[ 0] : tlb_v0[ 0])))
              | (match1[ 1] & (tlb_ps4MB[ 1] ? (s1_vppn[9] ? tlb_v1[ 1] : tlb_v0[ 1]) : (s1_va_bit12 ? tlb_v1[ 1] : tlb_v0[ 1])))
              | (match1[ 2] & (tlb_ps4MB[ 2] ? (s1_vppn[9] ? tlb_v1[ 2] : tlb_v0[ 2]) : (s1_va_bit12 ? tlb_v1[ 2] : tlb_v0[ 2])))
              | (match1[ 3] & (tlb_ps4MB[ 3] ? (s1_vppn[9] ? tlb_v1[ 3] : tlb_v0[ 3]) : (s1_va_bit12 ? tlb_v1[ 3] : tlb_v0[ 3])))
              | (match1[ 4] & (tlb_ps4MB[ 4] ? (s1_vppn[9] ? tlb_v1[ 4] : tlb_v0[ 4]) : (s1_va_bit12 ? tlb_v1[ 4] : tlb_v0[ 4])))
              | (match1[ 5] & (tlb_ps4MB[ 5] ? (s1_vppn[9] ? tlb_v1[ 5] : tlb_v0[ 5]) : (s1_va_bit12 ? tlb_v1[ 5] : tlb_v0[ 5])))
              | (match1[ 6] & (tlb_ps4MB[ 6] ? (s1_vppn[9] ? tlb_v1[ 6] : tlb_v0[ 6]) : (s1_va_bit12 ? tlb_v1[ 6] : tlb_v0[ 6])))
              | (match1[ 7] & (tlb_ps4MB[ 7] ? (s1_vppn[9] ? tlb_v1[ 7] : tlb_v0[ 7]) : (s1_va_bit12 ? tlb_v1[ 7] : tlb_v0[ 7])))
              | (match1[ 8] & (tlb_ps4MB[ 8] ? (s1_vppn[9] ? tlb_v1[ 8] : tlb_v0[ 8]) : (s1_va_bit12 ? tlb_v1[ 8] : tlb_v0[ 8])))
              | (match1[ 9] & (tlb_ps4MB[ 9] ? (s1_vppn[9] ? tlb_v1[ 9] : tlb_v0[ 9]) : (s1_va_bit12 ? tlb_v1[ 9] : tlb_v0[ 9])))
              | (match1[10] & (tlb_ps4MB[10] ? (s1_vppn[9] ? tlb_v1[10] : tlb_v0[10]) : (s1_va_bit12 ? tlb_v1[10] : tlb_v0[10])))
              | (match1[11] & (tlb_ps4MB[11] ? (s1_vppn[9] ? tlb_v1[11] : tlb_v0[11]) : (s1_va_bit12 ? tlb_v1[11] : tlb_v0[11])))
              | (match1[12] & (tlb_ps4MB[12] ? (s1_vppn[9] ? tlb_v1[12] : tlb_v0[12]) : (s1_va_bit12 ? tlb_v1[12] : tlb_v0[12])))
              | (match1[13] & (tlb_ps4MB[13] ? (s1_vppn[9] ? tlb_v1[13] : tlb_v0[13]) : (s1_va_bit12 ? tlb_v1[13] : tlb_v0[13])))
              | (match1[14] & (tlb_ps4MB[14] ? (s1_vppn[9] ? tlb_v1[14] : tlb_v0[14]) : (s1_va_bit12 ? tlb_v1[14] : tlb_v0[14])))
              | (match1[15] & (tlb_ps4MB[15] ? (s1_vppn[9] ? tlb_v1[15] : tlb_v0[15]) : (s1_va_bit12 ? tlb_v1[15] : tlb_v0[15])));                          

assign s0_ps_is_22 = match0[0] & tlb_ps4MB[0] |
                     match0[1] & tlb_ps4MB[1] |
                     match0[2] & tlb_ps4MB[2] |
                     match0[3] & tlb_ps4MB[3] |
                     match0[4] & tlb_ps4MB[4] |
                     match0[5] & tlb_ps4MB[5] |
                     match0[6] & tlb_ps4MB[6] |
                     match0[7] & tlb_ps4MB[7] |
                     match0[8] & tlb_ps4MB[8] |
                     match0[9] & tlb_ps4MB[9] |
                     match0[10] & tlb_ps4MB[10] |
                     match0[11] & tlb_ps4MB[11] |
                     match0[12] & tlb_ps4MB[12] |
                     match0[13] & tlb_ps4MB[13] |
                     match0[14] & tlb_ps4MB[14] |
                     match0[15] & tlb_ps4MB[15];

assign s1_ps_is_22 = match1[ 0] & tlb_ps4MB[ 0] |
                     match1[ 1] & tlb_ps4MB[ 1] |
                     match1[ 2] & tlb_ps4MB[ 2] |
                     match1[ 3] & tlb_ps4MB[ 3] |
                     match1[ 4] & tlb_ps4MB[ 4] |
                     match1[ 5] & tlb_ps4MB[ 5] |
                     match1[ 6] & tlb_ps4MB[ 6] |
                     match1[ 7] & tlb_ps4MB[ 7] |
                     match1[ 8] & tlb_ps4MB[ 8] |
                     match1[ 9] & tlb_ps4MB[ 9] |
                     match1[10] & tlb_ps4MB[10] |
                     match1[11] & tlb_ps4MB[11] |
                     match1[12] & tlb_ps4MB[12] |
                     match1[13] & tlb_ps4MB[13] |
                     match1[14] & tlb_ps4MB[14] |
                     match1[15] & tlb_ps4MB[15];

assign s0_ps  = {6{s0_ps_is_22}}  & 6'd22|
                {6{~s0_ps_is_22}} & 6'd12;

assign s1_ps =  {6{s1_ps_is_22}}  & 6'd22|
                {6{~s1_ps_is_22}} & 6'd12;

wire [TLBNUM-1:0] cond1;
wire [TLBNUM-1:0] cond2;
wire [TLBNUM-1:0] cond3;
wire [TLBNUM-1:0] cond4;
wire [TLBNUM-1:0] need_clean;
genvar j;
generate
  for(j=0; j< TLBNUM; j=j+1)begin
    assign cond1[j] = tlb_g[j]==0;
    assign cond2[j] = tlb_g[j]==1;
    assign cond3[j] = tlb_asid[j]==s1_asid;
    assign cond4[j] = (s1_vppn[18:10]==tlb_vppn[j][18:10])
                  && (tlb_ps4MB[j] || s1_vppn[9:0]==tlb_vppn[j][9:0]);
  
    assign need_clean[j] = (invtlb_op==5'd0 || invtlb_op==5'd1) ? (cond1[j] || cond2[j]):
                        (invtlb_op==5'd2) ? cond2[j] :
                        (invtlb_op==5'd3) ? cond1[j] :
                        (invtlb_op==5'd4) ? (cond1[j] && cond3[j]) :
                        (invtlb_op==5'd5) ? (cond1[j] && cond3[j] && cond4[j]) :
                        (invtlb_op==5'd6) ? ((cond2[j] || cond3[j]) && cond4[j]) :
                        1'b0;
    always @(posedge clk) begin
      if (we && j == w_index) begin
        tlb_e[j] <= w_e;
      end
      else if (invtlb_valid && need_clean[j]) begin
        tlb_e[j] <= 1'b0;
      end
    end
  end
endgenerate


endmodule