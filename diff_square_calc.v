module diff_square_calc #(
    parameter DATA_WIDTH = 10
)(
    input                   clk       ,
    input                   reset_n   ,
    
    input[2:0]              mode_i    ,
    input                   data_val_i,
    input                   enable_i  ,  // сигнал примет значение 0, когда закончится период накопления
    input[DATA_WIDTH-1:0]   I_data_i  ,
    input[DATA_WIDTH-1:0]   Q_data_i  ,
    
    output                  valid_o   ,
    output[15:0]            sqrt_R_o     // Размерность зависит от конфигурации cordic. В общем размерность может быть равна [DATA_WIDTH+1:0]    
);                                       // но cordic умеет формировать выходную шину только размерностей 8, 16, 24, 32 и т.д. следовательно он формирует шину [15:0] и ругается, что биты не использу

//****** Constant and Parameters ******//
localparam fm4_mode = 3'b001;
localparam fm8_mode = 3'b010;
// qpsk ideal points
localparam idealI_qpsk = 180;
localparam idealQ_qpsk = 180;
// 8-psk ideal points
localparam idealI_8psk = 256;
localparam idealQ_8psk = 98 ;

//************ Declaration ************//
// Cordic signals
reg                         cordic_in_data_val          ;
reg        [23          :0] square_R                    ;  // Размерность зависит от конфигурации cordic. Тоже самое что и с портом sqrt_R_o
//take abs 
reg        [DATA_WIDTH-1:0] absI, absQ                  ;

reg signed [DATA_WIDTH-1:0] diff_I, diff_Q              ; //Разность рассчитываемой точки и идеальной точки
reg        [2*DATA_WIDTH:0] square_I, square_Q          ; // Квадраты I и Q

reg                         val_in                      ;
reg [DATA_WIDTH-1       :0] I_data_r, Q_data_r          ;

// Pipeling
always@(posedge clk) begin
    if(!reset_n) begin
        val_in   <= 0;
        I_data_r <= 0;
        Q_data_r <= 0;
    end else begin
        val_in   <= data_val_i;
        I_data_r <= I_data_i;
        Q_data_r <= Q_data_i;
    end
end


// cordic sqrt ip-core
cordic_0 sqrt(
	.aclk					 (clk     ), // in
	.aresetn				 (reset_n ), // in
	.s_axis_cartesian_tvalid (val_in  ), // in
	.s_axis_cartesian_tdata	 (square_R), // in
	.m_axis_dout_tvalid		 (valid_o ), // out
	.m_axis_dout_tdata		 (sqrt_R_o)	 // out
);


always @( posedge clk ) begin
    if( !reset_n ) begin
        absI <= 0;
        absQ <= 0;
    end else begin
        if(val_in) begin
            // Модуль I
            if( I_data_r[DATA_WIDTH-1] ) absI <= ~I_data_r + 1;
            else                         absI <=  I_data_r;
            // Модуль Q
            if( Q_data_r[DATA_WIDTH-1] ) absQ <= ~Q_data_r + 1;
            else                         absQ <=  Q_data_r;
        end 
    end
end

//Блок вычисление квадрата растояния
always@(posedge clk) begin
    if( !reset_n ) begin
        diff_I <= 0;
        diff_Q <= 0;
        square_I <= 0;
        square_Q <= 0;
        square_R <= 0;
    end else begin
        if( val_in ) begin
            if( mode_i == fm4_mode ) begin //qpsk
                diff_I   <= $signed({1'b0, absI}) - idealI_qpsk;
                diff_Q   <= $signed({1'b0, absQ}) - idealQ_qpsk;
                square_I <= diff_I * diff_I;
                square_Q <= diff_Q * diff_Q;
                square_R <= square_I + square_Q;
            end else begin
                //Если точка лежит ВЫШЕ прямой I=Q, то I и Q меняются местами
                if( absI < absQ ) begin
                    diff_I   <= $signed({1'b0, absQ}) - idealI_8psk;
					diff_Q   <= $signed({1'b0, absI}) - idealQ_8psk;
					square_I <= diff_I * diff_I;
					square_Q <= diff_Q * diff_Q;
					square_R <= square_I + square_Q;
                //Если точка лежит НИЖЕ прямой I=Q, то менять местами не надо					
                end else begin
                    diff_I   <= $signed({1'b0, absI}) - idealI_8psk;
					diff_Q   <= $signed({1'b0, absQ}) - idealQ_8psk;
					square_I <= diff_I * diff_I;
					square_Q <= diff_Q * diff_Q;
					square_R <= square_I + square_Q;
                end
            end
        end
    end        
end

endmodule