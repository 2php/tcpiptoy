
module tcpip_top
  (
   input wire 	     clk_125M, //tx
   input wire 	     clk_25M,
   input wire 	     rst_n, //from sys
	
   output wire 	     phy_mdc,
   inout wire 	     phy_mdio,
	
   input wire 	     phy_intn,
   output wire 	     phy_reset,
	
   input wire 	     phy_rx_clk,
   input wire 	     phy_rx_er,
   input wire 	     phy_rx_dv,
   input wire [7:0]  phy_rxd,
   //input wire      phy_crs,
   //input wire      phy_col,
   
   //output wire     phy_gtx_clk,
   //input wire	     phy_tx_clk,
   output wire 	     phy_tx_er,
   output wire 	     phy_tx_en,
   output wire [7:0] phy_txd,

   //app layer
   input wire 	     tcpip_tx_clk,
   input wire 	     tcpip_tx_en,
   input wire [7:0]  tcpip_tx_dat,
   output wire 	     tcpip_tx_fifo_full,
   output wire 	     tcpip_init_done
   
   ////to app layer
   //output wire     udp_pkt_start,
   //output wire     udp_pkt_en,
   //output wire [7:0] udp_pkt_dat,
   //output wire     udp_pkt_end,
   //   
   ////from app layer
   //input wire      udp_tx_en,
   //input wire [7:0]  udp_tx_dat
    );

  //wire 		     clk_25M;
  //wire 		     locked;
  //wire 		     rst_n;
  
  wire 		     ip_pkt_start;
  wire 		     ip_pkt_en;
  wire [7:0] 	     ip_pkt_dat;
  wire 		     ip_pkt_end;
  wire [47:0] 	     des_mac_addr_rcv;
  wire [47:0] 	     src_mac_addr_rcv;
  wire [15:0] 	     ip_prot_type;

  wire [31:0] 	     src_ip_addr;
  wire [31:0] 	     des_ip_addr;
  wire [7:0] 	     trans_prot_type;
  wire 		     trans_pkt_start;
  wire 		     trans_pkt_frag_start;
  wire [12:0] 	     trans_pkt_frag_sft;
  wire 		     trans_pkt_en;
  wire [7:0] 	     trans_pkt_dat;
  wire 		     trans_pkt_frag_end;
  wire 		     trans_pkt_end;
		     
  wire [15:0] 	     src_port;
  wire [15:0] 	     des_port;
  //wire 	     udp_pkt_start;
  //wire 	     udp_pkt_en;
  //wire [7:0] 	     udp_pkt_dat;
  //wire 	     udp_pkt_end;
  
  wire 		     normal_tx_en;
  wire [7:0] 	     normal_txd;
  wire 		     arp_resp_tx_en;
  wire [7:0] 	     arp_resp_txd;
  wire 		     tcpip_tx_busy;
  
  assign phy_tx_en = tcpip_tx_busy ? normal_tx_en : arp_resp_tx_en;
  assign phy_txd = tcpip_tx_busy ? normal_txd : arp_resp_txd;
  
  tcpip_tx u_tcpip_tx
    (
     //inputs
     .clk           (clk_125M), //125Mhz
     .rst_n         (rst_n),
     .src_mac_addr  (48'h000a35028846), //fpga
     .des_mac_addr  (48'h6c626d802701), //pc, 48'h6c626d802701
     .src_ip_addr   (32'hc0a800ae), //192.168.0.174
     .des_ip_addr   (32'hc0a800af), //192.168.0.175, 32'hc0a800af
     .src_port      (16'd20001),
     .des_port      (16'd20002),
     .prot_type     (8'd17), //udp
     .tcpip_tx_clk  (tcpip_tx_clk),
     .tcpip_tx_en   (tcpip_tx_en),
     .tcpip_tx_dat  (tcpip_tx_dat),
     //output
     .tx_en         (normal_tx_en),
     .txd           (normal_txd),
     .tx_er         (phy_tx_er),
     .tx_busy       (tcpip_tx_busy),
     .app_fifo_full (tcpip_tx_fifo_full)
     );

  manage_if u_manage_if
    (
     .clk_25M        (clk_25M),
     .rst_n          (rst_n),
    
     .mac_addr       (5'b00111),
    
     .reg_wr_en      (1'b0),
     .reg_wr_addr    (5'b0),
     .reg_wr_dat     (16'b0),

     .reg_rd_en      (1'b0),
     .reg_rd_addr    (5'b0),
     .reg_rd_dat     (),

     .reg_done       (reg_done),
    
     .phy_mdc        (phy_mdc), //management data clock reference, <=8.3Mhz
     .phy_mdio       (phy_mdio),

     .phy_intn       (phy_intn), //opendrain output from 88e1111
     .phy_reset      (phy_reset)
     );

  
  mac_unpack u_mac_unpack
    (
     .rst_n	   (rst_n),
     
     //GMII/MII rx
     .rx_clk	   (phy_rx_clk),
     .rx_dv	   (phy_rx_dv),
     .rx_er	   (phy_rx_er),
     .rxd	   (phy_rxd[7:0]),
     
     .ip_pkt_start (ip_pkt_start),
     .ip_pkt_en	   (ip_pkt_en), 
     .ip_pkt_dat   (ip_pkt_dat), 
     .ip_pkt_end   (ip_pkt_end), 
     
     .des_mac_addr (des_mac_addr_rcv), 
     .src_mac_addr (src_mac_addr_rcv), 
     .prot_type	   (ip_prot_type)
     );

  arp_resp u_arp_resp
    (
     .rx_clk	   (phy_rx_clk),
     .ip_pkt_end   (ip_pkt_end),
     .ip_prot_type (ip_prot_type),
     
     .clk          (clk_125M), 
     .rst_n        (rst_n),
     .tx_busy      (tcpip_tx_busy),
     .tx_en        (arp_resp_tx_en),
     .txd          (arp_resp_txd)
     );

  udp_rx_detect u_udp_rx_detect
    (
     //Inputs
     .rx_clk          (phy_rx_clk),
     .ip_pkt_end      (ip_pkt_end),
     .ip_prot_type    (ip_prot_type),
     .clk             (clk_125M),
     .rst_n           (rst_n),
     //Output
     .tcpip_init_done (tcpip_init_done)
     );

  
//  ip_unpack u_ip_unpack
//  (
//   .rx_clk          (phy_rx_clk), //125Mhz
//   .rst_n           (rst_n),
// 
//   .ip_pkt_start    (ip_pkt_start),
//   .ip_pkt_en       (ip_pkt_en),
//   .ip_pkt_dat      (ip_pkt_dat),
//   .ip_pkt_end      (ip_pkt_end),
// 
//   .des_mac_addr    (des_mac_addr),
//   .src_mac_addr    (src_mac_addr),
//   .ip_prot_type    (ip_prot_type),
// 
//   .src_ip_addr     (src_ip_addr),
//   .des_ip_addr     (des_ip_addr),
//   .trans_prot_type (trans_prot_type), //tcp, dup, etc.
// 
//   .trans_pkt_start      (trans_pkt_start),
//   .trans_pkt_frag_start (trans_pkt_frag_start),
//   .trans_pkt_frag_sft   (trans_pkt_frag_sft),
//   .trans_pkt_en         (trans_pkt_en),
//   .trans_pkt_dat        (trans_pkt_dat),
//   .trans_pkt_frag_end   (trans_pkt_frag_end),
//   .trans_pkt_end        (trans_pkt_end)
//   
//   );
// 
//  udp_unpack u_udp_unpack
//  (
//   //Inputs
//   .rx_clk              (phy_rx_clk), 
//   .rst_n               (rst_n),
// 
//   .src_ip_addr         (src_ip_addr),
//   .des_ip_addr         (des_ip_addr),
//   .trans_prot_type     (trans_prot_type),
// 
//   .trans_pkt_start     (trans_pkt_start),
//   .trans_pkt_frag_start(trans_pkt_frag_start),
//   .trans_pkt_frag_end  (trans_pkt_frag_end),
//   .trans_pkt_end       (trans_pkt_end),
// 
//   .trans_pkt_frag_sft  (trans_pkt_frag_sft),
//   .trans_pkt_en        (trans_pkt_en),
//   .trans_pkt_dat       (trans_pkt_dat),
//   //Outputs
//   .src_port            (src_port),
//   .des_port            (des_port),
// 
//   .udp_pkt_start       (udp_pkt_start),
//   .udp_pkt_en          (udp_pkt_en),
//   .udp_pkt_dat         (udp_pkt_dat),
//   .udp_pkt_end         (udp_pkt_end)
//   
//   );

  

endmodule
