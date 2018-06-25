module tcpip_tx
  (
   //system
   input wire 	     clk, //125Mhz
   input wire 	     rst_n,

   //config
   input wire [47:0] src_mac_addr,
   input wire [47:0] des_mac_addr,
   input wire [31:0] src_ip_addr,
   input wire [31:0] des_ip_addr,
   input wire [15:0] src_port,
   input wire [15:0] des_port,
   input wire [7:0]  prot_type,
   
   //extern i/f
   input wire 	     tcpip_tx_clk,
   input wire 	     tcpip_tx_en,
   input wire [7:0]  tcpip_tx_dat,

   //mac GMII tx
   output wire 	     tx_en,
   output wire [7:0] txd,
   output wire 	     tx_er,
   
   //status
   output wire 	     tx_busy,
   output wire 	     app_fifo_full
   );
  
  wire [7:0]         app_fifo_dat;
  wire [31:0]        fcs;
  wire [7:0]         mac_rram_dat;
  
  wire           wram_clk_en;
  wire [9:0]         wram_addr;
  wire [7:0]         wram_dat;
  
  /*AUTOWIRE*/
  // Beginning of automatic wires (for undeclared instantiated-module outputs)
  wire          app_fifo_clk_en;    // From u_udp_pack of udp_pack.v
  wire          fcs_get;        // From u_mac_pack of mac_pack.v
  wire          ip_head_end;        // From u_ip_pack of ip_pack.v
  wire [9:0]        ip_wram_addr;       // From u_ip_pack of ip_pack.v
  wire          ip_wram_clk_en;     // From u_ip_pack of ip_pack.v
  wire [7:0]        ip_wram_dat;        // From u_ip_pack of ip_pack.v
  wire          mac_data_end;       // From u_udp_pack of udp_pack.v
  wire          mac_head_end;       // From u_mac_pack of mac_pack.v
  wire [9:0]        mac_rram_addr;      // From u_mac_pack of mac_pack.v
  wire          mac_rram_clk_en;    // From u_mac_pack of mac_pack.v
  wire [9:0]        mac_wram_addr;      // From u_mac_pack of mac_pack.v
  wire          mac_wram_clk_en;    // From u_mac_pack of mac_pack.v
  wire [7:0]        mac_wram_dat;       // From u_mac_pack of mac_pack.v
  wire [9:0]        udp_wram_addr;      // From u_udp_pack of udp_pack.v
  wire          udp_wram_clk_en;    // From u_udp_pack of udp_pack.v
  wire [7:0]        udp_wram_dat;       // From u_udp_pack of udp_pack.v
  // End of automatics
  
  
  app_fifo_8x1024 u_app_fifo_tx
    (
     //.rst     (~rst_n),
     //write
     .wr_rst  (~rst_n),
     .wr_clk  (tcpip_tx_clk), //tcpip_tx_clk
     .wr_en   (tcpip_tx_en),
     .din     (tcpip_tx_dat),
     //read
     .rd_rst  (~rst_n),
     .rd_clk  (clk),
     .rd_en   (app_fifo_clk_en),
     .dout    (app_fifo_dat[7:0]),
     //status
     .full    (app_fifo_full),
     .empty   (app_fifo_empty) 
     );

  ram_8x1024 u_ram_8x1024
    (
     //write (A port)
     .clka    (clk),
     .ena     (wram_clk_en),
     .wea     (1'b1),
     .addra   (wram_addr[9:0]),
     .dina    (wram_dat[7:0]),
     .douta   (),
     //read (B port)
     .clkb    (clk),
     .enb     (mac_rram_clk_en),
     .web     (1'b0),
     .addrb   (mac_rram_addr[9:0]),
     .dinb    (8'b0),
     .doutb   (mac_rram_dat[7:0]) 
     );

  assign wram_clk_en = mac_wram_clk_en | ip_wram_clk_en | udp_wram_clk_en; 
  assign wram_addr = mac_wram_clk_en ? mac_wram_addr :
             ip_wram_clk_en  ? ip_wram_addr  :
             udp_wram_clk_en ? udp_wram_addr : 10'd0; 
  assign wram_dat = mac_wram_clk_en  ? mac_wram_dat :
             ip_wram_clk_en  ? ip_wram_dat  :
             udp_wram_clk_en ? udp_wram_dat : 8'd0; 

  /* udp_pack AUTO_TEMPLATE (
   .udp_data_end (mac_data_end),
   )
   */
  udp_pack u_udp_pack
    (/*AUTOINST*/
     // Outputs
     .udp_data_end          (mac_data_end),      // Templated
     .app_fifo_clk_en           (app_fifo_clk_en),
     .udp_wram_clk_en           (udp_wram_clk_en),
     .udp_wram_addr         (udp_wram_addr[9:0]),
     .udp_wram_dat          (udp_wram_dat[7:0]),
     // Inputs
     .clk               (clk),
     .rst_n             (rst_n),
     .src_port              (src_port[15:0]),
     .des_port              (des_port[15:0]),
     .ip_head_end           (ip_head_end),
     .app_fifo_empty            (app_fifo_empty),
     .app_fifo_dat          (app_fifo_dat[7:0])
     );

  ip_pack u_ip_pack
    (/*AUTOINST*/
     // Outputs
     .ip_head_end           (ip_head_end),
     .ip_wram_clk_en            (ip_wram_clk_en),
     .ip_wram_addr          (ip_wram_addr[9:0]),
     .ip_wram_dat           (ip_wram_dat[7:0]),
     // Inputs
     .clk               (clk),
     .rst_n             (rst_n),
     .prot_type             (prot_type[7:0]),
     .src_ip_addr           (src_ip_addr[31:0]),
     .des_ip_addr           (des_ip_addr[31:0]),
     .mac_head_end          (mac_head_end));

  /* mac_pack AUTO_TEMPLATE (
   .prot_type          (16'h0800),
   )
   */
  mac_pack u_mac_pack
    (/*AUTOINST*/
     // Outputs
     .mac_head_end          (mac_head_end),
     .mac_wram_clk_en           (mac_wram_clk_en),
     .mac_wram_addr         (mac_wram_addr[9:0]),
     .mac_wram_dat          (mac_wram_dat[7:0]),
     .mac_rram_clk_en           (mac_rram_clk_en),
     .mac_rram_addr         (mac_rram_addr[9:0]),
     .fcs_get               (fcs_get),
     .tx_en             (tx_en),
     .txd               (txd[7:0]),
     .tx_er             (tx_er),
     .tx_busy                           (tx_busy),
     // Inputs
     .clk               (clk),
     .rst_n             (rst_n),
     .des_mac_addr          (des_mac_addr[47:0]),
     .src_mac_addr          (src_mac_addr[47:0]),
     .prot_type             (16'h0800),      // Templated
     .app_fifo_empty            (app_fifo_empty),
     .mac_data_end          (mac_data_end),
     .mac_rram_dat          (mac_rram_dat[7:0]),
     .fcs_en                (fcs_en),
     .fcs               (fcs[31:0]));

  

endmodule // tcpip

  
