//FIX: я пока не смог придумать как сделать этот модуль параметризируемым, возможно не правильно понял суть, как ты предлагал сделать сумму по шагам.
//     тоесть на данный момент получается вся система параметров нормально не работает, пока не придумал как задавать определенное количство "шагов" сложения
//     также, наверное, тут можно обойтись без стейт машины
module lock_calc #(
    parameter DATA_WIDTH      = 16,
    parameter BOUND_WIDTH     = 10,    // ширина границам
    parameter BOUND_NUM       = 32,    // количесвто границ
    parameter BOUND_NUM_WIDTH = 5      // количество бит в которые можно записать число BOUND_NUM
    
)(
    input                           clk,
    input                           reset_n,
    
    input[2:0]                      mode_i,    
    input                           data_val_i,
    input[BOUND_NUM_WIDTH-1:0]      max_num_i,
    input[DATA_WIDTH*BOUND_NUM-1:0] data_i,
    
    output                          val_o,
    output                          lock_o   
);

localparam fm4_mode = 3'b001;
localparam fm8_mode = 3'b010;
//Коэффициенты для подстройки результатов fm4
localparam fm4_max_coef = 4;	//для максимума
localparam fm4_in_coef  = 3;	//для столбцов, прилегающих к максимуму
//Коэффициенты для подстройки результатов fm8
localparam fm8_max_coef = 2;	//для максимума
localparam fm8_in_coef  = 2;	//для столбцов, прилегающих к максимуму

localparam out_coef     = 1;	//для точек против


reg[DATA_WIDTH-1:0] arr_in[0:BOUND_NUM-1];
genvar i;
generate
    for(i = 0; i < BOUND_NUM; i = i + 1) begin
        always@(posedge clk) begin
            if( !reset_n ) begin
                arr_in[i] <= 0;
            end else if( data_val_i ) begin
                arr_in[i] <= data_i[(i*DATA_WIDTH + DATA_WIDTH)-1 : i*DATA_WIDTH];
            end
        end
    end
endgenerate


wire[DATA_WIDTH:0]   sum_0    [0:BOUND_NUM/2-1];
reg [DATA_WIDTH:0]   sum_0_reg[0:BOUND_NUM/2-1];
wire[DATA_WIDTH+1:0] sum_1    [0:BOUND_NUM/4-1];
reg [DATA_WIDTH+1:0] sum_1_reg[0:BOUND_NUM/4-1];
wire[DATA_WIDTH+2:0] sum_2    [0:BOUND_NUM/8-1];
reg [DATA_WIDTH+2:0] sum_2_reg[0:BOUND_NUM/8-1];
wire[DATA_WIDTH+3:0] sum_3    [0:BOUND_NUM/16-1];
reg [DATA_WIDTH+3:0] sum_3_reg[0:BOUND_NUM/16-1];
wire[DATA_WIDTH+4:0] sum_4;
reg [DATA_WIDTH+4:0] sum_4_reg;

reg lock_sum_0, lock_sum_1, lock_sum_2, lock_sum_3, lock_sum_4;
reg end_sum_0, end_sum_1, end_sum_2, end_sum_3, end_sum_4, end_calc;

// Step 1
generate
    for(i = 0; i < BOUND_NUM/2; i = i + 1) begin                    
        assign sum_0[i] = arr_in[2*i] + arr_in[2*i+1];
    end
endgenerate

// Защелка первой суммы 
generate
    for(i = 0; i < BOUND_NUM/2; i = i + 1) begin
        if( i == 0 ) begin
            always@(posedge clk) begin
                if( !reset_n ) begin
                    sum_0_reg[i] <= 0;
                    end_sum_0    <= 0;
                end else if(lock_sum_0) begin
                    sum_0_reg[i] <= sum_0[i];
                    end_sum_0    <= 1;
                end else begin
                    end_sum_0 <= 0;
                end
            end
        end else begin
            always@(posedge clk) begin
                if( !reset_n ) begin
                    sum_0_reg[i] <= 0;                   
                end else if(lock_sum_0) begin
                    sum_0_reg[i] <= sum_0[i];
                end
            end
        end
    end 
endgenerate


// Step 2
generate
    for(i = 0; i < BOUND_NUM/4; i = i + 1) begin        
        assign sum_1[i] = sum_0_reg[2*i] + sum_0_reg[2*i+1];        
    end
endgenerate

// Защелка второй суммы 
generate
    for(i = 0; i < BOUND_NUM/4; i = i + 1) begin
        if( i == 0 ) begin
            always@(posedge clk) begin
                if( !reset_n ) begin
                    sum_1_reg[i] <= 0;
                    end_sum_1    <= 0;
                end else if(lock_sum_1) begin
                    sum_1_reg[i] <= sum_1[i];
                    end_sum_1    <= 1;
                end else begin
                    end_sum_1 <= 0;
                end
            end
        end else begin
            always@(posedge clk) begin
                if( !reset_n ) begin
                    sum_1_reg[i] <= 0;
                end else if(lock_sum_1) begin
                    sum_1_reg[i] <= sum_1[i];
                end
            end
        end
    end 
endgenerate


// Step 3
generate
    for(i = 0; i < BOUND_NUM/8; i = i + 1) begin        
        assign sum_2[i] = sum_1_reg[2*i] + sum_1_reg[2*i+1];        
    end
endgenerate

// Защелка третьей суммы 
generate
    for(i = 0; i < BOUND_NUM/8; i = i + 1) begin
        if( i == 0 ) begin
            always@(posedge clk) begin
                if( !reset_n ) begin
                    sum_2_reg[i] <= 0;
                    end_sum_2    <= 0;
                end else if(lock_sum_2) begin
                    sum_2_reg[i] <= sum_2[i];
                    end_sum_2    <= 1;
                end else begin
                    end_sum_2 <= 0;
                end
            end
        end else begin
            always@(posedge clk) begin
                if( !reset_n ) begin
                    sum_2_reg[i] <= 0;
                end else if(lock_sum_2) begin
                    sum_2_reg[i] <= sum_2[i];
                end
            end
        end 
    end 
endgenerate


// Step 4
generate
    for(i = 0; i < BOUND_NUM/16; i = i + 1) begin       
        assign sum_3[i] = sum_2_reg[2*i] + sum_2_reg[2*i+1];        
    end
endgenerate

// Защелка четвертой суммы 
generate
    for(i = 0; i < BOUND_NUM/16; i = i + 1) begin
        if ( i == 0 ) begin
            always@(posedge clk) begin
                if( !reset_n ) begin
                    sum_3_reg[i] <= 0;
                    end_sum_3    <= 0;
                end else if(lock_sum_3) begin
                    sum_3_reg[i] <= sum_3[i];
                    end_sum_3    <= 1;
                end else begin
                    end_sum_3 <= 0;
                end
            end
        end else begin
            always@(posedge clk) begin
                if( !reset_n ) begin
                    sum_3_reg[i] <= 0;
                end else if(lock_sum_3) begin
                    sum_3_reg[i] <= sum_3[i];
                end
            end
        end
    end 
endgenerate

// Step 5
assign sum_4 = sum_3_reg[0] + sum_3_reg[1];

// Защелка пятой суммы 
always@(posedge clk) begin
    if( !reset_n ) begin
        sum_4_reg <= 0;
        end_sum_4 <= 0;
    end else if( lock_sum_4) begin
        sum_4_reg <= sum_4;
        end_sum_4 <= 1;
    end else begin
        end_sum_4 <= 0;
    end
end

// Вычисление значение максимума и границ рядом с максимумом.
reg[DATA_WIDTH-1:0] max_value;
reg[DATA_WIDTH:0]   closely_sum;
always@(posedge clk) begin
    if( !reset_n ) begin
        max_value   <= 0;
        closely_sum <= 0;
    end else if( lock_sum_1 ) begin
        if( max_num_i == 0 ) begin
            max_value   <= arr_in[0];
            closely_sum <= arr_in[1];
        end else if( max_num_i == 29 ) begin
            max_value   <= arr_in[31];
            closely_sum <= arr_in[30];
        end else begin
            max_value   <= arr_in[max_num_i];
            closely_sum <= arr_in[max_num_i-1] + arr_in[max_num_i+1];
        end
    end
end

// Домножение на корректирующие коэффициенты
reg[DATA_WIDTH+2:0] max_mult, closely_mult;
reg[DATA_WIDTH+1:0] sum_in;
always@(posedge clk) begin
    if( !reset_n ) begin
        max_mult     <= 0;
        closely_mult <= 0;
        sum_in       <= 0;
    end else if( lock_sum_3 ) begin
        if( mode_i == fm4_mode ) begin
            max_mult     <= max_value   * fm4_max_coef;
            closely_mult <= closely_sum * fm4_in_coef;
        end else begin
            max_mult     <= max_value   * fm8_max_coef;
            closely_mult <= closely_sum * fm8_in_coef;
        end
        sum_in <= max_value + closely_sum;
    end
end

reg[DATA_WIDTH+4:0] point_out, point_in;
reg start_last_calc;
always@(posedge clk) begin
    if( !reset_n ) begin
        point_in  <= 0;
        point_out <= 0;
        end_calc  <= 0;
    end else if( start_last_calc ) begin
        point_in  <= max_mult + closely_mult;
        point_out <= sum_4_reg - sum_in ;
        end_calc  <= 1;
    end else begin
        end_calc  <= 0;
    end
end
    
reg lock_flag, out_val;
reg start_check;    
always@(posedge clk) begin
    if( !reset_n ) begin
        lock_flag <= 0;
        out_val   <= 0;
    end else if ( start_check ) begin
        if( point_in >= point_out ) lock_flag <= 1;
        else                        lock_flag <= 0;
        out_val <= 1;
    end else begin
        out_val <= 0;
    end
end

//------------------------------//
//---------   FSM    -----------//
//------------------------------//
reg[2:0] state, nextstate;
localparam IDLE_ST      = 0;
localparam SUM_0_ST     = 1;
localparam SUM_1_ST     = 2;
localparam SUM_2_ST     = 3;
localparam SUM_3_ST     = 4;
localparam SUM_4_ST     = 5;
localparam LAST_CALC_ST = 6;
localparam CHECK_ST     = 7;

always@(posedge clk) begin
    if( !reset_n ) state <= IDLE_ST;
    else           state <= nextstate;
end


always@(*) begin
    nextstate       = 'hX;
    lock_sum_0      = 0;
    lock_sum_1      = 0;
    lock_sum_2      = 0;
    lock_sum_3      = 0;
    lock_sum_4      = 0;
    start_last_calc = 0;
    start_check     = 0;
    
    case( state )
        IDLE_ST: begin
            nextstate = IDLE_ST;
            if( data_val_i ) begin
                nextstate   = SUM_0_ST;
            end
        end
        
        SUM_0_ST: begin
            lock_sum_0 = 1;
            nextstate  = SUM_1_ST;
        end
        
        SUM_1_ST: begin
            nextstate = SUM_1_ST;
            if( end_sum_0 ) begin
                lock_sum_1 = 1;
                nextstate  = SUM_2_ST;
            end
        end
        
        SUM_2_ST: begin
            nextstate = SUM_2_ST;
            if( end_sum_1 ) begin
                lock_sum_2 = 1;
                nextstate  = SUM_3_ST;
            end
        end
        
        SUM_3_ST: begin
            nextstate = SUM_3_ST;
            if( end_sum_2 ) begin
                lock_sum_3 = 1;
                nextstate  = SUM_4_ST;
            end
        end
        
        SUM_4_ST: begin
            nextstate = SUM_4_ST;
            if( end_sum_3 ) begin
                lock_sum_4 = 1;
                nextstate  = LAST_CALC_ST;
            end
        end
        
        LAST_CALC_ST: begin
            nextstate = LAST_CALC_ST;
            if( end_sum_4 ) begin
                start_last_calc = 1;
                nextstate       = CHECK_ST;
            end
        end
        
        CHECK_ST: begin
            nextstate = CHECK_ST;
            if( end_calc ) begin
                start_check = 1;
                nextstate   = IDLE_ST;
            end
        end 
    endcase
end

assign val_o  = out_val;
assign lock_o = lock_flag;

endmodule
