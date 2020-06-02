// Модуль накопления статистики и поиска максимума.
module statistic_accum #(
    parameter DATA_WIDTH      = 16,
    parameter BOUND_WIDTH     = 10,    // ширина границам
    parameter BOUND_NUM       = 32,    // количесвто границ
    parameter BOUND_NUM_WIDTH = 5      // количество бит в которые можно записать число BOUND_NUM
)(
    input                            clk,
    input                            reset_n,
    
    input                            data_val_i,       // сигнал валидности от кордика
    input                            start_search_max, // должен быть выставлен до тех пор, пока не появится data_val_o
    input                            clear_i,          // обнуление массива при новом цикле накопления точек
    input[DATA_WIDTH-1:0]            data_i,
    
    output                           data_val_o,
    output[BOUND_NUM_WIDTH-1:0]      max_num_o,
    output[DATA_WIDTH*BOUND_NUM-1:0] arr_o
);


reg[DATA_WIDTH-1:0] hit_arr[0:BOUND_NUM-1];
// Распределение точек по границам.
genvar i;
generate            
    for(i = 0; i < BOUND_NUM; i = i + 1) begin
        always@(posedge clk) begin
            if( !reset_n || clear_i ) begin
                hit_arr[i] <= 0;
            end else if( data_val_i ) begin 
                if( (data_i >= i*BOUND_WIDTH) && (data_i < i*BOUND_WIDTH + BOUND_WIDTH) ) begin
                    hit_arr[i] <= hit_arr[i] + 1;
                end
            end
        end        
    end    
endgenerate


// Преобразование массива в один длинный регистр.
generate
    for(i = 0; i < BOUND_NUM; i = i + 1) begin
        assign arr_o[(i*DATA_WIDTH + DATA_WIDTH)-1 : i*DATA_WIDTH] = hit_arr[i];
    end    
endgenerate 

reg data_val;
reg[DATA_WIDTH-1:0]      max_value;
reg[BOUND_NUM_WIDTH:0] max_num, cnt_max = 0;
// Поиск максимума.
always@(posedge clk) begin
    if (!reset_n || clear_i ) begin
        cnt_max    <= 0;
        max_num    <= 0;
        max_value  <= 0;
        data_val   <= 0;
    end else if( start_search_max ) begin
        // Пройти по всему массиву и запомнить максимум
        // и номер ячейки в котором был максимум
        if( cnt_max < BOUND_NUM ) begin
            if( max_value < hit_arr[cnt_max] ) begin
                max_value <= hit_arr[cnt_max];
                max_num   <= cnt_max;
            end
            cnt_max <= cnt_max + 1;
        end else begin
            data_val <= 1;
        end    
    end
end

assign data_val_o = data_val;
assign max_num_o  = max_num;
endmodule