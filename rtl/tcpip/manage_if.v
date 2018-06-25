//
module manage_if
  (
   input wire        clk_25M,
   input wire        rst_n,
   
   input wire [4:0]  mac_addr,
   
   input wire        reg_wr_en,
   input wire [4:0]  reg_wr_addr,
   input wire [15:0] reg_wr_dat,

   input wire        reg_rd_en,
   input wire [4:0]  reg_rd_addr,
   output reg [15:0] reg_rd_dat,

   output reg        reg_done,
   
   output reg        phy_mdc, //management data clock reference, <=8.3Mhz
   inout wire        phy_mdio,

   input wire        phy_intn, //opendrain output from 88e1111
   output reg        phy_reset
   );

   wire       mdi;
   reg        mdo;
   reg        mdoe;

   reg [1:0]  beat_cnt;
   reg [4:0]  t1us_cnt;   

   wire       ch_dat_en;

   reg [2:0]  reg_cs;
   reg [2:0]  reg_ns;

   parameter IDLE  = 3'd0;
   parameter START = 3'd1;
   parameter OPC   = 3'd2;
   parameter PHY_A = 3'd3;
   parameter REG_A = 3'd4;
   parameter TA    = 3'd5;
   parameter REG_D = 3'd6;
   parameter DONE  = 3'd7;

   wire st_idle;
   wire st_start;
   wire st_opc;
   wire st_phy_a;
   wire st_reg_a;
   wire st_ta;
   wire st_reg_d;
   wire st_done;
   
   reg [3:0]  bit_cnt;
   reg [15:0] sft_reg;
   reg        wr_n;

   reg        clk_div4;   
   
   //tri io
   assign phy_mdio = mdoe ? mdo : 1'bz;
   assign mdi = phy_mdio;

   //25Mhz / 4 = 6.25Mhz clock
   always@(posedge clk_25M, negedge rst_n)
     if(!rst_n)
       beat_cnt <= 2'b0;
     else
       beat_cnt <= beat_cnt + 1'b1;

   always@(posedge clk_25M, negedge rst_n)
     if(!rst_n)
     begin
       clk_div4 <= 1'b0;
       phy_mdc <= 1'b0;
     end
     else
     begin
       clk_div4 <= beat_cnt[1];
       phy_mdc <= clk_div4;
     end

   //write/read register
   assign ch_dat_en = (beat_cnt == 2'b01);

   always@(posedge clk_25M, negedge rst_n)
     if(!rst_n)
       bit_cnt <= 4'd0;
     else if(ch_dat_en)
       begin
          if((st_idle) ||
             (st_start && bit_cnt == 4'd1) ||
             (st_opc && bit_cnt == 4'd1) ||
             (st_phy_a && bit_cnt == 4'd4) ||
             (st_reg_a && bit_cnt == 4'd4) ||
             (st_ta && bit_cnt == 4'd1) ||
             (st_reg_d && bit_cnt == 4'd15))
            bit_cnt <= 4'd0;
          else
            bit_cnt <= bit_cnt + 1'b1;
       end // if (ch_dat_en)
   
   //state machine
   always@(posedge clk_25M, negedge rst_n)
     if(!rst_n)
       reg_cs <= IDLE;
     else
       reg_cs <= reg_ns;

   always@(*)
     case(reg_cs)
       IDLE:
         if(reg_wr_en || reg_rd_en) reg_ns = START;
         else reg_ns = IDLE;
       START:
         if(ch_dat_en && bit_cnt == 4'd1)
           reg_ns = OPC;
         else
           reg_ns = START;
       OPC:
         if(ch_dat_en && bit_cnt == 4'd1)
           reg_ns = PHY_A;
         else
           reg_ns = OPC;
       PHY_A:
         if(ch_dat_en && bit_cnt == 4'd4)
           reg_ns = REG_A;
         else
           reg_ns = PHY_A;
       REG_A:
         if(ch_dat_en && bit_cnt == 4'd4)
           reg_ns = TA;
         else
           reg_ns = REG_A;
       TA:
         if(ch_dat_en && bit_cnt == 4'd1)
           reg_ns = REG_D;
         else
           reg_ns = TA;
       REG_D:
         if(ch_dat_en && bit_cnt == 4'd15)
           reg_ns = DONE;
         else
           reg_ns = REG_D;
       DONE:
         reg_ns = IDLE;
       default:
         reg_ns = IDLE;
     endcase

   assign st_idle  = (reg_cs == IDLE);
   assign st_start = (reg_cs == START);
   assign st_opc   = (reg_cs == OPC);
   assign st_phy_a = (reg_cs == PHY_A);
   assign st_reg_a = (reg_cs == REG_A);
   assign st_ta    = (reg_cs == TA);
   assign st_reg_d = (reg_cs == REG_D);
   assign st_done  = (reg_cs == DONE);

   always@(posedge clk_25M, negedge rst_n)
     if(!rst_n)
       wr_n <= 1'b1;
     else if(reg_wr_en)
       wr_n <= 1'b0; //write
     else if(reg_rd_en)
       wr_n <= 1'b1; //read
   
   always@(posedge clk_25M, negedge rst_n)
     if(!rst_n)
       mdoe <= 1'b0;
     else if(st_start || st_opc || st_phy_a || st_reg_a ||
             (~wr_n && (st_ta || st_reg_d)))
       mdoe <= 1'b1;
     else
       mdoe <= 1'b0;

   always@(posedge clk_25M, negedge rst_n)
     if(!rst_n)
       mdo <= 1'b1;
     else if(st_idle)
       mdo <= 1'b1;
     else if(st_start)
       mdo <= bit_cnt[0];
     else if(st_opc)
       mdo <= (bit_cnt[0] ^ wr_n);
     else if(st_phy_a || st_reg_a ||
             (~wr_n && st_reg_d))
       mdo <= sft_reg[15];
     else if(~wr_n && st_ta)
       mdo <= ~bit_cnt[0];

   always@(posedge clk_25M, negedge rst_n)
     if(!rst_n)
       sft_reg <= 16'b0;
     else if(ch_dat_en)
       begin     
         if(st_opc && bit_cnt == 4'd1)
           sft_reg <= {mac_addr, 11'b0};
         else if(~wr_n && st_phy_a && bit_cnt == 4'd4)
           sft_reg <= {reg_wr_addr, 11'b0};
         else if(wr_n && st_phy_a && bit_cnt == 4'd4)
           sft_reg <= {reg_rd_addr, 11'b0};           
         else if(~wr_n && st_ta && bit_cnt == 4'd1)
           sft_reg <= reg_wr_dat;
         else
           sft_reg <= {sft_reg[14:0], 1'b0};
       end

   always@(posedge clk_25M, negedge rst_n)
     if(!rst_n)
       reg_rd_dat <= 16'b0;
     else if(st_idle)
       reg_rd_dat <= 16'b0;
     else if(wr_n && ch_dat_en && st_reg_d)
       reg_rd_dat <= {reg_rd_dat[14:0], mdi};
   
   always@(posedge clk_25M, negedge rst_n)
     if(!rst_n)
       reg_done <= 1'b0;
     else
       reg_done <= st_done;
   
   //phy_reset
   always@(posedge clk_25M, negedge rst_n)
     if(!rst_n)
       t1us_cnt <= 5'h00;
     else if(t1us_cnt == 5'h1f)
       t1us_cnt <= 5'h1f;
     else
       t1us_cnt <= t1us_cnt + 1'b1;

   always@(posedge clk_25M, negedge rst_n)
     if(!rst_n)
       phy_reset <= 1'b1;
     else if(t1us_cnt == 5'h1f)
       phy_reset <= 1'b1;
     else
       phy_reset <= 1'b0;
       
   

endmodule // manage
