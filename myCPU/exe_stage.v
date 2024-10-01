`include "mycpu.h"

module exe_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          ms_allowin    ,
    output                         es_allowin    ,
    //from ds
    input                          ds_to_es_valid,
    input  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    //to ms
    output                         es_to_ms_valid,
    output [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    // data sram interface
    output        data_sram_req   ,
    output        data_sram_wr    ,
    output [ 3:0] data_sram_wstrb ,
    output [31:0] data_sram_addr ,
    output [31:0] data_sram_wdata,
    input         data_sram_addr_ok,
    output [ 1:0] data_sram_size,
    output [`ES_DEST_BUS     -1:0] es_dest_bus   ,
    output [`ES_TO_DS_BUS    -1:0] es_to_ds_bus  ,
    //flush
     input                    ms_flush_es_bus,
     input                    ws_flush_es_bus,

    output                      invtlb_valid,
    output [               4:0] invtlb_op,
    
    // search port 1 (for load/store)
    output [              18:0] s1_vppn,
    output                      s1_va_bit12,
    output [               9:0] s1_asid,
    input                       s1_found,
    input  [               3:0] s1_index,
    input  [              19:0] s1_ppn,
    input  [               5:0] s1_ps,
    input  [               1:0] s1_plv,
    input  [               1:0] s1_mat,
    input                       s1_d,
    input                       s1_v,

    input [`TO_ES_CSR_BUS_WD-1:0] to_es_csr_bus,
    input                       mem_csr_tlb_w,
    input                       wb_csr_tlb_w
);

reg         es_valid      ;
wire        es_ready_go   ;
reg         es_handed     ;

reg  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus_r;
//wire        dest_valid    ;
wire        es_dest_valid ;
wire [ 2:0] es_st_op      ;
wire [ 4:0] es_ld_op      ;
wire [18:0] es_alu_op     ;
wire        es_src1_is_pc ;
wire        es_src2_is_imm; 
wire        es_gr_we      ;
wire        es_mem_we     ;
wire [ 4:0] es_dest       ;
wire [31:0] es_imm        ;
wire [31:0] es_rj_value   ;
wire [31:0] es_rkd_value  ;
wire [31:0] es_pc         ;
wire [ 3:0]sb_wen          ;
wire [ 3:0]sh_wen          ;
wire [ 3:0]sw_wen          ;
wire [ 1:0]ld_offset       ;
wire        es_res_from_mem;
wire        es_res_from_mul;
wire        es_ld_st_inst;
wire        es_div_inst;

wire [31:0] es_alu_src1   ;
wire [31:0] es_alu_src2   ;
wire [31:0] es_alu_result ;
wire        es_div_complete;
wire [31:0] es_mul_result;
wire [31:0] csr_wvalue;

reg  [63:0]stable_cnt;
wire [2:0] inst_cnt_op;
wire [31:0] cnt_value;
wire ex_ADEF;
wire ex_ALE;
wire ex_INE;
wire ex_ADEM;
wire inst_break;
wire inst_ertn;
wire inst_syscall;
wire has_exc;
wire has_int;
wire csr_we;
wire csr_re;
wire [31:0]csr_wmask;
wire [13:0]csr_num;
wire       es_ms_ws_err;

wire [31:0] csr_dmw0_rvalue;
wire [31:0] csr_dmw1_rvalue;
wire [31:0] csr_crmd_rvalue;
wire [31:0] csr_asid_rvalue;
wire [31:0] csr_tlbehi_rvalue;
wire        csr_crmd_da;
wire        csr_crmd_pg;
wire [ 1:0] csr_crmd_plv;

wire [4:0]s1_bus;
wire [4:0]tlbop;
wire [4:0]inv_op;
wire tlb_flush;

wire        is_drct_trans;
wire        is_map_trans;
wire        is_tlb_trans;
wire [31:0] drct_map_pa;
wire [31:0] tlb_map_pa;
wire        drct_map_hit;
wire        dmw0_hit;
wire        dmw1_hit;

wire        fs_tlb_refill;
wire        inst_page_fault;
wire        fs_plv_illegal;
wire        load_page_fault;
wire        store_page_fault;
wire        es_tlb_refill;
wire        es_plv_illegal;
wire        store_modify_ex;
wire        es_mmu_ex;
wire        fs_mmu_ex;

always @(posedge clk) begin
    if(reset) begin
        stable_cnt <= 0;
    end
    else begin
        stable_cnt <= stable_cnt + 1;
    end
end

assign cnt_value = {32{inst_cnt_op[1]}} & stable_cnt[31:0] |
                   {32{inst_cnt_op[2]}} & stable_cnt[63:32] ;
assign has_exc = ex_ADEF | ex_ALE | ex_INE | inst_break | inst_syscall | es_mmu_ex | fs_mmu_ex | ex_ADEM;
assign ex_ALE =  (es_ld_op[2] | es_st_op[2]) & (|es_alu_result[1:0]) |
                 (es_ld_op[1] | es_ld_op[4] | es_st_op[1]) & es_alu_result[0];
assign ex_ADEM = &csr_crmd_plv & es_alu_result[31] & es_ld_st_inst;
assign es_mmu_ex = load_page_fault | store_page_fault | es_plv_illegal | es_tlb_refill | store_modify_ex;

assign {fs_mmu_ex,        //235:235
        fs_tlb_refill,    //234:234
        inst_page_fault,  //233:233
        fs_plv_illegal,   //232:232
        tlbop          ,  //231:227
        inv_op      ,  //226:222
        inst_cnt_op    ,  //221:219
        has_int        ,  //218:218
        ex_INE         ,  //217:217
        ex_ADEF        ,  //216:216
        inst_break     ,  //215:215
        inst_ertn      ,  //214:214
        inst_syscall   ,  //213:213
        csr_we         ,  //212:212
        csr_re         ,  //211:211 
        csr_wmask      ,  //210:179
        csr_num        ,  //178:165
        es_st_op       ,  //164:162
        es_ld_op       ,  //161:157
        es_alu_op      ,  //156:138
        es_res_from_mem,  //137:137
        es_src1_is_pc  ,  //136:136
        es_src2_is_imm ,  //135:135
        es_gr_we       ,  //134:134
        es_mem_we      ,  //133:133
        es_dest        ,  //132:128
        es_imm         ,  //127:96
        es_rj_value    ,  //95 :64
        es_rkd_value   ,  //63 :32
        es_pc             //31 :0
       } = ds_to_es_bus_r;

//analysis csr
assign {csr_dmw0_rvalue,
        csr_dmw1_rvalue, 
        csr_crmd_rvalue, 
        csr_asid_rvalue, 
        csr_tlbehi_rvalue} = to_es_csr_bus;
assign csr_crmd_da = csr_crmd_rvalue[`CSR_CRMD_DA];
assign csr_crmd_pg = csr_crmd_rvalue[`CSR_CRMD_PG];
assign csr_crmd_plv = csr_crmd_rvalue[`CSR_CRMD_PLV];

// addr translation
assign drct_map_pa = {32{dmw0_hit}} & {csr_dmw0_rvalue[27:25], es_alu_result[28:0]} |
                     {32{dmw1_hit}} & {csr_dmw1_rvalue[27:25], es_alu_result[28:0]};
assign tlb_map_pa = {32{s1_ps==6'd22}} & {s1_ppn[19:10], es_alu_result[21:0]} |
                    {32{s1_ps==6'd12}} & {s1_ppn[19: 0], es_alu_result[11:0]};
assign is_drct_trans = csr_crmd_da & ~csr_crmd_pg & es_ld_st_inst;
assign is_map_trans  = ~csr_crmd_da & csr_crmd_pg & es_ld_st_inst;
assign is_tlb_trans  = is_map_trans & ~drct_map_hit & es_ld_st_inst;
assign dmw1_hit = (csr_dmw1_rvalue[31:29] == es_alu_result[31:29]) && // vseg_legal
                      ((&csr_crmd_plv  && csr_dmw1_rvalue[3])||
                      (~|csr_crmd_plv && csr_dmw1_rvalue[0])) && es_ld_st_inst;
assign dmw0_hit = (csr_dmw0_rvalue[31:29] == es_alu_result[31:29]) && // vseg_legal
                      ((&csr_crmd_plv  && csr_dmw0_rvalue[3])||
                      (~|csr_crmd_plv && csr_dmw0_rvalue[0])) && es_ld_st_inst;
assign drct_map_hit = dmw0_hit | dmw1_hit;


// tlb exception
assign es_tlb_refill = ~s1_found & is_tlb_trans;
assign load_page_fault = s1_found & ~s1_v & es_res_from_mem & is_tlb_trans;
assign store_page_fault = s1_found & ~s1_v & es_mem_we & is_tlb_trans;
assign es_plv_illegal = s1_found & s1_v & (csr_crmd_plv > s1_plv) & is_tlb_trans;
assign store_modify_ex  = es_mem_we & s1_found & s1_v & (csr_crmd_plv <= s1_plv) & ~s1_d & is_tlb_trans;

//tlbop = {inst_tlbsrch, inst_tlbrd, inst_tlbwr, inst_tlbfill,inst_invtlb};
assign s1_asid = {10{ tlbop[0]}} & es_rj_value[9:0]|
                 {10{~tlbop[0]}} & csr_asid_rvalue[9:0];
assign s1_vppn = {19{tlbop[0]}} & es_rkd_value[31:13]|
                 {19{tlbop[4]}} & csr_tlbehi_rvalue[31:13]|
                 {19{es_ld_st_inst}} & es_alu_result[31:13];
assign s1_va_bit12 = es_ld_st_inst & es_alu_result[12];

assign invtlb_op = inv_op;
assign invtlb_valid = es_valid & tlbop[0] & !es_ms_ws_err;
assign s1_bus = {s1_found,s1_index};

assign tlb_flush = (|tlbop[3:0]) || (csr_we && 
                   (csr_num == `CSR_ASID || csr_num == `CSR_CRMD || csr_num == `CSR_DMW0 ||
                    csr_num == `CSR_DMW1));

assign es_dest_valid = es_valid & es_gr_we;

assign es_to_ds_bus  = es_alu_result;
assign csr_wvalue = es_rkd_value;
assign es_res_from_mul = es_alu_op[12] | es_alu_op[13] |es_alu_op[14];
assign es_to_ms_bus = {ex_ADEM        , //254:254
                       es_tlb_refill  , //253:253
                       load_page_fault, //252:252
                       store_page_fault,//251:251
                       es_plv_illegal,  //250:250
                       store_modify_ex, //249:249
                       fs_tlb_refill,  //248:248
                       inst_page_fault,//247:247
                       fs_plv_illegal, //246:246
                       tlb_flush      ,//245:245
                       tlbop          ,//244:240
                       s1_bus         ,//239:235 {s1_found,s1_index}
                       es_ld_st_inst  ,//234:234
                       inst_cnt_op    ,//233:231
                       cnt_value      ,//230:199
                       has_exc        ,//198:198
                       has_int        ,//197:197
                       ex_INE         ,//196:196
                       ex_ALE         ,//195:195
                       ex_ADEF        ,//194:194
                       inst_break     ,//193:193
                       inst_syscall   ,//192:192
                       inst_ertn      ,//191:191
                       csr_wvalue     ,//190:159
                       csr_we         ,//158:158
                       csr_re         ,//157:157 
                       csr_wmask      ,//156:125
                       csr_num        ,//124:111
                       ld_offset      ,//110:109
                       es_ld_op       ,//108:104
                       es_mul_result  ,//103:72
                       es_res_from_mul,  //71:71
                       es_res_from_mem,  //70:70
                       es_gr_we       ,  //69:69
                       es_dest        ,  //68:64
                       es_alu_result  ,  //63:32
                       es_pc             //31:0
                      };


assign es_dest_bus = {es_res_from_mem,
                      es_res_from_mul|es_res_from_mem|csr_re,
                      es_dest_valid,
                      es_dest
                     };
assign es_ld_st_inst  = es_res_from_mem | es_mem_we;
assign es_div_inst    = |es_alu_op[18:15];
assign es_ready_go    = (~es_ld_st_inst & ~tlbop[4]/*srch*/) & (~es_div_inst | es_div_complete) |
                        (tlbop[4] & ~mem_csr_tlb_w & ~wb_csr_tlb_w) |
                        es_ld_st_inst & (data_sram_addr_ok & data_sram_req | es_ms_ws_err) ;
                         // |es_ms_ws_err;
assign es_allowin     = !es_valid || es_ready_go && ms_allowin;
assign es_to_ms_valid =  es_valid && es_ready_go;// && !ws_flush_es_bus;
always @(posedge clk) begin
    if (reset) begin     
        es_valid <= 1'b0;
    end
    else if(ws_flush_es_bus)begin
        es_valid <= 1'b0;
    end
    else if (es_allowin) begin 
        es_valid <= ds_to_es_valid;
    end
    if (reset)begin
        ds_to_es_bus_r <= 0;
    end
    else if (ds_to_es_valid && es_allowin) begin
        ds_to_es_bus_r <= ds_to_es_bus;
    end
end


assign es_alu_src1 = es_src1_is_pc  ? es_pc[31:0] : 
                                      es_rj_value;
                                      
assign es_alu_src2 = es_src2_is_imm ? es_imm : 
                                      es_rkd_value;

alu u_alu(
    .clk        (clk),
    .reset      (reset),
    .alu_op     (es_alu_op    ),
    .alu_src1   (es_alu_src1  ),
    .alu_src2   (es_alu_src2  ),
    .alu_result (es_alu_result),
    .mul_result (es_mul_result),
    .complete   (es_div_complete)
    );
assign ld_offset = es_alu_result[1:0];
    
assign sb_wen = es_alu_result[1:0] == 2'b00 ? 4'b0001:
                es_alu_result[1:0] == 2'b01 ? 4'b0010:
                es_alu_result[1:0] == 2'b10 ? 4'b0100:
                                              4'b1000;
assign sh_wen = es_alu_result[1:0] == 2'b00 ? 4'b0011:
                                              4'b1100;
assign sw_wen = 4'b1111;       

assign es_ms_ws_err = ms_flush_es_bus | ws_flush_es_bus |has_exc | has_int | inst_ertn;
assign data_sram_req    = (es_res_from_mem | es_mem_we) & ms_allowin & ~reset & !es_ms_ws_err & es_valid & ~fs_mmu_ex & ~es_mmu_ex; 
assign data_sram_wstrb  = ({4{es_st_op[0]}} & sb_wen
                        | {4{es_st_op[1]}} & sh_wen
                        | {4{es_st_op[2]}} & sw_wen);
assign data_sram_wr    = (es_mem_we);
assign data_sram_size  = {2{(es_st_op[0] | es_ld_op[0] | es_ld_op[3])}} & 2'b00 |
                         {2{(es_st_op[1] | es_ld_op[1] | es_ld_op[4])}} & 2'b01 |
                         {2{(es_st_op[2] | es_ld_op[2])}} & 2'b10;
 
assign data_sram_addr = {32{is_drct_trans}}  & es_alu_result[31:0] |
                        {32{is_map_trans &  drct_map_hit}} & drct_map_pa |
                        {32{is_tlb_trans}} & tlb_map_pa;
assign data_sram_wdata = es_st_op[0] ? {4{es_rkd_value[ 7:0]}}:
                         es_st_op[1] ? {2{es_rkd_value[15:0]}}:
                                        es_rkd_value;

endmodule