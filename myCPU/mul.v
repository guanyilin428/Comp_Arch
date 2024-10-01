`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/10/02 14:53:11
// Design Name: 
// Module Name: mul
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

module mul(
    input mul_clk,
    input reset, 
    input mul_signed,
    input [31:0]x,
    input [31:0]y,
    output[63:0]result
    );
    assign result=product[63:0];
    wire [32:0]A;
    wire [32:0]B;
    assign A={{mul_signed & x[31]},x[31:0]};
    assign B={{mul_signed & y[31]},y[31:0]};
    
    wire  [65:0]product;//33*33
    wire [65:0]A0;
    assign A0={{33{A[32]}},A[32:0]};
    wire [65:0] p [16:0];//width:66,depth:17
    wire [16:0]c;
    reg  [16:0]c_r;
    wire [65:0]S;
    reg [65:0]S_r;
    wire [65:0]C;
    wire [65:0]C0;
    assign C0={C[64:0],c[14]};//C62--C0,c14
    reg [65:0]C0_r;
    wire [13:0]cout[65:0];//66 wallace tree
    wire res_cout;
    assign {res_cout,product}=S_r+C0_r+c_r[15];
    always @(posedge mul_clk)
    begin
        if (reset)
        begin
            S_r         <= 66'd0;
            C0_r        <= 66'd0;
            c_r         <= 17'd0;
        end
        else
        begin
            S_r         <= S;
            C0_r        <= C0;
            c_r         <= c;
        end
    end

 
    booth b_0(
            .y2(B[1]),
            .y1(B[0]),
            .y0(0),
            .X(A0),
            .p(p[0]),
            .c(c[0])
    );
    genvar i;
    generate for(i=1;i<16;i=i+1)
        begin:gfor0
            booth b(
                .y2(B[2*i+1]),
                .y1(B[2*i]),
                .y0(B[2*i-1]),
                .X(A0<<2*i),
                .p(p[i]),
                .c(c[i])
            );
         end
    endgenerate
    booth b_16(
            .y2(B[32]),
            .y1(B[32]),
            .y0(B[31]),
            .X(A0<<2*16),
            .p(p[16]),
            .c(c[16])
    );
    wallace w(
        .n0(p[0][0]),
        .n1(p[1][0]),
        .n2(p[2][0]),
        .n3(p[3][0]),
        .n4(p[4][0]),
        .n5(p[5][0]),
        .n6(p[6][0]),
        .n7(p[7][0]),
        .n8(p[8][0]),
        .n9(p[9][0]),
        .n10(p[10][0]),
        .n11(p[11][0]),
        .n12(p[12][0]),
        .n13(p[13][0]),
        .n14(p[14][0]),
        .n15(p[15][0]),
        .n16(p[16][0]),
        .cin0(c[0]),
        .cin1(c[1]),
        .cin2(c[2]),
        .cin3(c[3]),
        .cin4(c[4]),
        .cin5(c[5]),
        .cin6(c[6]),
        .cin7(c[7]),
        .cin8(c[8]),
        .cin9(c[9]),
        .cin10(c[10]),
        .cin11(c[11]),
        .cin12(c[12]),
        .cin13(c[13]),
        .c11(cout[0][0]),
        .c12(cout[0][1]),
        .c13(cout[0][2]),
        .c14(cout[0][3]),
        .c15(cout[0][4]),
        .c21(cout[0][5]),
        .c22(cout[0][6]),
        .c23(cout[0][7]),
        .c24(cout[0][8]),
        .c31(cout[0][9]),
        .c32(cout[0][10]),
        .c41(cout[0][11]),
        .c42(cout[0][12]),
        .c51(cout[0][13]),
        .c61(C[0]),
        .s61(S[0])
    );
    generate for(i=1;i<66;i=i+1)
        begin:gfor1
            wallace w(
                .n0(p[0][i]),
                .n1(p[1][i]),
                .n2(p[2][i]),
                .n3(p[3][i]),
                .n4(p[4][i]),
                .n5(p[5][i]),
                .n6(p[6][i]),
                .n7(p[7][i]),
                .n8(p[8][i]),
                .n9(p[9][i]),
                .n10(p[10][i]),
                .n11(p[11][i]),
                .n12(p[12][i]),
                .n13(p[13][i]),
                .n14(p[14][i]),
                .n15(p[15][i]),
                .n16(p[16][i]),
                .cin0(cout[i-1][0]),
                .cin1(cout[i-1][1]),
                .cin2(cout[i-1][2]),
                .cin3(cout[i-1][3]),
                .cin4(cout[i-1][4]),
                .cin5(cout[i-1][5]),
                .cin6(cout[i-1][6]),
                .cin7(cout[i-1][7]),
                .cin8(cout[i-1][8]),
                .cin9(cout[i-1][9]),
                .cin10(cout[i-1][10]),
                .cin11(cout[i-1][11]),
                .cin12(cout[i-1][12]),
                .cin13(cout[i-1][13]),
                .c11(cout[i][0]),
                .c12(cout[i][1]),
                .c13(cout[i][2]),
                .c14(cout[i][3]),
                .c15(cout[i][4]),
                .c21(cout[i][5]),
                .c22(cout[i][6]),
                .c23(cout[i][7]),
                .c24(cout[i][8]),
                .c31(cout[i][9]),
                .c32(cout[i][10]),
                .c41(cout[i][11]),
                .c42(cout[i][12]),
                .c51(cout[i][13]),
                .c61(C[i]),
                .s61(S[i])
            );
        end
    endgenerate
endmodule
module booth(
    input y2,
    input y1,
    input y0,
    input [65:0] X,
    output [65:0] p,
    output c
);
    wire addx,add2x,subx,sub2x;
    assign addx = ~y2&y1&~y0|~y2&~y1&y0;
    assign add2x = ~y2&y1&y0;
    assign subx = y2&y1&~y0|y2&~y1&y0;
    assign sub2x = y2&~y1&~y0;
    assign c = subx | sub2x;
    assign p[0] = subx&~X[0] | addx&X[0] | sub2x;
    genvar nbit;
    generate 
        for(nbit = 1; nbit<66; nbit = nbit+1)
            begin: tmp
                assign p[nbit] = subx&~X[nbit]|sub2x&~X[nbit-1]|addx&X[nbit]|add2x&X[nbit-1];
            end   
    endgenerate
endmodule


module Full_adder(
    input A,
    input B,
    input cin,
    output sum,
    output cout
);
    assign sum = ~A & ~B & cin | ~A & B & ~cin | A & ~B & ~cin | A & B & cin;
    assign cout = A & B | A & cin | B & cin;

endmodule

/*module Semi_adder(
    input A,
    input B,
    output sum,
    output cout
);
    assign sum=~A & B | A & ~B;
    assign cout= A & B;

endmodule*/
module wallace(
    input n0,
    input n1,
    input n2,
    input n3,
    input n4,
    input n5,
    input n6,
    input n7,
    input n8,
    input n9,
    input n10,
    input n11,
    input n12,
    input n13,
    input n14,
    input n15,
    input n16,
    input cin0,
    input cin1,
    input cin2,
    input cin3,
    input cin4,
    input cin5,
    input cin6,
    input cin7,
    input cin8,
    input cin9,
    input cin10,
    input cin11,
    input cin12,
    input cin13,
    output c11,
    output c12,
    output c13,
    output c14,
    output c15,
    output c21,
    output c22,
    output c23,
    output c24,
    output c31,
    output c32,
    output c41,
    output c42,
    output c51,
    output c61,
    output s61
);
    wire s11,s12,s13,s14,s15;
    wire s21,s22,s23,s24;
    wire s31,s32;
    wire s41,s42;
    wire s51;
    
    Full_adder a11(
        .A(n0),
        .B(n1),
        .cin(n2),
        .sum(s11),
        .cout(c11)
    );
    Full_adder a12(
        .A(n3),
        .B(n4),
        .cin(n5),
        .sum(s12),
        .cout(c12)
    );
    Full_adder a13(
        .A(n6),
        .B(n7),
        .cin(n8),
        .sum(s13),
        .cout(c13)
    );
    Full_adder a14(
        .A(n9),
        .B(n10),
        .cin(n11),
        .sum(s14),
        .cout(c14)
    );
    Full_adder a15(
        .A(n12),
        .B(n13),
        .cin(n14),
        .sum(s15),
        .cout(c15)
    );
    Full_adder a21(
        .A(s11),
        .B(s12),
        .cin(s13),
        .sum(s21),
        .cout(c21)
    );
    Full_adder a22(
        .A(s14),
        .B(s15),
        .cin(n15),
        .sum(s22),
        .cout(c22)
    );
    Full_adder a23(
        .A(cin0),
        .B(cin1),
        .cin(cin2),
        .sum(s23),
        .cout(c23)
    );
    Full_adder a24(
        .A(cin3),
        .B(cin4),
        .cin(n16),
        .sum(s24),
        .cout(c24)
    );
    Full_adder a31(
        .A(s21),
        .B(s22),
        .cin(s23),
        .sum(s31),
        .cout(c31)
    );
    Full_adder a32(
        .A(s24),
        .B(cin5),
        .cin(cin6),
        .sum(s32),
        .cout(c32)
    );
    Full_adder a41(
        .A(s31),
        .B(s32),
        .cin(cin7),
        .sum(s41),
        .cout(c41)
    );
    Full_adder a42(
        .A(cin8),
        .B(cin9),
        .cin(cin10),
        .sum(s42),
        .cout(c42)
    );
    Full_adder a51(
        .A(s41),
        .B(s42),
        .cin(cin11),
        .sum(s51),
        .cout(c51)
    );
    Full_adder a61(
        .A(s51),
        .B(cin12),
        .cin(cin13),
        .sum(s61),
        .cout(c61)
    );
endmodule

