`include "mycpu.h"
module mycpu_top(
    input   [ 5:0]      int,
    input               aclk,
    input               aresetn,
    //read request
    output  [ 3:0]      arid,
    output  [31:0]      araddr,
    output  [ 7:0]      arlen,
    output  [ 2:0]      arsize,
    output  [ 1:0]      arburst,
    output  [ 1:0]      arlock,
    output  [ 3:0]      arcache,
    output  [ 2:0]      arprot,
    output              arvalid,
    input               arready,
    //read response
    input   [ 3:0]      rid,
    input   [31:0]      rdata,
    input   [ 1:0]      rresp,
    input               rlast,
    input               rvalid,
    output              rready,
    //write request
    output  [ 3:0]      awid,
    output  [31:0]      awaddr,
    output  [ 7:0]      awlen,
    output  [ 2:0]      awsize,
    output  [ 1:0]      awburst,
    output  [ 1:0]      awlock,
    output  [ 3:0]      awcache,
    output  [ 2:0]      awprot,
    output              awvalid,
    input               awready,
    //write data
    output  [ 3:0]      wid,
    output  [31:0]      wdata,
    output  [ 3:0]      wstrb,
    output              wlast,
    output              wvalid,
    input               wready,
    //write response
    input   [ 3:0]      bid,
    input   [ 1:0]      bresp,
    input               bvalid,
    output              bready,
    // trace debug interface
    output [31:0] debug_wb_pc,
    output [ 3:0] debug_wb_rf_wen,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
);

// inst sram interface
wire         inst_sram_req;
wire         inst_sram_wr;
wire [ 3:0] inst_sram_wstrb;
wire [31:0] inst_sram_addr;
wire [31:0] inst_sram_wdata;
wire [31:0] inst_sram_rdata;
wire [ 1:0] inst_sram_size;
wire        inst_sram_addr_ok; 
wire        inst_sram_data_ok; 
// data sram interface
wire        data_sram_req;
wire        data_sram_wr;
wire [ 3:0] data_sram_wstrb;
wire [31:0] data_sram_addr;
wire [31:0] data_sram_wdata;
wire [31:0] data_sram_rdata;
wire [ 1:0] data_sram_size;
wire        data_sram_addr_ok;
wire        data_sram_data_ok;

wire    reset;
assign  reset = ~aresetn;

axi_bridge my_transfer_bridge(
    .clk               (aclk               ),
    .reset             (reset             ),

    .arid               (arid               ),
    .araddr             (araddr             ),
    .arlen              (arlen              ),
    .arsize             (arsize             ),
    .arburst            (arburst            ),
    .arlock             (arlock             ),
    .arcache            (arcache            ),
    .arprot             (arprot             ),
    .arvalid            (arvalid            ),
    .arready            (arready            ),

    .rid                (rid                ),
    .rdata              (rdata              ),
    .rresp              (rresp              ),
    .rlast              (rlast              ),
    .rvalid             (rvalid             ),
    .rready             (rready             ),

    .awid               (awid               ),
    .awaddr             (awaddr             ),
    .awlen              (awlen              ),
    .awsize             (awsize             ),
    .awburst            (awburst            ),
    .awlock             (awlock             ),
    .awcache            (awcache            ),
    .awprot             (awprot             ),
    .awvalid            (awvalid            ),
    .awready            (awready            ),

    .wid                (wid                ),
    .wdata              (wdata              ),
    .wstrb              (wstrb              ),
    .wlast              (wlast              ),
    .wvalid             (wvalid             ),
    .wready             (wready             ),

    .bid                (bid                ),
    .bresp              (bresp              ),
    .bvalid             (bvalid             ),
    .bready             (bready             ),

    .inst_sram_req      (inst_sram_req      ),
    .inst_sram_wr       (inst_sram_wr       ),
    .inst_sram_wstrb    (inst_sram_wstrb    ),
    .inst_sram_addr     (inst_sram_addr     ),
    .inst_sram_wdata    (inst_sram_wdata    ),
    .inst_sram_rdata    (inst_sram_rdata    ),
    .inst_sram_size     (inst_sram_size     ),
    .inst_sram_addr_ok  (inst_sram_addr_ok  ),
    .inst_sram_data_ok  (inst_sram_data_ok  ),

    .data_sram_req      (data_sram_req      ),
    .data_sram_wr       (data_sram_wr       ),
    .data_sram_wstrb    (data_sram_wstrb    ),
    .data_sram_addr     (data_sram_addr     ),
    .data_sram_wdata    (data_sram_wdata    ),
    .data_sram_rdata    (data_sram_rdata    ),
    .data_sram_size     (data_sram_size     ),
    .data_sram_addr_ok  (data_sram_addr_ok  ),
    .data_sram_data_ok  (data_sram_data_ok  )
);
 

wire         has_int;
wire         ds_allowin;
wire         es_allowin;
wire         ms_allowin;
wire         ws_allowin;
wire         fs_to_ds_valid;
wire         ds_to_es_valid;
wire         es_to_ms_valid;
wire         ms_to_ws_valid;
wire [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus;
wire [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus;
wire [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus;
wire [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus;
wire [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus;
wire [`BR_BUS_WD       -1:0] br_bus;
wire [`ES_DEST_BUS     -1:0] es_dest_bus;
wire [`MS_DEST_BUS     -1:0] ms_dest_bus;
wire [`WS_DEST_BUS     -1:0] ws_dest_bus;
wire [`ES_TO_DS_BUS    -1:0] es_to_ds_bus;
wire [`MS_TO_DS_BUS    -1:0] ms_to_ds_bus;
wire [`WS_TO_DS_BUS    -1:0] ws_to_ds_bus;

/*wire  [`ES_FLUSH_FS_BUS_WD -1:0] es_flush_fs_bus;
wire                        es_flush_ds_bus;
wire                        ms_to_es_valid;
wire                        ws_to_es_valid;*/
wire [`WS_FLUSH_FS_BUS_WD-1:0] ws_flush_fs_bus;
wire                           ws_flush_ds_bus;
wire                           ws_flush_es_bus;
wire                           ws_flush_ms_bus; 
wire                           ms_flush_es_bus; 

//tlb
wire [              18:0]    s0_vppn;
wire                         s0_va_bit12;
wire [               9:0]    s0_asid;
wire                         s0_found;
wire [               3:0]    s0_index;
wire [              19:0]    s0_ppn;
wire [               5:0]    s0_ps;
wire [               1:0]    s0_plv;
wire [               1:0]    s0_mat;
wire                         s0_d;
wire                         s0_v;
    // search port 1 (for load/store)
wire  [              18:0]   s1_vppn;
wire                         s1_va_bit12;
wire  [               9:0]   s1_asid;
wire                         s1_found;
wire [               3:0]    s1_index;
wire [              19:0]    s1_ppn;
wire [               5:0]    s1_ps;
wire [               1:0]    s1_plv;
wire [               1:0]    s1_mat;
wire                         s1_d;
wire                         s1_v;
    // invtlb opcode
wire                         invtlb_valid;
wire  [               4:0]   invtlb_op;
    // write port
wire                         we; 
wire  [               3:0]   w_index;
wire                         w_e;
wire  [               5:0]   w_ps;
wire  [              18:0]   w_vppn;
wire  [               9:0]   w_asid;
wire                         w_g;
wire  [              19:0]   w_ppn0;
wire  [               1:0]   w_plv0;
wire  [               1:0]   w_mat0;
wire                         w_d0;
wire                         w_v0;
wire  [              19:0]   w_ppn1;
wire  [               1:0]   w_plv1;
wire  [               1:0]   w_mat1;
wire                         w_d1;
wire                         w_v1;
    // read port
wire  [              3:0]   r_index;
wire                         r_e;
wire [              18:0]    r_vppn;
wire [               5:0]    r_ps;
wire [               9:0]    r_asid;
wire                         r_g;
wire [              19:0]    r_ppn0;
wire [               1:0]    r_plv0;
wire [               1:0]    r_mat0;
wire                         r_d0;
wire                         r_v0;
wire [              19:0]    r_ppn1;     
wire [               1:0]    r_plv1;
wire [               1:0]    r_mat1;
wire                         r_d1;
wire                         r_v1;

wire mem_csr_tlb_w;
wire wb_csr_tlb_w;
wire [`TO_FS_CSR_BUS_WD-1: 0]to_fs_csr_bus;
wire [`TO_ES_CSR_BUS_WD-1: 0]to_es_csr_bus;

// IF stage
if_stage if_stage(
    .clk            (aclk           ),
    .reset          (reset          ),
    //allowin
    .ds_allowin     (ds_allowin     ),
    //brbus
    .br_bus         (br_bus         ),
    //outputs
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    // inst sram interface
    .inst_sram_req     (inst_sram_req    ),
    .inst_sram_wr      (inst_sram_wr     ),
    .inst_sram_wstrb   (inst_sram_wstrb  ),
    .inst_sram_addr    (inst_sram_addr   ),
    .inst_sram_wdata   (inst_sram_wdata  ),
    .inst_sram_rdata   (inst_sram_rdata  ),
    .inst_sram_size    (inst_sram_size   ),
    .inst_sram_data_ok (inst_sram_data_ok),
    .inst_sram_addr_ok (inst_sram_addr_ok),
    .ws_flush_fs_bus   (ws_flush_fs_bus),
    .to_fs_csr_bus     (to_fs_csr_bus),
    // search port 0 (for fetch)
    .s0_vppn       (s0_vppn        ),
    .s0_va_bit12   (s0_va_bit12    ),
    .s0_asid       (s0_asid        ),
    .s0_found      (s0_found       ),
    .s0_index      (s0_index       ),
    .s0_ppn        (s0_ppn         ),  
    .s0_ps         (s0_ps          ),
    .s0_plv        (s0_plv         ),
    .s0_mat        (s0_mat         ),
    .s0_d          (s0_d           ),
    .s0_v          (s0_v           )
);
// ID stage
id_stage id_stage(
    .clk            (aclk           ),
    .reset          (reset          ),
    //allowin
    .es_allowin     (es_allowin     ),
    .ds_allowin     (ds_allowin     ),
    //from fs
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    //to es
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),
    //to fs
    .br_bus         (br_bus         ),
    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   ),
    .es_dest_bus    (es_dest_bus    ),
    .ms_dest_bus    (ms_dest_bus    ),
    .ws_dest_bus    (ws_dest_bus    ),
    .es_to_ds_bus   (es_to_ds_bus   ),
    .ms_to_ds_bus   (ms_to_ds_bus   ),
    .ws_to_ds_bus   (ws_to_ds_bus   ),
    .ws_flush_ds_bus(ws_flush_ds_bus),
    .has_int        (has_int)
    
);
// EXE stage
exe_stage exe_stage(
    .clk            (aclk           ),
    .reset          (reset          ),
    //allowin
    .ms_allowin     (ms_allowin     ),
    .es_allowin     (es_allowin     ),
    //from ds
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),
    //to ms
    .es_to_ms_valid (es_to_ms_valid ),
    .es_to_ms_bus   (es_to_ms_bus   ),
    // data sram interface
    .data_sram_req    (data_sram_req   ),
    .data_sram_wr     (data_sram_wr    ),
    .data_sram_wstrb  (data_sram_wstrb ),
    .data_sram_addr   (data_sram_addr ),
    .data_sram_addr_ok(data_sram_addr_ok),
    .data_sram_wdata  (data_sram_wdata),
    .data_sram_size   (data_sram_size),
    .es_dest_bus    (es_dest_bus    ),
    .es_to_ds_bus   (es_to_ds_bus   ),
    .ms_flush_es_bus(ms_flush_es_bus),
    .ws_flush_es_bus(ws_flush_es_bus),
    //invtlb   
    .invtlb_valid  (invtlb_valid   ),
    .invtlb_op     (invtlb_op      ),
    // search port 1 (for load/store)
    .s1_vppn       (s1_vppn        ),
    .s1_va_bit12   (s1_va_bit12    ),
    .s1_asid       (s1_asid        ),
    .s1_found      (s1_found       ),
    .s1_index      (s1_index       ),
    .s1_ppn        (s1_ppn         ),
    .s1_ps         (s1_ps          ),
    .s1_plv        (s1_plv         ),
    .s1_mat        (s1_mat         ),
    .s1_d          (s1_d           ),
    .s1_v          (s1_v           ),
    .to_es_csr_bus   (to_es_csr_bus    ),
    .mem_csr_tlb_w   (mem_csr_tlb_w    ),
    .wb_csr_tlb_w    (wb_csr_tlb_w       )
);
// MEM stage
mem_stage mem_stage(
    .clk            (aclk           ),
    .reset          (reset          ),
    //allowin
    .ws_allowin     (ws_allowin     ),
    .ms_allowin     (ms_allowin     ),
    //from es
    .es_to_ms_valid (es_to_ms_valid ),
    .es_to_ms_bus   (es_to_ms_bus   ),
    //to ws
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    //from data-sram
    .data_sram_rdata  (data_sram_rdata),
    .data_sram_data_ok(data_sram_data_ok),
    .ms_dest_bus    (ms_dest_bus    ),
    .ms_to_ds_bus   (ms_to_ds_bus   ),
    //flush
   // .ms_to_es_valid(ms_to_es_valid  )
    .ms_flush_es_bus(ms_flush_es_bus),
    .ws_flush_ms_bus(ws_flush_ms_bus),

    .mem_csr_tlb_w    (mem_csr_tlb_w)
);
// WB stage
wb_stage wb_stage(
    .clk            (aclk           ),
    .reset          (reset          ),
    //allowin
    .ws_allowin     (ws_allowin     ),
    //from ms
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   ),
    .ws_dest_bus    (ws_dest_bus    ),
    .ws_to_ds_bus   (ws_to_ds_bus   ),
    //trace debug interface
    .debug_wb_pc      (debug_wb_pc      ),
    .debug_wb_rf_wen  (debug_wb_rf_wen  ),
    .debug_wb_rf_wnum (debug_wb_rf_wnum ),
    .debug_wb_rf_wdata(debug_wb_rf_wdata),
    //flush
     //.ws_to_es_valid(ws_to_es_valid  )
     .ws_flush_fs_bus(ws_flush_fs_bus),
     .ws_flush_ds_bus(ws_flush_ds_bus),
     .ws_flush_es_bus(ws_flush_es_bus),
     .ws_flush_ms_bus(ws_flush_ms_bus),
     .has_int        (has_int),
    
    .to_fs_csr_bus   (to_fs_csr_bus    ),
    .to_es_csr_bus   (to_es_csr_bus    ),
    .wb_csr_tlb_w  (wb_csr_tlb_w   ),
    // write port
    .we            (we             ), 
    .w_index       (w_index        ),
    .w_e           (w_e            ),
    .w_ps          (w_ps           ),
    .w_vppn        (w_vppn         ),
    .w_asid        (w_asid         ),
    .w_g           (w_g            ),
    .w_ppn0        (w_ppn0         ),
    .w_plv0        (w_plv0         ),
    .w_mat0        (w_mat0         ),
    .w_d0          (w_d0           ),
    .w_v0          (w_v0           ),
    .w_ppn1        (w_ppn1         ),
    .w_plv1        (w_plv1         ),
    .w_mat1        (w_mat1         ),
    .w_d1          (w_d1           ),
    .w_v1          (w_v1           ),
    // read port
    .r_index       (r_index        ),
    .r_e           (r_e            ),
    .r_vppn        (r_vppn         ),
    .r_ps          (r_ps           ),
    .r_asid        (r_asid         ),
    .r_g           (r_g            ),
    .r_ppn0        (r_ppn0         ),
    .r_plv0        (r_plv0         ),
    .r_mat0        (r_mat0         ),
    .r_d0          (r_d0           ),
    .r_v0          (r_v0           ),
    .r_ppn1        (r_ppn1         ),     
    .r_plv1        (r_plv1         ),
    .r_mat1        (r_mat1         ),
    .r_d1          (r_d1           ),
    .r_v1          (r_v1           )
);
tlb tlb(
    .clk           (aclk           ),
    // search port 0 (for fetch)
    .s0_vppn       (s0_vppn        ),
    .s0_va_bit12   (s0_va_bit12    ),
    .s0_asid       (s0_asid        ),
    .s0_found      (s0_found       ),
    .s0_index      (s0_index       ),
    .s0_ppn        (s0_ppn         ),  
    .s0_ps         (s0_ps          ),
    .s0_plv        (s0_plv         ),
    .s0_mat        (s0_mat         ),
    .s0_d          (s0_d           ),
    .s0_v          (s0_v           ),
    // search port 1 (for load/store)
    .s1_vppn       (s1_vppn        ),
    .s1_va_bit12   (s1_va_bit12    ),
    .s1_asid       (s1_asid        ),
    .s1_found      (s1_found       ),
    .s1_index      (s1_index       ),
    .s1_ppn        (s1_ppn         ),
    .s1_ps         (s1_ps          ),
    .s1_plv        (s1_plv         ),
    .s1_mat        (s1_mat         ),
    .s1_d          (s1_d           ),
    .s1_v          (s1_v           ),
    // invtlb opcode
    .invtlb_valid  (invtlb_valid   ),
    .invtlb_op     (invtlb_op      ),
    // write port
    .we            (we             ), 
    .w_index       (w_index        ),
    .w_e           (w_e            ),
    .w_ps          (w_ps           ),
    .w_vppn        (w_vppn         ),
    .w_asid        (w_asid         ),
    .w_g           (w_g            ),
    .w_ppn0        (w_ppn0         ),
    .w_plv0        (w_plv0         ),
    .w_mat0        (w_mat0         ),
    .w_d0          (w_d0           ),
    .w_v0          (w_v0           ),
    .w_ppn1        (w_ppn1         ),
    .w_plv1        (w_plv1         ),
    .w_mat1        (w_mat1         ),
    .w_d1          (w_d1           ),
    .w_v1          (w_v1           ),
    // read port
    .r_index       (r_index        ),
    .r_e           (r_e            ),
    .r_vppn        (r_vppn         ),
    .r_ps          (r_ps           ),
    .r_asid        (r_asid         ),
    .r_g           (r_g            ),
    .r_ppn0        (r_ppn0         ),
    .r_plv0        (r_plv0         ),
    .r_mat0        (r_mat0         ),
    .r_d0          (r_d0           ),
    .r_v0          (r_v0           ),
    .r_ppn1        (r_ppn1         ),     
    .r_plv1        (r_plv1         ),
    .r_mat1        (r_mat1         ),
    .r_d1          (r_d1           ),
    .r_v1          (r_v1           )
);
endmodule