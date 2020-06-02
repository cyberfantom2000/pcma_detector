module pcma_detector #(
    parameter DATA_WIDTH_IQ   = 10,  // длина регистров I и Q
    parameter DATA_WIDTH_CORD = 16,  
    parameter PERIOD_WIDTH 	  = 16,  // длина регистра периодов Seek и Lock
    parameter BOUND_WIDTH     = 10,  // ширина границ
    parameter BOUND_NUM       = 32,  // количесвто границ, должно быть кратно степени 2. FIX: пока работает только до 32, один модуль не параметризировать
    parameter BOUND_NUM_WIDTH = 5    // количесвто бит в которое влезет число BOUND_NUM
)(							  
    input                     clk, 
    input                     reset_n,

    input [2:0]               mode_i,        // 001 - fm4, 010 - fm8 
    input [DATA_WIDTH_IQ-1:0] I_data_i,      // input I; значения приходят в допкоде
    input [DATA_WIDTH_IQ-1:0] Q_data_i,      // input Q; значения приходят в допкоде
    input                     data_val_i, 
    input [PERIOD_WIDTH-1:0]  period_seek_i, // значение периода для поиска захвата
    input [PERIOD_WIDTH-1:0]  period_lock_i, // значение периода удержания захвата Lock > Seek
     
    output                    lock_o
);

wire suare_calc_val; // Сигнал валидность от модуля вычисления квадрата (выставляет его кордик)
wire[15:0] sqrt_R;   // Размер шины зависит от конфигурации кордика, потом через дерективы можно параметризировать
reg        sqare_en; // Пока идет накопление статистики sqare_en==1, после окончания периода ==0

wire                           stat_accum_val;  // выход валид модуля statistic_accum
wire[BOUND_NUM_WIDTH-1:0]      max_num;         // Номер границы, содержащей максимум
wire[DATA_WIDTH_CORD*BOUND_NUM-1:0] accum_arr;  // Регистр в который записаны все границы накопленного массива
                                                // 0-11 бит 0 ячейка массива, 12-23 бит 1 ячейка массива и т.д.

reg srart_calc;
wire lock_val;
reg start_search_max;
reg clear;

// Модуль вычисления квадрата растояния
diff_square_calc #(
    .DATA_WIDTH(DATA_WIDTH_IQ)
)diff_square_calc_inst(
    .clk        (clk),
    .reset_n    (reset_n),
    
    .mode_i     (mode_i),
    .enable_i   (sqare_en),
    .data_val_i (data_val_i),
    .I_data_i   (I_data_i),
    .Q_data_i   (Q_data_i),
    
    .valid_o    (suare_calc_val),
    .sqrt_R_o   (sqrt_R)
);

// Модуль накпоелния статистики и вычисления номера максимума
statistic_accum #(
    .DATA_WIDTH      (DATA_WIDTH_CORD),    // FIX: зависит от конфигурации кордика, подумать как исправить
    .BOUND_WIDTH     (BOUND_WIDTH),
    .BOUND_NUM       (BOUND_NUM),
    .BOUND_NUM_WIDTH (BOUND_NUM_WIDTH)
)statistic_accum_inst(
    .clk              (clk),
    .reset_n          (reset_n),
    
    .data_val_i       (suare_calc_val),
    .start_search_max (start_search_max),
    .clear_i          (clear),
    .data_i           (sqrt_R),
    
    .data_val_o       (stat_accum_val),
    .max_num_o        (max_num),
    .arr_o            (accum_arr)
);


// Модуль расчет за/против
lock_calc #(
    .DATA_WIDTH      (DATA_WIDTH_CORD),    // FIX: зависит от конфигурации кордика, подумать как исправить
    .BOUND_WIDTH     (BOUND_WIDTH),
    .BOUND_NUM       (BOUND_NUM),
    .BOUND_NUM_WIDTH (BOUND_NUM_WIDTH)
)lock_calc_inst(
    .clk        (clk),
    .reset_n    (reset_n),
    
    .mode_i     (mode_i),
    .data_val_i (srart_calc),
    .max_num_i  (max_num),
    .data_i     (accum_arr),
    
    .val_o      (lock_val),
    .lock_o     (lock_o)
);

// Счетчик периода. Считает количество обработанных точек

reg[PERIOD_WIDTH-1:0] cntr;
reg[PERIOD_WIDTH-1:0] meas_period;
always@(posedge clk) begin
    if( !reset_n ) begin
        cntr <= 0;
    end else begin
        if( cntr != 0 ) begin
            if( suare_calc_val ) begin
                cntr <= cntr - 1;
            end
        end else begin
            cntr <= meas_period;
        end
    end
end

//------------------------------//
//---------   FSM    -----------//
//------------------------------//

reg[2:0] state, nextstate;
localparam IDLE_ST       = 0;
localparam ACCUM_ST      = 1;
localparam SEARCH_MAX_ST = 2;
localparam CALC_ST       = 3;

always@(posedge clk) begin
    if( !reset_n ) state <= IDLE_ST;
    else           state <= nextstate;
end

always@(*) begin
    nextstate        = 'hX;
    meas_period      = 0;
    start_search_max = 0;
    clear            = 0;
    srart_calc       = 0;
    sqare_en         = 0;

    
    case(state)
        IDLE_ST: begin
            nextstate = IDLE_ST;
            clear = 1;
            if( data_val_i ) begin
                if( lock_o ) meas_period = period_lock_i;
                else         meas_period = period_seek_i;
                
                sqare_en  = 1;
                clear     = 0;
                nextstate = ACCUM_ST;
            end
        end
        
        ACCUM_ST: begin
            nextstate = ACCUM_ST;
            sqare_en  = 1;
            if( cntr == 0 ) begin
                start_search_max = 1;
                nextstate        = SEARCH_MAX_ST;
            end
        end
        
        SEARCH_MAX_ST: begin
            nextstate        = SEARCH_MAX_ST;
            start_search_max = 1;
            if( stat_accum_val ) begin
                srart_calc = 1;
                nextstate  = CALC_ST;
            end
        end
            
        CALC_ST: begin
            nextstate = CALC_ST;
            if( lock_val ) nextstate = IDLE_ST;                
        end
    endcase
end




endmodule