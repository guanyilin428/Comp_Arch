`include "mycpu.h"

module mem_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          ws_allowin    ,
    output                         ms_allowin    ,
    //from es
    input                          es_to_ms_valid,
    input  [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    //to ws
    output                         ms_to_ws_valid,
    output [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus  ,
    //from data-sram
    input  [31                 :0] data_sram_rdata,
    input                          data_sram_data_ok,
    output [`MS_DEST_BUS     -1:0] ms_dest_bus    ,
    output [`MS_TO_DS_BUS    -1:0] ms_to_ds_bus   ,
    //flush
   // output                         ms_to_es_valid ,
    output                         ms_flush_es_bus,
    input                          ws_flush_ms_bus,

    output                         mem_csr_tlb_w     
);

reg         ms_valid;
wire        ms_ready_go;
reg  [31:0] ms_buff_data;
reg         ms_buff_valid;

reg [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus_r;
wire [ 4:0] ms_ld_op;
wire [ 1:0] ms_ld_offset;
wire        ms_dest_valid;
wire [31:0] ms_mul_result;
wire        ms_res_from_mem;
wire        ms_res_from_mul;
wire        ms_gr_we;
wire [ 4:0] ms_dest;
wire [31:0] ms_alu_result;
wire [31:0] ms_pc;
wire        ms_ld_st_op;

wire [31:0] cnt_value;
wire [2:0] inst_cnt_op;
wire has_exc;
wire has_int;
wire ex_ADEF;
wire ex_ADEM;
wire ex_ALE;
wire ex_INE;
wire inst_break;
wire inst_ertn;
wire inst_syscall;
wire csr_we;
wire csr_re;
wire [31:0]csr_wmask;
wire [13:0]csr_num;
wire [31:0]csr_wvalue;

wire [31:0] mul_result;
wire [31:0] mem_result;
wire [31:0] ms_final_result;
wire [31:0] mem_vaddr;
wire [ 4:0] s1_bus;
wire [ 4:0] tlbop;
wire tlb_flush;

wire    fs_tlb_refill;
wire    inst_page_fault;
wire    fs_plv_illegal;
wire    load_page_fault;
wire    store_page_fault;
wire    es_plv_illegal;
wire    store_modify_ex;
wire    es_tlb_refill;
wire    ms_ld_st_inst;



assign {ex_ADEM        , //254:254
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
        s1_bus         ,//239:235
        ms_ld_st_inst  ,//234:234
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
        ms_ld_offset   ,  //110:109
        ms_ld_op       ,  //108:104
        ms_mul_result  ,  //103:72
        ms_res_from_mul,  //71:71
        ms_res_from_mem,  //70:70
        ms_gr_we       ,  //69:69
        ms_dest        ,  //68:64
        ms_alu_result  ,  //63:32
        ms_pc             //31:0
       } = es_to_ms_bus_r;
assign  ms_flush_es_bus = ms_valid & (inst_ertn | has_int | has_exc | tlb_flush);
assign ms_dest_valid = ms_valid & ms_gr_we;
assign ms_to_ds_bus  = ms_final_result;
//tlbop = {inst_tlbsrch, inst_tlbrd, inst_tlbwr, inst_tlbfill,inst_invtlb};
assign mem_csr_tlb_w = ms_valid && (tlbop[3] | (csr_we && (csr_num == `CSR_ASID || csr_num == `CSR_TLBEHI)));
assign mem_vaddr = ms_alu_result;
assign ms_to_ws_bus = {ex_ADEM        , //209:209
                       es_tlb_refill  , //208:208
                       load_page_fault, //207:207
                       store_page_fault,//206:206
                       es_plv_illegal,  //205:205
                       store_modify_ex, //204:204
                       fs_tlb_refill,  //203:203
                       inst_page_fault,//202:202
                       fs_plv_illegal, //201:201
                       tlb_flush      , //200:200
                       tlbop          , //199:195
                       s1_bus         , //194:190
                       has_exc        ,//189:189
                       has_int        ,//188:188
                       ex_INE         ,//187:187
                       ex_ALE         ,//186:186
                       ex_ADEF        ,//185:185
                       inst_break     ,//184:184
                       inst_syscall   ,//183:183
                       inst_ertn      ,//182:182
                       csr_wvalue     ,//181:150
                       mem_vaddr      ,//149:118
                       csr_we         ,//117:117
                       csr_re         ,//116:116 
                       csr_wmask      ,//115:84
                       csr_num        ,//83:70
                       ms_gr_we       ,  //69:69
                       ms_dest        ,  //68:64
                       ms_final_result,  //63:32
                       ms_pc             //31:0
                      };

assign ms_dest_bus = {csr_re|(!data_sram_data_ok & ms_res_from_mem),
                      ms_dest_valid,
                      ms_dest
                    };
                    
assign ms_ready_go    =  ms_ld_st_inst & (data_sram_data_ok | has_exc) | ~ms_ld_st_inst; //(ms_flush_es_bus | ws_flush_ms_bus)|
assign ms_allowin     = !ms_valid || ms_ready_go && ws_allowin ;
assign ms_to_ws_valid = ms_valid & ms_ready_go;// && !ws_flush_ms_bus;
always @(posedge clk) begin
    if (reset) begin
        ms_valid <= 1'b0;
    end
    else if (ws_flush_ms_bus) begin
        ms_valid <= 1'b0;
    end
    else if (ms_allowin) begin
        ms_valid <= es_to_ms_valid;
    end
    if (reset)begin
        es_to_ms_bus_r <= 0;
    end
    else if (es_to_ms_valid && ms_allowin) begin
        es_to_ms_bus_r  <= es_to_ms_bus;
    end
end
//0:b;
//1:h
//2:w
//3:bu
//4:hu
wire [7:0]mem_byte_0;
wire [7:0]mem_byte_1;
wire [7:0]mem_byte_2;
wire [7:0]mem_byte_3;
wire [3:0]ld_offset_d;
wire [ 7:0]mem_result_byte;
wire [15:0]mem_result_half;

assign mem_byte_0 = data_sram_rdata[ 7: 0];
assign mem_byte_1 = data_sram_rdata[15: 8];
assign mem_byte_2 = data_sram_rdata[23:16];
assign mem_byte_3 = data_sram_rdata[31:24];
decoder_2_4  dec2(.in(ms_ld_offset), .out(ld_offset_d));

assign mem_result_byte = {8{ld_offset_d[2'h0]}} & mem_byte_0
                       | {8{ld_offset_d[2'h1]}} & mem_byte_1
                       | {8{ld_offset_d[2'h2]}} & mem_byte_2
                       | {8{ld_offset_d[2'h3]}} & mem_byte_3;
                         
assign mem_result_half = {16{ld_offset_d[2'h0]}}& {mem_byte_1,mem_byte_0}
                       | {16{ld_offset_d[2'h2]}}& {mem_byte_3,mem_byte_2};
                       
assign mem_result = {32{ms_ld_op[0]}} & {{24{mem_result_byte[7]}},mem_result_byte[7:0]}
                  | {32{ms_ld_op[1]}} & {{16{mem_result_half[15]}},mem_result_half[15:0]}
                  | {32{ms_ld_op[2]}} & {data_sram_rdata[31:0]}
                  | {32{ms_ld_op[3]}} & {24'b0,mem_result_byte[7:0]}
                  | {32{ms_ld_op[4]}} & {16'b0,mem_result_half[15:0]};      

assign mul_result = es_to_ms_bus[103:72];
assign ms_final_result = ms_res_from_mem & ~ms_buff_valid ? mem_result:
                         ms_res_from_mem & ms_buff_valid ? ms_buff_data:
                         ms_res_from_mul ? mul_result:
                        |inst_cnt_op[2:1] ? cnt_value:
                                           ms_alu_result;
/*
always @(posedge clk) begin
    if(reset) begin
        ms_cancel_reg <= 0;
    end
    else if((es_to_ms_valid | ~ms_allowin & ~ms_ready_go) & ws_flush_ms_bus) begin
        ms_cancel_reg <= 1;
    end
    else if(data_sram_data_ok) begin
        ms_cancel_reg <= 0;
    end
end
*/


always @(posedge clk) begin
    if(reset | ws_flush_ms_bus) begin
        ms_buff_valid <= 0;
        ms_buff_data <= 0;
    end
    else if(data_sram_data_ok & ~ws_allowin)begin
        ms_buff_valid <= 1;
        ms_buff_data <= mem_result;
    end
    else if(ws_allowin) begin
        ms_buff_valid <= 0;
        ms_buff_data <= 0;
    end
end


endmodule