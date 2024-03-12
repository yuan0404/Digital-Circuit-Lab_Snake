`timescale 1ns / 1ps

module finalproject(
    input  clk,
    input  reset_n,
    input  [3:0] usr_btn,
    input  [3:0] usr_sw,
    output [3:0] usr_led,

    output VGA_HSYNC,
    output VGA_VSYNC,
    output [3:0] VGA_RED,
    output [3:0] VGA_GREEN,
    output [3:0] VGA_BLUE
    );

// Button and Switch Declaration    
wire btn_level[3:0], switch_level[3:0];

// SRAM Declarations
wire [16:0] sram_addr_cover, sram_addr_heart, sram_addr_score, sram_addr_end;
wire [11:0] data_in;
wire [11:0] data_out_cover, data_out_heart, data_out_score, data_out_lose, data_out_win;
wire sram_we, sram_en;

// VGA Declarations
wire vga_clk;         
wire video_on;        
wire pixel_tick;      
wire [9:0] pixel_x, pixel_y;
reg  [11:0] rgb_reg;
reg  [11:0] rgb_next;
reg  [17:0] pixel_addr_cover, pixel_addr_heart, pixel_addr_score, pixel_addr_end;
reg  [17:0] heart_addr[0:2], score_addr[0:3];

// Game Logic Declarations
integer i, j, k, speed = 0, min_speed = 50;
wire heart_region, score_region, end_region, ball_region, edge_region, bar_region1, bar_region2;
wire bar1, bar2, level_end;
reg  [2:0] heart, score;
reg  [5:0] snake_node;
reg  [20:0] snake_clock, snake_region;
reg  [132:0] ball_x_pos = 150, ball_y_pos = 400;
reg  [132:0] up_pos1 = 150, down_pos1 = 300, left_pos1 = 500, right_pos1 = 510;
reg  [132:0] up_pos2 = 150, down_pos2 = 160, left_pos2 = 80, right_pos2 = 230;
reg  [199:0] snake_VPOS, snake_pos; 
reg  [5:0] ball_r = 9;
reg  [1:0] cur_level, add_done, score_done;
reg  hit_bar, hit_edge, already_hit_bar, detector, snake;

// FSM Declarations
reg [3:0] P, P_next;  

// Position Constants
localparam VBUF_W = 320, VBUF_H = 240;
localparam snake_W = 10, snake_H = 10;
localparam H_VPOS = 200, heart_W = 64, heart_H = 32; 
localparam S_VPOS = 200, score_W = 64, score_H = 32; 
localparam E_VPOS = 88, edge_W = 64, edge_H = 80; 

// FSM Constants
localparam [3:0] MAIN_INIT = 0, GO_UP = 1, GO_RIGHT = 2, GO_DOWN = 3, GO_LEFT = 4, 
                 STOP = 5, LOSE = 6, COVER = 7, CHANGE=8, WIN =9;   

// Debounce Module Instances
debounce btn_db0(.clk(clk), .btn_input(usr_btn[0]), .btn_output(btn_level[0]));
debounce btn_db1(.clk(clk), .btn_input(usr_btn[1]), .btn_output(btn_level[1]));
debounce btn_db2(.clk(clk), .btn_input(usr_btn[2]), .btn_output(btn_level[2]));
debounce btn_db3(.clk(clk), .btn_input(usr_btn[3]), .btn_output(btn_level[3]));
debounce2 sw_db0(.clk(clk), .sw_input(usr_sw[0]), .sw_output(switch_level[0]));
debounce2 sw_db1(.clk(clk), .sw_input(usr_sw[1]), .sw_output(switch_level[1]));
debounce2 sw_db2(.clk(clk), .sw_input(usr_sw[2]), .sw_output(switch_level[2]));
debounce2 sw_db3(.clk(clk), .sw_input(usr_sw[3]), .sw_output(switch_level[3]));

// VGA Synchronization Module Instance
vga_sync vs0(
    .clk(vga_clk), .reset(~reset_n), .oHS(VGA_HSYNC), .oVS(VGA_VSYNC),
    .visible(video_on), .p_tick(pixel_tick),
    .pixel_x(pixel_x), .pixel_y(pixel_y)
);

// Clock Divider Module Instance
clk_divider#(2) clk_divider0(.clk(clk), .reset(~reset_n), .clk_out(vga_clk));

// SRAM Access Module Instaces
sram_seabed #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(VBUF_W * VBUF_H))
    ram0 (.clk(clk), .we(sram_we), .en(sram_en), .addr(sram_addr_cover), .data_i(data_in), .data_o(data_out_cover));
sram_heart #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(heart_W * heart_H * 3))
    ram1 (.clk(clk), .we(sram_we), .en(sram_en), .addr(sram_addr_heart), .data_i(data_in), .data_o(data_out_heart));
sram_score #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(score_W * score_H * 5))
    ram2 (.clk(clk), .we(sram_we), .en(sram_en), .addr(sram_addr_score), .data_i(data_in), .data_o(data_out_score));
sram_lose #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(edge_H * edge_W))
    ram3 (.clk(clk), .we(sram_we), .en(sram_en), .addr(sram_addr_end), .data_i(data_in), .data_o(data_out_lose));
sram_win #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(edge_H * edge_W))
    ram4 (.clk(clk), .we(sram_we), .en(sram_en), .addr(sram_addr_end), .data_i(data_in), .data_o(data_out_win));

// SRAM Access Assignment    
assign sram_en = 1;         
assign data_in = 12'h000;  
assign sram_we = (usr_btn[0] && usr_btn[1] && usr_btn[2] && usr_btn[3]);      
assign sram_addr_cover = pixel_addr_cover;
assign sram_addr_heart = pixel_addr_heart;
assign sram_addr_score = pixel_addr_score;
assign sram_addr_end = pixel_addr_end;

// VGA Color Assignment
assign {VGA_RED, VGA_GREEN, VGA_BLUE} = rgb_reg;

// Game Logic Assignment
assign level_end = (score >= 5)? 1:0;
assign heart_region = pixel_y >= (H_VPOS << 1) && pixel_y < (H_VPOS + heart_H) << 1 && (pixel_x + 127) >= 605 && pixel_x < 605 + 1;
assign score_region = pixel_y >= (S_VPOS << 1) && pixel_y < (S_VPOS + heart_H) << 1 && (pixel_x + 127) >= 476 && pixel_x < 476 + 1;
assign end_region = pixel_y >= (E_VPOS << 1) && pixel_y < (E_VPOS + edge_H) << 1 && (pixel_x + 127) >= 384 && pixel_x < 384 + 1;
assign ball_region = (pixel_x - ball_x_pos) * (pixel_x - ball_x_pos) + (pixel_y - ball_y_pos) * (pixel_y - ball_y_pos) <= (ball_r * ball_r);
assign bar1 = pixel_y >= 141 && pixel_y <= 309 && pixel_x >= 491 && pixel_x <= 519;
assign bar2 = pixel_y >= 141 && pixel_y <= 169 && pixel_x >= 21 && pixel_x <= 299;
assign bar_region1 = detector && (cur_level == 1) && (pixel_y >= up_pos1 && pixel_y <= down_pos1 && pixel_x >= left_pos1 && pixel_x <= right_pos1);
assign bar_region2 = detector && (cur_level == 1) && (pixel_y >= up_pos2 && pixel_y <= down_pos2 && pixel_x >= left_pos2 && pixel_x <= right_pos2);
assign edge_region = pixel_y <= 20 || pixel_y >= 460 || pixel_x <= 20 || pixel_x >= 620;

// Initialize Addresses
initial begin
    heart_addr[0] = 'd0;      
    heart_addr[1] = heart_H * heart_W;
    heart_addr[2] = heart_H * heart_W * 2;
    score_addr[0] = 'd0;      
    score_addr[1] = score_H * score_W;
    score_addr[2] = score_H * score_W * 2;
    score_addr[3] = score_H * score_W * 3;
    score_addr[4] = score_H * score_W * 4;
end

// FSM Logic
always @(posedge clk) begin
    if (~reset_n) P <= COVER;
    else P <= P_next;
end

// FSM Next State Logic
always @(*) begin
    case (P)
        COVER:
            if (btn_level[0]) P_next <= MAIN_INIT;
    		    else P_next <= COVER;
    	  MAIN_INIT:
         		if (btn_level[0]) P_next <= GO_RIGHT;
        		else if (level_end) P_next <= CHANGE;
         		else P_next <= MAIN_INIT;
        GO_UP:
            if (level_end) P_next <= CHANGE;
            else if (!ball_region && (hit_edge || hit_bar)) P_next <= STOP;
            else if (btn_level[1]) P_next <= GO_RIGHT;
            else if (btn_level[3]) P_next <= GO_LEFT;
            else P_next <= GO_UP;
        GO_RIGHT:
            if(level_end) P_next <= CHANGE;
            else if (!ball_region && (hit_edge || hit_bar)) P_next <= STOP;
            else if (btn_level[0]) P_next <= GO_UP;
            else if (btn_level[2]) P_next <= GO_DOWN;
            else P_next <= GO_RIGHT;
        GO_DOWN:
            if (level_end) P_next <= CHANGE;
            else if (!ball_region && (hit_edge || hit_bar)) P_next <= STOP;
            else if (btn_level[1]) P_next <= GO_RIGHT;
            else if (btn_level[3]) P_next <= GO_LEFT;
            else P_next <= GO_DOWN;
        GO_LEFT:
            if (level_end) P_next <= CHANGE;
            else if (!ball_region && (hit_edge || hit_bar)) P_next <= STOP;
            else if (btn_level[0]) P_next <= GO_UP;
            else if (btn_level[2]) P_next <= GO_DOWN;
            else P_next <= GO_LEFT;
        STOP:
            if (heart <= 2) P_next = MAIN_INIT;
            else if (heart > 2) P_next = LOSE;
        LOSE:
            P_next <= LOSE;
        CHANGE:
            if (cur_level == 0) P_next = MAIN_INIT;
            else P_next <= WIN;
        WIN:
            P_next <= WIN;
    endcase
end

// Hit Bar Logic
always@(posedge clk)begin
    if (~reset_n || P == MAIN_INIT) begin
        hit_bar <= 0;
        already_hit_bar <=0;
    end else begin
        for (k = 0; k < snake_node; k = k + 1) begin
            if ((!already_hit_bar) && snake_region[k] && (bar_region1 || bar_region2) && (P == GO_LEFT || P == GO_RIGHT || P == GO_UP || P == GO_DOWN)) begin
                hit_bar <= 1;
                already_hit_bar <= 1;
            end
        end
        already_hit_bar <= 0;
    end
end

// Hit Edge Logic
always@(posedge clk)begin
    if (~reset_n || P == MAIN_INIT) begin
        hit_edge <= 0;
    end else if (!ball_region && edge_region && ((snake_region[1] && (P == GO_LEFT || P == GO_RIGHT || P == GO_UP)) || (snake_region[0] && P == GO_DOWN))) begin
        hit_edge <= 1;
    end
end

// Level Logic
always @(posedge clk)begin
    if (~reset_n) begin
        detector <= 0;
        cur_level <= 0;
    end
    if (P == COVER && P_next == MAIN_INIT) begin
        detector <= 0;
    end
    if (P == CHANGE)begin
        detector <= 1;
        cur_level <= 1;
    end
end

// Snake Logic
always @(posedge clk) begin
    // Initial
    if (~reset_n || P == MAIN_INIT) begin
        if (~reset_n) begin
            heart <= 0;
            score <= 0;
            ball_x_pos = 150; 
            ball_y_pos = 400;
        end
        snake_node = 5;
        snake_VPOS = 0;
        snake_pos = 0;
        for (k = 0; k < snake_node; k = k + 1) begin
            snake_VPOS[snake_node * 10 - 1 - k * 10 -: 10] = 60;
            snake_pos[snake_node * 10 - 1 - k * 10 -: 10] = 150 - k * snake_W * 2;
        end
    end

    // Update Position
    if (ball_region && snake_region[0] && !score_done) begin
        score <= score + 1;
        score_done <= 1;
        ball_x_pos = 39 + snake_clock % (601 - 39 + 1); 
        ball_y_pos = 39 + snake_clock % (441 - 39 + 1);
        if (bar2 && bar1 && snake_region[0] && snake_region[1] && snake_region[2] && snake_region[3] && snake_region[4]) begin
            ball_x_pos = 39 + snake_clock % (601 - 39 + 1); 
            ball_y_pos = 39 + snake_clock % (441 - 39 + 1);
        end

        if (P == GO_UP) begin
            snake_VPOS = snake_VPOS[9 -: 10] | ((snake_VPOS >> 10 | (snake_VPOS[snake_node * 10 - 1 -: 10] - snake_clock[20] * snake_H) << ((snake_node - 1) * 10)) << 10);
            snake_pos = snake_pos[9 -: 10] | ((snake_pos >> 10 | (snake_pos[snake_node * 10 - 1 -: 10]) << ((snake_node - 1) * 10)) << 10);
            snake_node = snake_node + 1;
            score_done <= 0;
        end else if (P == GO_RIGHT) begin
            snake_pos = snake_pos[9 -: 10] | ((snake_pos >> 10 | (snake_pos[snake_node * 10 - 1 -: 10] + snake_clock[20] * snake_W * 2) << ((snake_node - 1) * 10)) << 10);
            snake_VPOS = snake_VPOS[9 -: 10] | ((snake_VPOS >> 10 | (snake_VPOS[snake_node * 10 - 1 -: 10]) << ((snake_node - 1) * 10)) << 10);
            snake_node = snake_node + 1;
            score_done <= 0;
        end else if (P == GO_DOWN) begin
            snake_VPOS = snake_VPOS[9 -: 10] | ((snake_VPOS >> 10 | (snake_VPOS[snake_node * 10 - 1 -: 10] + snake_clock[20] * snake_H) << ((snake_node - 1) * 10)) << 10);
            snake_pos = snake_pos[9 -: 10] | ((snake_pos >> 10 | (snake_pos[snake_node * 10 - 1 -: 10]) << ((snake_node - 1) * 10)) << 10);
            snake_node = snake_node + 1;
            score_done <= 0;
        end else if (P == GO_LEFT) begin
            snake_pos = snake_pos[9 -: 10] | ((snake_pos >> 10 | (snake_pos[snake_node * 10 - 1 -: 10] - snake_clock[20] * snake_W * 2) << ((snake_node - 1) * 10)) << 10);
            snake_VPOS = snake_VPOS[9 -: 10] | ((snake_VPOS >> 10 | (snake_VPOS[snake_node * 10 - 1 -: 10]) << ((snake_node - 1) * 10)) << 10);
            snake_node = snake_node + 1;
            score_done <= 0;
        end    
    end
    
    // Other Conditions
    if (P == CHANGE && !cur_level) begin
        snake_node = 5;
        snake_VPOS = 0;
        snake_pos = 0;
        score <= 0;
        for (k = 0; k < snake_node; k = k + 1) begin
            snake_VPOS[snake_node * 10 - 1 - k * 10 -: 10] = 60;
            snake_pos[snake_node * 10 - 1 - k * 10 -: 10] = 150 - k * snake_W * 2;
        end
    end else if ((hit_edge || hit_bar) && !add_done && !ball_region) begin
        heart <= heart + 1;
        add_done <= 1;
    end else if (P == MAIN_INIT) begin
        add_done <= 0;
        score_done <= 0;
    end else if (P == GO_UP && snake_clock[20]) begin 
        snake_VPOS = snake_VPOS >> 10 | (snake_VPOS[snake_node * 10 - 1 -: 10] - snake_clock[20] * snake_H) << ((snake_node - 1) * 10);
        snake_pos = snake_pos >> 10 | (snake_pos[snake_node * 10 - 1 -: 10]) << ((snake_node - 1) * 10);
    end else if (P == GO_RIGHT && snake_clock[20]) begin 
        snake_pos = snake_pos >> 10 | (snake_pos[snake_node * 10 - 1 -: 10] + snake_clock[20] * snake_W * 2) << ((snake_node - 1) * 10);
        snake_VPOS = snake_VPOS >> 10 | (snake_VPOS[snake_node * 10 - 1 -: 10]) << ((snake_node - 1) * 10);
    end else if (P == GO_DOWN && snake_clock[20]) begin
        snake_VPOS = snake_VPOS >> 10 | (snake_VPOS[snake_node * 10 - 1 -: 10] + snake_clock[20] * snake_H) << ((snake_node - 1) * 10);
        snake_pos = snake_pos >> 10 | (snake_pos[snake_node * 10 - 1 -: 10]) << ((snake_node - 1) * 10);
    end else if(P == GO_LEFT && snake_clock[20]) begin
        snake_pos = snake_pos >> 10 | (snake_pos[snake_node * 10 - 1 -: 10] - snake_clock[20] * snake_W * 2) << ((snake_node - 1) * 10);
        snake_VPOS = snake_VPOS >> 10 | (snake_VPOS[snake_node * 10 - 1 -: 10]) << ((snake_node - 1) * 10);
    end
end

// Snake Clock Logic
always @(posedge clk) begin
    if (~reset_n) snake_clock <= 0;
    else if (snake_clock[20] == 1) snake_clock <= 0;
    else if (speed == 0) snake_clock <= snake_clock + 1;
end

// Snake Region Logic
always @(posedge clk) begin
    if (~reset_n) begin
        for (i = 0; i < snake_node; i = i + 1) begin
            snake_region[i] = 0;
        end
    end else begin
        for (i = 0; i < snake_node; i = i + 1) begin
            snake_region[i] <=
            pixel_y >= (snake_VPOS[snake_node * 10 - 1 - i * 10 -: 10] << 1) && pixel_y < (snake_VPOS[snake_node * 10 - 1 - i * 10 -: 10] + snake_H) << 1 &&
            (pixel_x + (2 * snake_W - 1)) >= snake_pos[snake_node * 10 - 1 - i * 10 -: 10] && pixel_x < snake_pos[snake_node * 10 - 1 - i * 10 -: 10] + 1;
        end  
    end
end

// Switch Logic
always @(posedge clk) begin
    min_speed = 50;
    if (switch_level[0]) min_speed = min_speed - 10;
    if (switch_level[1]) min_speed = min_speed - 10;
    if (switch_level[2]) min_speed = min_speed - 10;
    if (switch_level[3]) min_speed = min_speed - 10;
end

// Speed Control Logic
always @(posedge clk) begin
    if (speed >= min_speed) speed <= 0;
    else speed <= speed + 1;	
end

// Pixel Addresses Logic
always @ (posedge clk) begin
    if (~reset_n) begin
        pixel_addr_cover <= 0;
        pixel_addr_heart <= 0;
        pixel_addr_score <= 0;
    end else if (end_region) begin
        pixel_addr_end <= ((pixel_y >> 1) - E_VPOS) * edge_W + ((pixel_x + (edge_W * 2 - 1) - 384) >> 1);
    end
    
    if (score_region)
        if (score == 'd4)
            pixel_addr_score <= 'd8192 + ((pixel_y >> 1) - S_VPOS) * score_W + ((pixel_x + (score_W * 2 - 1) - 476) >> 1);
        else
            pixel_addr_score <= score_addr[score] + ((pixel_y >> 1) - S_VPOS) * score_W + ((pixel_x + (score_W * 2 - 1) - 476) >> 1);
    if (heart_region)
        pixel_addr_heart <= heart_addr[heart] + ((pixel_y >> 1) - H_VPOS) * heart_W + ((pixel_x + (heart_W * 2 - 1) - 605) >> 1);
    
    pixel_addr_cover <= (pixel_y >> 1) * VBUF_W + (pixel_x >> 1);
end

// Color Update Logic
always @(posedge clk) begin
    if (pixel_tick) rgb_reg <= rgb_next;
end

// Color Selection Logic
always @(*) begin
    if (~video_on) begin
        rgb_next = 12'h000; 
        snake = 0;
    end else begin
        if (P == COVER) begin
            rgb_next = data_out_cover;
        end else if (P == WIN) begin
            if (end_region && data_out_win != 12'h0f0) rgb_next = data_out_win;
            else rgb_next = 12'h082;
        end else if (P == LOSE) begin
            if (end_region && data_out_lose != 12'h0f0) rgb_next = data_out_lose;
            else rgb_next = 12'h082; 
        end else if (edge_region) begin
            rgb_next = 12'hfff;
        end else if (ball_region) begin  
            rgb_next <= 12'haf2;
        end else begin
            if (bar_region1 | bar_region2) rgb_next <= 12'hac9;
            for (j = 0; j < snake_node; j = j + 1) begin
                if (snake_region[j]) begin
                    rgb_next = 12'heb7; 
                    snake = 1;
                end    
            end
            if (snake == 0) begin
                if (score_region && data_out_score > 12'haaa) rgb_next = 12'h9fe;
                else if (heart_region && data_out_heart != 12'h2f0) rgb_next = data_out_heart;
                else rgb_next = 12'h082;
            end 
        end
        snake = 0; 
    end
end

endmodule