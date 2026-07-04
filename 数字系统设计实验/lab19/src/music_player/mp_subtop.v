`timescale 1ns / 1ps

//将 mcu, divider, 乐谱读取和音符播放器连接在一起
module music_player #(parameter sim = 0) (
    input  wire        clk,
    input  wire        reset,
    input  wire        play_pause,
    input  wire        next,
    input  wire        NewFrame,
    
    output wire [15:0] sample,
    output wire        play,
    output wire [1:0]  song
);

    // 内部连线
    wire beat;
    wire sampling_pulse;
    wire play_enable;
    wire reset_play;  
    wire note_done;
    wire new_note;
    wire [5:0] note;
    wire [5:0] duration;
    wire song_done;

    // 1. 同步采样脉冲
    syn u_syn (
        .clk (clk),
        .in  (NewFrame),
        .out (sampling_pulse)
    );

    // 2. 节拍发生器
    localparam DIV_N    = (sim == 1) ? 64 : 2000000;
    localparam DIV_BITS = (sim == 1) ? 6  : 21;  

    divider #(
        .n(DIV_N),
        .counter_bits(DIV_BITS)
    ) u_divider (
        .clk     (clk),
        .reset   (reset),
        .clk_out (beat)
    );

    // 3. 主控状态机 mcu
    mcu u_mcu (
        .clk        (clk),
        .reset      (reset),
        .play_pause (play_pause),
        .next       (next),
        .song_done  (song_done),
        .play       (play_enable),
        .song       (song),
        .reset_play (reset_play)
    );
    
    assign play = play_enable;

    // 4. 乐谱读取器
    song_reader u_song_reader (
        .clk       (clk),
        .reset     (reset_play), 
        .play      (play_enable),
        .song      (song),
        .note_done (note_done),
        .song_done (song_done),
        .note      (note),
        .duration  (duration),
        .new_note  (new_note)
    );

    // 5. 音符播放器
    note_player u_note_player (
        .clk              (clk),
        .reset            (reset_play), 
        .play_enable      (play_enable),
        .note_to_load     (note),
        .duration_to_load (duration),
        .load_new_note    (new_note),
        .beat             (beat),
        .sampling_pulse   (sampling_pulse),
        .note_done        (note_done),
        .sample           (sample),
        .sample_ready     ()          
    );

endmodule