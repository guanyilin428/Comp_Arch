`include "mycpu.h"

module wb_stage(
    input                           clk           ,
    input                           reset         ,
    //allowin
    output                          ws_allowin    ,
    //from ms
    input                           ms_to_ws_valid,
    input  [`MS_TO_WS_BUS_WD -1:0]  ms_to_ws_bus  ,
    //to rf: for write back
    output [`WS_TO_RF_BUS_WD -1:0]  ws_to_rf_bus  ,
    //trace debug interface
    output [31:0] debug_wb_pc     ,
    output [ 3:0] debug_wb_rf_wen ,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata,
    output [`WS_DEST_BUS     -1:0] ws_dest_bus    ,
    output [`WS_TO_DS_BUS    -1:0] ws_to_ds_bus   ,
    //flush 
    output [`WS_FLUSH_FS_BUS_WD-1:0] ws_flush_fs_bus,
    output                           ws_flush_ds_bus,
    output                           ws_flush_es_bus,
    output                           ws_flush_ms_bus,
    //int
    output                           has_int,
    
    // invtlb opcode
    output [`TO_ES_CSR_BUS_WD-1:0]to_es_csr_bus,
    output                      wb_csr_tlb_w,
    // csr to fs
    output [`TO_FS_CSR_BUS_WD -1:0] to_fs_csr_bus,
    // write port
    output                      we, 
    output [               3:0] w_index,
    output                      w_e,
    output [               5:0] w_ps,
    output [              18:0] w_vppn,
    output [               9:0] w_asid,
    output                      w_g,
    output [              19:0] w_ppn0,
    output [               1:0] w_plv0,
    output [               1:0] w_mat0,
    output                      w_d0,
    output                      w_v0,
    output [              19:0] w_ppn1,
    output [               1:0] w_plv1,
    output [               1:0] w_mat1,
    output                      w_d1,
    output                      w_v1,
    // read port
    output [               3:0] r_index,
    input                       r_e,
    input  [              18:0] r_vppn,
    input  [               5:0] r_ps,
    input  [               9:0] r_asid,
    input                       r_g,
    input  [              19:0] r_ppn0,
    input  [               1:0] r_plv0,
    input  [               1:0] r_mat0,
    input                       r_d0,
    input                       r_v0,
    input  [              19:0] r_ppn1,     
    input  [               1:0] r_plv1,
    input  [               1:0] r_mat1,
    input                       r_d1,
    input                       r_v1
    
);

reg         ws_valid;
wire        ws_ready_go;

reg [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus_r;

wire        ws_dest_valid;
wire        ws_gr_we;
wire [ 4:0] ws_dest;
wire [31:0] ws_alu_mem_result;
wire [31:0] ws_final_result;
wire [31:0] ws_pc;
wire [31:0] mem_vaddr;

wire ex_ADEF;
wire ex_ADEM;
wire ex_ALE;
wire ex_INE;
wire inst_break;
wire inst_ertn;
wire inst_syscall;
wire has_exc;
wire ws_int;
wire csr_we;
wire csr_re;
wire [31:0]csr_wmask;
wire [13:0]csr_num;
wire [31:0]csr_wvalue;

wire [31:0]csr_rvalue;
wire ws_ex;
wire [5:0] ws_ecode;
wire [8:0] ws_esubcode;
wire ws_flush;
wire ertn_flush;
wire [31:0] ex_entry;
wire [31:0] tlbr_entry;
wire [31:0] era_entry;

wire [7:0]   hw_int_in;
wire         ipi_int_in;
wire [31: 0] ws_vaddr;
wire [31: 0] coreid_in;
wire [14:0] prior;


wire  [4 : 0] tlbop; //tlbsrch,tlbrd,tlbwr,tlbfill,invtlb
wire          tlbsrch_hit;

wire  [31: 0] csr_tlbidx_wvalue;
wire  [31: 0] csr_tlbehi_wvalue;
wire  [31: 0] csr_tlbelo0_wvalue;
wire  [31: 0] csr_tlbelo1_wvalue;
wire  [31: 0] csr_asid_wvalue;

wire [31: 0] csr_tlbidx_rvalue;
wire [31: 0] csr_tlbehi_rvalue;
wire [31: 0] csr_tlbelo0_rvalue;
wire [31: 0] csr_tlbelo1_rvalue;

wire [31: 0]csr_asid_rvalue;
wire [31: 0] csr_crmd_rvalue;
wire [31: 0] csr_dmw0_rvalue;
wire [31: 0] csr_dmw1_rvalue;
wire [31: 0] csr_estat_rvalue;

wire csr_tlbrd_re;
reg [3:0] tlbfill_index;
wire [4:0]s1_bus;
wire s1_found;
wire [3:0]s1_index;

wire tlbr;
wire tlb_flush;

wire    tlb_ex;
wire    fs_tlb_refill;
wire    inst_page_fault;
wire    fs_plv_illegal;
wire    load_page_fault;
wire    store_page_fault;
wire    es_plv_illegal;
wire    es_tlb_refill;
wire    store_modify_ex;
wire    badv_is_pc;

assign tlbr = ws_valid & (fs_tlb_refill | es_tlb_refill);
assign tlb_ex = ws_valid & (fs_tlb_refill | fs_plv_illegal | inst_page_fault |
                load_page_fault | store_page_fault | es_plv_illegal | store_modify_ex | es_tlb_refill);
assign badv_is_pc = fs_tlb_refill | fs_plv_illegal | inst_page_fault | ex_ADEF;
assign {ex_ADEM        , //209:209
        es_tlb_refill  , //208:208
        load_page_fault, //207:207
        store_page_fault,//206:206
        es_plv_illegal,  //205:205
        store_modify_ex, //204:204
        fs_tlb_refill,  //203:203
        inst_page_fault,//202:202
        fs_plv_illegal, //201:201
        tlb_flush      ,//200:200
        tlbop          ,//199:195
        s1_bus         ,//194:190
        has_exc        ,//189:189
        ws_int         ,//188:188
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
        ws_gr_we       ,  //69:69
        ws_dest        ,  //68:64
        ws_alu_mem_result,  //63:32
        ws_pc             //31:0
       } = ms_to_ws_bus_r;
assign ws_final_result = csr_re ? csr_rvalue : ws_alu_mem_result;    
assign ws_dest_valid = ws_valid & ws_gr_we;
assign ws_to_ds_bus  = ws_final_result;
wire        rf_we;
wire [4 :0] rf_waddr;
wire [31:0] rf_wdata;
assign ws_to_rf_bus = {rf_we   ,  //37:37
                       rf_waddr,  //36:32
                       rf_wdata   //31:0
                      };

assign ws_dest_bus = {ws_dest_valid,
                      ws_dest
                     };

assign ws_ready_go = 1'b1;
assign ws_allowin  = !ws_valid || ws_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ws_valid <= 1'b0;
    end
    else if (ws_flush) begin
        ws_valid <= 1'b0; 
    end 
    else if (ws_allowin) begin
        ws_valid <= ms_to_ws_valid;
    end

    if (ms_to_ws_valid && ws_allowin) begin
        ms_to_ws_bus_r <= ms_to_ws_bus;
    end
end

assign rf_we    = ws_gr_we & ws_valid & (~ws_flush | tlb_flush);
assign rf_waddr = ws_dest;
assign rf_wdata = ws_final_result;

// debug info generate
assign debug_wb_pc       = ws_pc;
assign debug_wb_rf_wen   = {4{rf_we}};
assign debug_wb_rf_wnum  = ws_dest;
assign debug_wb_rf_wdata = ws_final_result;

assign ws_flush = ws_valid & (has_exc | ws_int | inst_ertn | tlb_flush);
assign ws_flush_fs_bus={ws_flush,
                       (inst_ertn?era_entry:
                       (ws_ex & ~tlbr)? ex_entry :
                        tlbr? tlbr_entry : ws_pc+4)//era or exception_entry
                        };
assign ws_flush_ds_bus = ws_flush;
assign ws_flush_es_bus = ws_flush;
assign ws_flush_ms_bus = ws_flush;

//int
assign prior[0] = ws_int;
//fs
assign prior[1] = ~ws_int & ex_ADEF;
assign prior[2] = ~|prior[1:0] & inst_page_fault;
assign prior[3] = ~|prior[1:0] & fs_plv_illegal;
assign prior[4] = ~|prior[1:0] & fs_tlb_refill;
//ds
assign prior[5] = ~|prior[4:0] & ex_INE;
assign prior[6] = ~|prior[4:0] & inst_syscall;
assign prior[7] = ~|prior[4:0] & inst_break;
//es
assign prior[8] = ~|prior[7:0] & ex_ALE;
assign prior[9] = ~|prior[8:0] & ex_ADEM;
assign prior[10] = ~|prior[8:0] & es_tlb_refill;
assign prior[11] = ~|prior[8:0] & es_plv_illegal;
assign prior[12] = ~|prior[8:0] & load_page_fault;
assign prior[13] = ~|prior[8:0] & store_page_fault;
assign prior[14] = ~|prior[8:0] & store_modify_ex;

assign ertn_flush = inst_ertn;
assign ws_ex = (has_exc | ws_int) & ws_valid;
assign ws_ecode = {6{prior[0]}} & `ECODE_INT |
                  {6{prior[1]}} & `ECODE_ADE |
                  {6{prior[2]}} & `ECODE_PIF |
                  {6{prior[3]}} & `ECODE_PPI |
                  {6{prior[4]}} & `ECODE_TLBR|
                  {6{prior[5]}} & `ECODE_INE |
                  {6{prior[6]}} & `ECODE_SYS |
                  {6{prior[7]}} & `ECODE_BRK |
                  {6{prior[8]}} & `ECODE_ALE |
                  {6{prior[9]}} & `ECODE_ADE |
                  {6{prior[10]}} & `ECODE_TLBR|
                  {6{prior[11]}} & `ECODE_PPI|
                  {6{prior[12]}} & `ECODE_PIL|
                  {6{prior[13]}} & `ECODE_PIS|
                  {6{prior[14]}} & `ECODE_PME;
assign ws_esubcode = {9{ex_ADEF}} & `ESUBCODE_ADEF | {9{ex_ADEM}} & `ESUBCODE_ADEM;
assign hw_int_in = 8'b0;
assign ipi_int_in = 1'b0;
assign ws_vaddr = mem_vaddr;//mem address
assign coreid_in = 32'b0;

assign s1_found = s1_bus[4];
assign s1_index = s1_bus[3:0];

//assign tlb_reflush   = ws_valid & (tlbop[0] | tlbop[1] | tlbop[2] | tlbop[4]);//except tlbsrch

assign tlbsrch_hit = tlbop[4] & s1_found;//tlbsrch
assign csr_tlbrd_re = r_e & ws_valid;

assign csr_tlbidx_wvalue = {~r_e,1'b0,r_ps,20'b0,s1_index};
assign csr_tlbehi_wvalue = {r_vppn,13'b0};
assign csr_tlbelo0_wvalue = {r_ppn0,1'b0,r_g,r_mat0,r_plv0,r_d0,r_v0};
assign csr_tlbelo1_wvalue = {r_ppn1,1'b0,r_g,r_mat1,r_plv1,r_d1,r_v1};
assign csr_asid_wvalue[9:0] = r_asid;

assign r_index = csr_tlbidx_rvalue[3:0];

//op:tlbsrch,tlbrd,tlbwr,tlbfill,invtlb
assign we = (tlbop[1] | tlbop[2]) & ws_valid; //fill | wr
assign w_index = tlbop[2] ? csr_tlbidx_rvalue[3:0] : tlbop[1] ? tlbfill_index : 4'b0;//wr or fill
assign w_ps = csr_tlbidx_rvalue[29:24];
assign w_e  = (csr_estat_rvalue[21:16]==6'h3f) || ~csr_tlbidx_rvalue[31];
assign w_vppn = csr_tlbehi_rvalue[31:13];
assign w_asid = csr_asid_rvalue[9:0];

assign w_v0 = csr_tlbelo0_rvalue [0];
assign w_d0 = csr_tlbelo0_rvalue [1];
assign w_plv0 = csr_tlbelo0_rvalue [3:2];
assign w_mat0 = csr_tlbelo0_rvalue [5:4];
assign w_ppn0 = csr_tlbelo0_rvalue [31:8];
assign w_v1 = csr_tlbelo1_rvalue [0];
assign w_d1 = csr_tlbelo1_rvalue [1];
assign w_plv1 = csr_tlbelo1_rvalue [3:2];
assign w_mat1 = csr_tlbelo1_rvalue [5:4];
assign w_ppn1 = csr_tlbelo1_rvalue [31:8];
assign w_g = csr_tlbelo1_rvalue[6] & csr_tlbelo0_rvalue[6]; 

assign to_es_csr_bus = {csr_dmw0_rvalue, csr_dmw1_rvalue, csr_crmd_rvalue, csr_asid_rvalue, csr_tlbehi_rvalue};
assign to_fs_csr_bus = {csr_dmw0_rvalue, csr_dmw1_rvalue, csr_crmd_rvalue, csr_asid_rvalue};
assign wb_csr_tlb_w = ws_valid && (tlbop[3] | (csr_we & ~ws_flush) && (csr_num == `CSR_ASID || csr_num == `CSR_TLBEHI));
always @(posedge clk)begin
    if(reset)begin
        tlbfill_index <= 4'b0;
    end
    else if(tlbop[1] & ws_valid) begin
        if(tlbfill_index == 4'd15) begin
            tlbfill_index <= 4'b0;
        end
        else begin
            tlbfill_index <= tlbfill_index + 4'b1;
        end
    end
end

csr csr(
    .clk(clk),
    .reset(reset),
    
    .csr_re(csr_re),
    .csr_num(csr_num),
    .csr_rvalue(csr_rvalue),
    
    .csr_we(csr_we & ws_valid & (~ws_flush | tlb_flush)),
    .csr_wmask(csr_wmask),
    .csr_wvalue(csr_wvalue),
    
    .wb_ex(ws_ex),
    .wb_ecode(ws_ecode),
    .wb_esubcode(ws_esubcode),
    
    .ertn_flush(ertn_flush),
    .ex_entry(ex_entry),//exception_entry
    .era_entry(era_entry),
    .tlbr_entry(tlbr_entry),
    .has_int(has_int),
    
    .tlb_ex (tlb_ex),
    .hw_int_in(hw_int_in),
    .ipi_int_in(ipi_int_in),
    .wb_vaddr(ws_vaddr),
    .wb_pc(ws_pc),
    .badv_is_pc(badv_is_pc),
    .coreid_in(coreid_in),
    
    .tlbop_bus(tlbop), //tlbsrch,tlbrd,tlbwr,tlbfill,invtlb
    .tlbsrch_hit(tlbsrch_hit),
    .csr_tlbrd_re(csr_tlbrd_re),
    
    .csr_tlbidx_wvalue(csr_tlbidx_wvalue),
    .csr_tlbehi_wvalue(csr_tlbehi_wvalue),
    .csr_tlbelo0_wvalue(csr_tlbelo0_wvalue),
    .csr_tlbelo1_wvalue(csr_tlbelo1_wvalue),
    .csr_asid_wvalue(csr_asid_wvalue),
    
    .csr_tlbidx_rvalue(csr_tlbidx_rvalue),
    .csr_tlbehi_rvalue(csr_tlbehi_rvalue),
    .csr_tlbelo0_rvalue(csr_tlbelo0_rvalue),
    .csr_tlbelo1_rvalue(csr_tlbelo1_rvalue),
    
    .csr_asid_rvalue(csr_asid_rvalue),
    .csr_crmd_rvalue(csr_crmd_rvalue),
    .csr_dmw0_rvalue(csr_dmw0_rvalue),
    .csr_dmw1_rvalue(csr_dmw1_rvalue),
    .csr_estat_rvalue(csr_estat_rvalue)
);

endmodule
