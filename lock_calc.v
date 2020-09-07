//FIX: я пока не смог придумать как сделать этот модуль параметризируемым, возможно не правильно понял суть, как ты предлагал сделать сумму по шагам.
//     тоесть на данный момент получается вся система параметров нормально не работает, пока не придумал как задавать определенное количство "шагов" сложения

module lock_calc #(
    parameter DATA_WIDTH      = 16,
    parameter BOUND_WIDTH     = 10,    // ширина границ
    parameter BOUND_NUM       = 32,    // количесвто границ должно быть равно 32!!
    parameter BOUND_NUM_WIDTH = 5      // количество бит в которые можно записать число BOUND_NUM
    
)(
    input                           clk       ,
    input                           reset_n   ,
      
    input                           data_val_i,
    input[BOUND_NUM_WIDTH-1:0]      max_num_i ,
    input[DATA_WIDTH*BOUND_NUM-1:0] data_i    ,
    input[3:0]                      max_coef_i,     // Коэффициенты подстройки для максимума
    input[3:0]                      in_coef_i ,      // Коэффициенты подстройки для столбцов, прилегающих к максимуму
    input[3:0]                      out_coef_i,     // Коэффициенты подстройки для точек против
    
    output                          val_o     ,
    output                          lock_o   
);

//****** Constant and Parameters ******//
localparam fm4_mode = 3'b001;
localparam fm8_mode = 3'b010;
/*
// Коэффициенты для подстройки результатов fm4
localparam fm4_max_coef = 4;	// для максимума
localparam fm4_in_coef  = 3;	// для столбцов, прилегающих к максимуму
// Коэффициенты для подстройки результатов fm8
localparam fm8_max_coef = 2;	// для максимума
localparam fm8_in_coef  = 2;	// для столбцов, прилегающих к максимуму

localparam out_coef     = 1;	// для точек против
*/

//************ Declaration ************//
reg data_val_shift;
reg[DATA_WIDTH-1: 0] arr_in[0:  BOUND_NUM-1];

reg [DATA_WIDTH:  0] sum_0[0: BOUND_NUM/2-1];
reg [DATA_WIDTH+1:0] sum_1[0: BOUND_NUM/4-1];
reg [DATA_WIDTH+2:0] sum_2[0: BOUND_NUM/8-1];
reg [DATA_WIDTH+3:0] sum_3[0:BOUND_NUM/16-1];
reg [DATA_WIDTH+4:0] sum_4                  ;

// Сдвиговые регистры нужны для того чтобы на 1 такт задержать сигнала защелки сложения в регистр, это позволяет избавится от FSM.
reg lock_sum_0, lock_sum_1, lock_sum_2, lock_sum_3, lock_sum_4;
reg lock_sum_0_shift, lock_sum_1_shift, lock_sum_2_shift, lock_sum_3_shift, lock_sum_4_shift;

reg                            val_in   ;
reg [BOUND_NUM_WIDTH-1     :0] max_num_r;
reg [DATA_WIDTH*BOUND_NUM-1:0] data_r   ;
reg [3                     :0] max_coe_r, in_coe_r, out_coe_r;

// Pipeling
always@(posedge clk) begin
    if(!reset_n) begin
        val_in    <= 0;
        max_num_r <= 0;
        data_r    <= 0;
        max_coe_r <= 0;
        in_coe_r  <= 0;
        out_coe_r <= 0;
    end else begin    
        val_in    <= data_val_i;
        max_num_r <= max_num_i;
        data_r    <= data_i;
        max_coe_r <= max_coef_i;
        in_coe_r  <= in_coef_i;
        out_coe_r <= out_coef_i;    
    end
end

genvar i;
generate
    for(i = 0; i < BOUND_NUM; i = i + 1) begin
        always@(posedge clk) begin
            if( !reset_n ) begin
                arr_in[i]      <= 0;
                data_val_shift <= 0;
            end else if( val_in ) begin
                arr_in[i] <= data_r[(i*DATA_WIDTH + DATA_WIDTH)-1 : i*DATA_WIDTH];
                data_val_shift <= val_in;
            end else begin
                data_val_shift <= val_in;
            end
        end
    end
endgenerate




// Первая линия сумматоров
generate
    for(i = 0; i < BOUND_NUM/2; i = i + 1) begin
        if( i == 0 ) begin
            always@(posedge clk) begin
                if( !reset_n ) begin
                    sum_0[i]         <= 0;
                    lock_sum_0       <= 0;
                    lock_sum_0_shift <= 0;
                end else if(data_val_shift) begin
                    sum_0[i]         <= arr_in[2*i] + arr_in[2*i+1];
                    lock_sum_0       <= 1;
                    lock_sum_0_shift <= lock_sum_0;
                end else begin
                    lock_sum_0       <= 0;
                    lock_sum_0_shift <= lock_sum_0;
                end
            end
        end else begin
            always@(posedge clk) begin
                if( !reset_n ) begin
                    sum_0[i] <= 0;                   
                end else if(data_val_shift) begin
                    sum_0[i] <= arr_in[2*i] + arr_in[2*i+1];
                end
            end
        end
    end 
endgenerate


// Вторая линия сумматоров
generate
    for(i = 0; i < BOUND_NUM/4; i = i + 1) begin
        if( i == 0 ) begin
            always@(posedge clk) begin
                if( !reset_n ) begin
                    sum_1[i]         <= 0;
                    lock_sum_1       <= 0;
                    lock_sum_1_shift <= 0;
                end else if(lock_sum_0_shift) begin
                    sum_1[i]         <= sum_0[2*i] + sum_0[2*i+1];
                    lock_sum_1       <= 1;
                    lock_sum_1_shift <= lock_sum_1;
                end else begin
                    lock_sum_1       <= 0;
                    lock_sum_1_shift <= lock_sum_1;
                end
            end
        end else begin
            always@(posedge clk) begin
                if( !reset_n ) begin
                    sum_1[i] <= 0;
                end else if(lock_sum_0_shift) begin
                    sum_1[i] <= sum_0[2*i] + sum_0[2*i+1];
                end
            end
        end
    end 
endgenerate


// Третья линия сумматоров
generate
    for(i = 0; i < BOUND_NUM/8; i = i + 1) begin
        if( i == 0 ) begin
            always@(posedge clk) begin
                if( !reset_n ) begin
                    sum_2[i]         <= 0;
                    lock_sum_2       <= 0;
                    lock_sum_2_shift <= 0;
                end else if(lock_sum_1_shift) begin
                    sum_2[i]         <= sum_1[2*i] + sum_1[2*i+1];
                    lock_sum_2       <= 1;
                    lock_sum_2_shift <= lock_sum_2;
                end else begin
                    lock_sum_2       <= 0;
                    lock_sum_2_shift <= lock_sum_2;
                end
            end
        end else begin
            always@(posedge clk) begin
                if( !reset_n ) begin
                    sum_2[i] <= 0;
                end else if(lock_sum_1_shift) begin
                    sum_2[i] <= sum_1[2*i] + sum_1[2*i+1];
                end
            end
        end 
    end 
endgenerate


// Четвертая линия сумматоров
generate
    for(i = 0; i < BOUND_NUM/16; i = i + 1) begin
        if ( i == 0 ) begin
            always@(posedge clk) begin
                if( !reset_n ) begin
                    sum_3[i]         <= 0;
                    lock_sum_3       <= 0;
                    lock_sum_3_shift <= lock_sum_3;
                end else if(lock_sum_2_shift) begin
                    sum_3[i]         <= sum_2[2*i] + sum_2[2*i+1];
                    lock_sum_3       <= 1;
                    lock_sum_3_shift <= lock_sum_3;
                end else begin
                    lock_sum_3       <= 0;
                    lock_sum_3_shift <= lock_sum_3;
                end
            end
        end else begin
            always@(posedge clk) begin
                if( !reset_n ) begin
                    sum_3[i] <= 0;
                end else if(lock_sum_2_shift) begin
                    sum_3[i] <= sum_2[2*i] + sum_2[2*i+1];
                end
            end
        end
    end 
endgenerate


// Одинокйи сумматоро
always@(posedge clk) begin
    if( !reset_n ) begin
        sum_4            <= 0;
        lock_sum_4       <= 0;
        lock_sum_4_shift <= 0;
    end else if( lock_sum_3_shift) begin
        sum_4            <= sum_3[0] + sum_3[1];;
        lock_sum_4       <= 1;
        lock_sum_4_shift <= lock_sum_4;
    end else begin
        lock_sum_4       <= 0;
        lock_sum_4_shift <= lock_sum_4;
    end
end

// Вычисление значение максимума и границ рядом с максимумом.
reg[DATA_WIDTH-1:0] max_value;
reg[DATA_WIDTH:0]   closely_sum;
always@(posedge clk) begin
    if( !reset_n ) begin
        max_value   <= 0;
        closely_sum <= 0;
    end else if( lock_sum_0_shift ) begin
        if( max_num_r == 0 ) begin
            max_value   <= arr_in[0];
            closely_sum <= arr_in[1];
        end else if( max_num_r == 29 ) begin
            max_value   <= arr_in[31];
            closely_sum <= arr_in[30];
        end else begin
            max_value   <= arr_in[max_num_r];
            closely_sum <= arr_in[max_num_r-1] + arr_in[max_num_r+1];
        end
    end
end



// Домножение на корректирующие коэффициенты
reg[DATA_WIDTH+3:0] max_mult; 
reg[DATA_WIDTH+1:0] sum_in;
reg[DATA_WIDTH+3:0] closely_mult;

always@(posedge clk) begin
    if( !reset_n ) begin
        max_mult     <= 0;
        closely_mult <= 0;
        sum_in       <= 0;
    end else if( lock_sum_2_shift ) begin
        max_mult     <= max_value   * max_coe_r;
        closely_mult <= closely_sum * in_coe_r;
        sum_in       <= max_value   + closely_sum;
    end
end


// Вычисление точек ЗА и ПРОТИВ
reg[DATA_WIDTH+4:0] point_out, point_in;
always@(posedge clk) begin
    if( !reset_n ) begin
        point_in          <= 0;
        point_out         <= 0;
        start_check       <= 0;
        start_check_shift <= 0;
    end else if(lock_sum_4_shift) begin
        point_in          <= max_mult + closely_mult;
        point_out         <= (sum_4 - sum_in) * out_coe_r ;
        start_check       <= 1;
        start_check_shift <= start_check;
    end else begin
        start_check       <= 0;
        start_check_shift <= start_check;
    end
end


// Проверка захвата
reg lock_flag, out_val;
reg start_check, start_check_shift;    
always@(posedge clk) begin
    if( !reset_n ) begin
        lock_flag <= 0;
        out_val   <= 0;
    end else if (start_check_shift) begin
        if( point_in >= point_out ) lock_flag <= 1;
        else                        lock_flag <= 0;
        out_val <= 1;
    end else begin
        out_val <= 0;
    end
end

assign val_o  = out_val;
assign lock_o = lock_flag;

endmodule
