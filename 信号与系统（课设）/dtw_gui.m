function dtw_gui
% DTW_GUI 基于动态时间规整（DTW）的语音识别系统
% 识别短语：浙江大学、求是创新、信电学院、信号系统

%% 清理环境
clc; clear; close all;

%% 提前加载图片以确定窗口尺寸
imgDir = fullfile(fileparts(mfilename('fullpath')), 'images');
bg_img = imread(fullfile(imgDir, 'bottom.jpg'));
[img_h, img_w, ~] = size(bg_img);
window_width = 800;
output_y = 50;
window_height = img_h + 280;  % 为图片下调预留空间
window_height = max(window_height, 550);

%% 创建主界面
fig = figure('Name', '基于DTW的语音识别系统', ...
    'Position', [300, 300, window_width, window_height], ...
    'NumberTitle', 'off', 'MenuBar', 'none', 'Resize', 'off', ...
    'Color', [0.95,0.95,0.95], 'CloseRequestFcn', @closeFigure);

%% 初始化参数
fs = 16000;
phrases = {'浙江大学', '求是创新', '信电学院', '信号系统'};
cache_file = 'ref_cache.mat';
ref_dir = fullfile(pwd, 'ref_audio');
tmp_dir = fullfile(pwd, 'temp');
if ~exist(tmp_dir, 'dir'); mkdir(tmp_dir); end

%% 全局变量
is_recording = false;
recorder = [];
audio_data = [];
selected_file = '';
stop_requested = false;

%% 加载参考模板
[ref_data, ref_labels] = load_or_create_refs(ref_dir, phrases, cache_file, tmp_dir, fs);

%% 计算居中位置
center_x = (window_width - img_w) / 2;

%% UI控件
% 标题
uicontrol('Style', 'text', 'Position', [50, window_height-80, 700, 30], ...
    'String', '基于DTW的语音识别系统', 'FontSize',16, 'FontWeight','bold', ...
    'BackgroundColor',[0.95,0.95,0.95]);

% 按钮
uicontrol('Style', 'pushbutton', 'Position', [50, window_height-130, 120, 40], ...
    'String', '选择参考目录', 'FontSize',12, 'Callback', @(~,~) select_ref_dir_callback());

uicontrol('Style', 'pushbutton', 'Position', [700, window_height-130, 80, 40], ...
    'String', '清除缓存', 'FontSize', 10, ...
    'Callback', @(~,~) clear_cache_callback());

rec_btn = uicontrol('Style', 'pushbutton', 'Position', [200, window_height-130, 120, 40], ...
    'String', '开始录音', 'FontSize',12, 'Callback', @record_callback);

file_btn = uicontrol('Style', 'pushbutton', 'Position', [350, window_height-130, 120, 40], ...
    'String', '选择文件', 'FontSize',12, 'Callback', @file_callback);

% 文件路径文本
filepath_text = uicontrol('Style', 'text', 'Position', [50, window_height-170, 700, 20], ...
    'String', '当前文件: 无', 'FontSize',10, 'HorizontalAlignment', 'left', ...
    'BackgroundColor', [0.95,0.95,0.95]);

% 状态文本
result_text = uicontrol('Style', 'text', 'Position', [center_x, output_y+img_h+10, img_w, 40], ...
    'String', '98娘准备好啦', 'FontSize',12, 'BackgroundColor', [0.95,0.95,0.95]);

% 播放音频复选框
play_audio_checkbox = uicontrol('Style', 'checkbox', ...
    'String', '播放识别音频', ...
    'Position', [480, window_height-130, 120, 25], ...
    'BackgroundColor', [0.95,0.95,0.95], ...
    'Value', 0);

% 停止按钮
stop_btn = uicontrol('Style', 'pushbutton', 'Position', [610, window_height-130, 80, 40], ...
    'String', '停止', 'FontSize', 12, ...
    'Enable', 'off', ...
    'Callback', @stop_callback);

%% 输出区背景（半透明底图）
ax_result_bg = axes('Units', 'pixels', ...
    'Position', [center_x, output_y, img_w, img_h], ...
    'Parent', fig, 'XTick', [], 'YTick', [], 'Box', 'off');
set(ax_result_bg, 'YDir', 'reverse');
alpha_val = 0.5;
image('CData', bg_img, 'XData', [1 img_w], 'YData', [1 img_h], ...
    'Parent', ax_result_bg, 'AlphaData', alpha_val);
set(ax_result_bg, 'XLim', [1 img_w], 'YLim', [1 img_h]);

% 透明编辑框
output_box = uicontrol('Style', 'edit', ...
    'Position', [center_x, output_y, img_w, img_h], ...
    'String', '', 'FontSize', 16, ...
    'BackgroundColor', 'none', 'ForegroundColor', 'black', ...
    'Enable', 'inactive', 'Max', 2);

%% 加载左右两张图片
img98 = imread(fullfile(imgDir, '98.jpg'));
imgThinking = imread(fullfile(imgDir, 'cc98_thinking.jpg'));

% 图片尺寸
pic_w = 130;
pic_h = 130;

% 左右图片位置（向下偏移40像素，避免与输出框重叠）
pic_y_bottom = output_y + img_h - pic_h + 40;
pic_x_left = center_x - pic_w - 20;
pic_x_right = center_x + img_w + 20;

% 辅助函数：创建无任何坐标轴元素的 axes
    function ax = create_pic_axes(pos)
        ax = axes('Units', 'pixels', 'Position', pos, ...
            'Parent', fig, 'Visible', 'off', ...
            'XTick', [], 'YTick', [], 'XTickLabel', [], 'YTickLabel', [], ...
            'Box', 'off', 'Color', 'none', 'XColor', 'none', 'YColor', 'none', ...
            'TickLength', [0 0], 'TickDir', 'none');
        % 额外确保坐标轴完全关闭
        axis(ax, 'off');
        set(ax, 'Layer', 'top');  % 避免干扰其他控件
    end

ax_left = create_pic_axes([pic_x_left, pic_y_bottom, pic_w, pic_h]);
imshow(img98, 'Parent', ax_left);
% 再次强制关闭坐标轴（imshow 可能会重置部分属性）
axis(ax_left, 'off');
set(ax_left, 'XTick', [], 'YTick', [], 'Box', 'off', 'Color', 'none');

ax_right = create_pic_axes([pic_x_right, pic_y_bottom, pic_w, pic_h]);
imshow(imgThinking, 'Parent', ax_right);
axis(ax_right, 'off');
set(ax_right, 'XTick', [], 'YTick', [], 'Box', 'off', 'Color', 'none');

%% 辅助函数：控制图片显示（不再有 cherry）
    function set_recognition_status(step)
        switch step
            case 'start'   % 识别开始前，显示左右图片
                set(ax_left, 'Visible', 'on');
                set(ax_right, 'Visible', 'on');
                set(result_text, 'String', '98娘聆听中...');
            case 'reset'   % 重置时隐藏图片
                set(ax_left, 'Visible', 'off');
                set(ax_right, 'Visible', 'off');
                set(result_text, 'String', '98娘准备好啦');
            case 'success' % 识别成功后，保持显示（不改变图片）
                set(result_text, 'String', '98娘听清楚啦');
                % 图片保持可见，无需操作
        end
        drawnow;
    end

%% 清除缓存回调
    function clear_cache_callback()
        if exist(cache_file, 'file')
            delete(cache_file);
            set(result_text, 'String', '缓存已清除，下次启动将重新加载参考音频');
        else
            set(result_text, 'String', '缓存文件不存在');
        end
        drawnow;
    end

%% 图形关闭回调
    function closeFigure(~,~)
        if is_recording && ~isempty(recorder) && isrecording(recorder)
            stop(recorder);
        end
        delete(fig);
    end

%% 选择参考目录回调
    function select_ref_dir_callback()
        new_dir = uigetdir(pwd, '选择包含短语子文件夹的参考音频目录');
        if isequal(new_dir, 0); return; end
        ref_dir = new_dir;
        try
            [ref_data, ref_labels] = load_or_create_refs(ref_dir, phrases, cache_file, tmp_dir, fs);
            set(result_text, 'String', sprintf('已加载参考模板 (目录: %s)', ref_dir));
            set(output_box, 'String', '参考模板加载成功，可以开始识别。');
            set_recognition_status('reset');
        catch ME
            set(result_text, 'String', ['参考模板加载失败: ' ME.message]);
            set(output_box, 'String', getReport(ME, 'extended', 'hyperlinks', 'off'));
        end
    end

    function stop_callback(~,~)
        stop_requested = true;
        set(result_text, 'String', '正在停止...');
        drawnow;
    end

%% 录音回调
    function record_callback(~,~)
        if ~is_recording
            is_recording = true;
            set(rec_btn, 'String', '停止录音');
            set(result_text, 'String', '录音中...');
            drawnow;
            try
                recorder = audiorecorder(fs, 16, 1);
                record(recorder);
            catch ME
                is_recording = false;
                set(rec_btn, 'String', '开始录音');
                set(result_text, 'String', ['录音启动失败: ' ME.message]);
                set(output_box, 'String', '请检查麦克风连接或权限设置。');
                return;
            end
        else
            is_recording = false;
            set(rec_btn, 'String', '开始录音');
            set(result_text, 'String', '处理中...');
            stop_requested = false;
            set(stop_btn, 'Enable', 'on');
            drawnow;

            if exist('recorder', 'var') && ~isempty(recorder) && isrecording(recorder)
                try; stop(recorder); catch; end
            end
            if ~exist('recorder', 'var') || isempty(recorder)
                set(result_text, 'String', '录音设备未初始化，请重试');
                set(output_box, 'String', '未找到录音对象，请重新开始录音。');
                set(stop_btn, 'Enable', 'off');
                return;
            end
            try
                audio_data = getaudiodata(recorder);
            catch ME
                set(result_text, 'String', ['获取音频数据失败: ' ME.message]);
                set(output_box, 'String', '录音设备可能已断开，请重新尝试。');
                set(stop_btn, 'Enable', 'off');
                return;
            end
            if isempty(audio_data) || length(audio_data) < fs * 0.5
                set(result_text, 'String', '录音时间太短或无效，请重新录音');
                set(output_box, 'String', sprintf('录音时长不足0.5秒（实际 %.2f 秒），无法识别。', length(audio_data)/fs));
                set(stop_btn, 'Enable', 'off');
                return;
            end

            temp_file = fullfile(tmp_dir, 'temp_recording.wav');
            try; audiowrite(temp_file, audio_data, fs); catch; end
            cleanup = onCleanup(@() delete_temp_file(temp_file));

            set_recognition_status('start');  % 显示左右图片

			% 计算音频的 RMS（注意音频可能已经过 RMS 归一化，但为了安全重新计算）
			rms_val = sqrt(mean(audio_data.^2));
			if rms_val < 0.005   
				set(result_text, 'String', '未检测到有效语音（音量过低或无声）');
				set(output_box, 'String', '请提高音量或确保麦克风正常工作。');
				return;
			end

            try
                [recognized_phrase, raw_dists, mapped_dists, probs] = recognize_speech(audio_data, fs, ref_data, ref_labels, phrases);
                display_result(recognized_phrase, raw_dists, mapped_dists, probs, phrases, output_box);
                if get(play_audio_checkbox, 'Value') == 1
                    sound(audio_data, fs);
                end
                [max_prob, ~] = max(probs);
                set(result_text, 'String', sprintf('识别完成: %s (置信度: %.2f%%)', recognized_phrase, max_prob*100));
                set_recognition_status('success');  % 只改文字，图片保持
            catch ME
                if strcmp(ME.message, '用户中断了识别')
                    set(result_text, 'String', '识别已取消');
                    set(output_box, 'String', '用户手动停止了计算。');
                    set_recognition_status('reset');
                else
                    set(result_text, 'String', ['识别错误: ' ME.message]);
                    set(output_box, 'String', getReport(ME, 'extended', 'hyperlinks', 'off'));
                end
            end
            set(stop_btn, 'Enable', 'off');
            stop_requested = false;
        end
    end

    function delete_temp_file(filepath)
        if exist(filepath, 'file'); delete(filepath); end
    end

%% 文件选择回调
    function file_callback(~,~)
        try
            [file_name, file_path] = uigetfile( ...
                {'*.wav;*.m4a;*.flac;*.mp3', '所有音频文件 (*.wav,*.m4a,*.flac,*.mp3)'; ...
                 '*.wav', 'WAV 文件 (*.wav)'; ...
                 '*.m4a', 'M4A 文件 (*.m4a)'; ...
                 '*.flac', 'FLAC 文件 (*.flac)'; ...
                 '*.mp3', 'MP3 文件 (*.mp3)'}, ...
                '选择测试音频');
            if isequal(file_name,0) || isequal(file_path,0)
                set(result_text, 'String', '未选择文件');
                set(filepath_text, 'String', '当前文件: 无');
                return;
            end
            selected_file = fullfile(file_path, file_name);
            set(filepath_text, 'String', ['当前文件: ' selected_file]);
            set(result_text, 'String', '正在处理文件...');
            drawnow;

            set_recognition_status('reset');  % 隐藏图片

            need_delete = false;
            temp_wav_file = '';
            [~,~,ext] = fileparts(selected_file);
            if strcmpi(ext, '.m4a') || strcmpi(ext, '.mp3') || strcmpi(ext, '.flac')
                temp_wav_file = fullfile(tmp_dir, 'temp_audio.wav');
                convert_to_wav(selected_file, temp_wav_file, fs);
                selected_file = temp_wav_file;
                need_delete = true;
            end

            [audio_tmp, fs_read] = audioread(selected_file);
            if fs_read ~= fs; audio_tmp = resample(audio_tmp, fs, fs_read); end
            if size(audio_tmp,2) > 1; audio_tmp = mean(audio_tmp,2); end
            audio_data = audio_tmp;
            if length(audio_data) < fs * 0.3
                set(result_text, 'String', '音频文件过短（<0.3秒），无法识别');
                if need_delete; delete_temp_file(temp_wav_file); end
                return;
            end
            if need_delete; cleanup = onCleanup(@() delete_temp_file(temp_wav_file)); end

            stop_requested = false;
            set(stop_btn, 'Enable', 'on');
            drawnow;

            set_recognition_status('start');  % 显示图片

			% 计算音频的 RMS（注意音频可能已经过 RMS 归一化，但为了安全重新计算）
			rms_val = sqrt(mean(audio_data.^2));
			if rms_val < 0.005			
				set(result_text, 'String', '未检测到有效语音（音量过低或无声）');
				set(output_box, 'String', '请提高音量或确保麦克风正常工作。');
				return;
			end

            [recognized_phrase, raw_dists, mapped_dists, probs] = recognize_speech(audio_data, fs, ref_data, ref_labels, phrases);
            display_result(recognized_phrase, raw_dists, mapped_dists, probs, phrases, output_box);
            if get(play_audio_checkbox, 'Value') == 1; sound(audio_data, fs); end
            set_recognition_status('success');  % 只改文字
            set(stop_btn, 'Enable', 'off');
        catch ME
            if strcmp(ME.message, '用户中断了识别')
                set(result_text, 'String', '识别已取消');
                set(output_box, 'String', '用户手动停止了计算。');
                set_recognition_status('reset');
            else
                set(result_text, 'String', ['错误: ' ME.message]);
                set(output_box, 'String', getReport(ME, 'extended', 'hyperlinks', 'off'));
            end
            if exist('temp_wav_file', 'var') && exist(temp_wav_file, 'file'); delete(temp_wav_file); end
            set(stop_btn, 'Enable', 'off');
        end
    end

%% 核心识别函数
    function [recognized_phrase, raw_dists, mapped_dists, probs] = recognize_speech(audio, fs, ref_data, ref_labels, phrases)
        audio = remove_silence(audio, fs);
        if isempty(audio)
            error('静音切除后音频为空');
        end
        test_feat = extract_mfcc_features(audio, fs);
        n_phrases = length(phrases);
        raw_dists = zeros(n_phrases, 1);
        for i = 1:n_phrases
            these_refs_cell = ref_data(ref_labels == i);
            if stop_requested
                error('用户中断了识别');
            end
            if isempty(these_refs_cell)
                raw_dists(i) = inf;
                continue;
            end
            sum_norm_dist = 0;
            for k = 1:length(these_refs_cell)
                if stop_requested
                    error('用户中断了识别');
                end
                ref_feat = these_refs_cell{k};
                [dist, ix, iy] = dtw(test_feat', ref_feat');
                norm_dist = dist / length(ix);
                sum_norm_dist = sum_norm_dist + norm_dist;
            end
            raw_dists(i) = sum_norm_dist / length(these_refs_cell);
        end
        if all(isinf(raw_dists))
            error('所有短语的参考模板均为空，无法识别');
        end
        DIST_THRESH = 15;
        map_min = 1.0;
        map_max = 5.0;
        min_raw = min(raw_dists);
        max_raw = max(raw_dists);
        if max_raw > DIST_THRESH
            if max_raw == min_raw
                mapped_dists = ones(size(raw_dists)) * (map_min + map_max)/2;
            else
                mapped_dists = map_min + (raw_dists - min_raw) / (max_raw - min_raw) * (map_max - map_min);
            end
        else
            mapped_dists = raw_dists;
        end
        beta = 10.0;
        weights = exp(-beta * mapped_dists);
        probs = weights / sum(weights);
        [~, idx] = min(raw_dists);
        recognized_phrase = phrases{idx};
    end

%% 显示结果
    function display_result(recognized_phrase, raw_dists, mapped_dists, probs, phrases, output_box)
        str = sprintf('识别结果: %s\n', recognized_phrase);
        str = [str, sprintf('---------------------------------\n')];
        if max(raw_dists) > 15
            title_str = '映射DTW距离';
            show_dists = mapped_dists;
        else
            title_str = '平均DTW距离';
            show_dists = raw_dists;
        end
        str = [str, sprintf('短语              %s       概率\n', title_str)];
        for i = 1:length(phrases)
            if isinf(raw_dists(i))
                dist_str = '     无模板';
            else
                dist_str = sprintf('%10.2f', show_dists(i));
            end
            str = [str, sprintf('%-12s    %12s    %6.2f%%\n', ...
                   phrases{i}, dist_str, probs(i)*100)];
        end
        set(output_box, 'String', str);
    end

%% 完整算法函数
    function [ref_data, ref_labels] = load_or_create_refs(ref_dir, phrases, cache_file, tmp_dir, fs)
        dir_hash = compute_dir_hash(ref_dir, phrases);
        if exist(cache_file, 'file')
            try
                vars = load(cache_file, '-mat', 'ref_data', 'ref_labels', 'phrases_cached', 'fs_cached', 'dir_hash_cached');
                if isequal(vars.phrases_cached, phrases) && vars.fs_cached == fs && ...
                   isfield(vars, 'dir_hash_cached') && isequal(vars.dir_hash_cached, dir_hash)
                    ref_data = vars.ref_data;
                    ref_labels = vars.ref_labels;
                    fprintf('从缓存加载参考模板 (%s)\n', cache_file);
                    return;
                end
            catch
            end
        end
        fprintf('生成参考模板...\n');
        ref_data = {};
        ref_labels = [];
        for i = 1:length(phrases)
            phr = phrases{i};
            phr_dir = fullfile(ref_dir, phr);
            if ~exist(phr_dir, 'dir')
                error('目录不存在: %s', phr_dir);
            end
            audio_files = [dir(fullfile(phr_dir, '*.wav')); dir(fullfile(phr_dir, '*.m4a')); ...
                           dir(fullfile(phr_dir, '*.flac')); dir(fullfile(phr_dir, '*.mp3'))];
            if isempty(audio_files)
                error('在 %s 中未找到任何音频文件', phr_dir);
            end
            for j = 1:length(audio_files)
                file_path = fullfile(phr_dir, audio_files(j).name);
                [~,~,ext] = fileparts(file_path);
                if ~strcmpi(ext, '.wav')
                    wav_tmp = fullfile(tmp_dir, sprintf('ref_%s_%d.wav', phr, j));
                    convert_to_wav(file_path, wav_tmp, fs);
                    file_path = wav_tmp;
                end
                [audio, fs_read] = audioread(file_path);
                if fs_read ~= fs
                    audio = resample(audio, fs, fs_read);
                end
                if size(audio,2) > 1
                    audio = mean(audio,2);
                end
                audio = remove_silence(audio, fs);
                if isempty(audio)
                    warning('音频 %s 静音切除后为空，跳过', audio_files(j).name);
                    continue;
                end
                feat = extract_mfcc_features(audio, fs);
                ref_data{end+1} = feat;
                ref_labels(end+1) = i;
            end
        end
        phrases_cached = phrases;
        fs_cached = fs;
        dir_hash_cached = dir_hash;
        save(cache_file, 'ref_data', 'ref_labels', 'phrases_cached', 'fs_cached', 'dir_hash_cached', '-v7');
        fprintf('参考模板已保存至 %s\n', cache_file);
    end

    function dir_hash = compute_dir_hash(ref_dir, phrases)
        hash_str = '';
        for i = 1:length(phrases)
            phr_dir = fullfile(ref_dir, phrases{i});
            if ~exist(phr_dir, 'dir'); continue; end
            audio_files = [dir(fullfile(phr_dir, '*.wav')); dir(fullfile(phr_dir, '*.m4a')); ...
                           dir(fullfile(phr_dir, '*.flac')); dir(fullfile(phr_dir, '*.mp3'))];
            for j = 1:length(audio_files)
                hash_str = [hash_str, phrases{i}, audio_files(j).name, ...
                            num2str(audio_files(j).datenum), num2str(audio_files(j).bytes)];
            end
        end
        if isempty(hash_str)
            dir_hash = '';
        else
            dir_hash = java.lang.String(hash_str).hashCode();
        end
    end

    function convert_to_wav(input_path, output_path, target_fs)
        [audio, fs_orig] = audioread(input_path);
        if fs_orig ~= target_fs
            audio = resample(audio, target_fs, fs_orig);
        end
        if size(audio,2) > 1
            audio = mean(audio,2);
        end
        audiowrite(output_path, audio, target_fs);
    end

    function audio_out = remove_silence(audio, fs)
        frame_len = round(0.025 * fs);
        frame_shift = round(0.010 * fs);
        num_frames = floor((length(audio) - frame_len) / frame_shift) + 1;
        if num_frames < 1
            warning('remove_silence: 音频长度不足一帧 (%d 采样点)，保留原信号', length(audio));
            audio_out = audio;
            return;
        end
        frames = zeros(frame_len, num_frames);
        for i = 1:num_frames
            start_idx = (i-1)*frame_shift + 1;
            frames(:,i) = audio(start_idx:start_idx+frame_len-1);
        end
        energy = sum(frames.^2, 1);
        thresh = max(energy) * 0.03;
        if thresh < 1e-6
            thresh = max(energy) * 0.1;
        end
        voiced = find(energy > thresh);
        if isempty(voiced)
            audio_out = audio;
        else
            start_sample = max(1, (voiced(1)-1)*frame_shift + 1);
            end_sample = min(length(audio), (voiced(end)-1)*frame_shift + frame_len);
            audio_out = audio(start_sample:end_sample);
        end
    end

    function mfcc_feat = extract_mfcc_features(audio, fs)
        rms = sqrt(mean(audio.^2));
        if rms > 1e-6
            audio = audio * (0.1 / rms);
        end
        if exist('mfcc', 'file') == 2
            win_len = round(0.025 * fs);
            win = hamming(win_len);
            overlap_len = round(0.015 * fs);
            [coeffs, ~] = mfcc(audio, fs, 'NumCoeffs', 13, ...
                'Window', win, 'OverlapLength', overlap_len);
            mfcc_feat = coeffs;
        else
            frame_len = round(0.025*fs);
            frame_shift = round(0.010*fs);
            frames = frame_signal(audio, frame_len, frame_shift);
            frames = frames .* hamming(frame_len);
            nfft = 2^nextpow2(frame_len);
            mag = abs(fft(frames, nfft));
            pow_frames = (1/frame_len) * mag(1:nfft/2+1,:).^2;
            num_filters = 20;
            mel_filters = mel_filterbank(num_filters, nfft, fs);
            if size(mel_filters,2) ~= size(pow_frames,1)
                error('Mel滤波器维度不匹配: 滤波器列数=%d，功率谱行数=%d', ...
                    size(mel_filters,2), size(pow_frames,1));
            end
            mel_energy = mel_filters * pow_frames;
            mel_energy = max(mel_energy, eps);
            log_mel = log(mel_energy);
            mfcc_raw = dct(log_mel);
            mfcc_feat = mfcc_raw(1:13, :)';
        end
        mfcc_feat = mfcc_feat - mean(mfcc_feat, 1);
    end

    function frames = frame_signal(x, frame_len, frame_shift)
        N = length(x);
        num_frames = floor((N - frame_len) / frame_shift) + 1;
        if num_frames <= 0
            frames = [];
            return;
        end
        frames = zeros(frame_len, num_frames);
        for i = 1:num_frames
            start_idx = (i-1)*frame_shift + 1;
            frames(:,i) = x(start_idx:start_idx+frame_len-1);
        end
    end

    function filters = mel_filterbank(num_filters, nfft, fs)
        fft_len = nfft;
        mel_min = 0;
        mel_max = 2595 * log10(1 + (fs/2)/700);
        mel_points = linspace(mel_min, mel_max, num_filters+2);
        hz_points = 700 * (10.^(mel_points/2595) - 1);
        bin_raw = round((fft_len+1) * hz_points / fs);
        bin = zeros(size(bin_raw));
        bin(1) = max(1, min(bin_raw(1), fft_len/2));
        for k = 2:length(bin_raw)
            bin(k) = max(bin(k-1)+1, min(bin_raw(k), fft_len/2));
        end
        if bin(end) > fft_len/2
            bin(end) = fft_len/2;
            for k = length(bin)-1:-1:1
                if bin(k) >= bin(k+1)
                    bin(k) = bin(k+1) - 1;
                    if bin(k) < 1
                        bin(k) = 1;
                    end
                end
            end
        end
        filters = zeros(num_filters, fft_len/2+1);
        for m = 1:num_filters
            left = bin(m);
            center = bin(m+1);
            right = bin(m+2);
            if left >= center || center >= right || right > fft_len/2+1
                continue;
            end
            filters(m, left+1:center+1) = linspace(0, 1, center-left+1);
            filters(m, center+1:right+1) = linspace(1, 0, right-center+1);
        end
    end

end