function [q,v] = processa_vamf(nome_arq)

% Nome do arquivo de log gerado pelo FFmpeg

doc = xmlread(nome_arq);

% Obter todos os elementos <frame>
frames = doc.getElementsByTagName('frame');
numFrames = frames.getLength;

% Inicializar vetor para armazenar os números de frame
frame_nums = zeros(numFrames, 1);
vmaf_values = zeros(numFrames, 1);

% Percorrer cada frame e extrair o atributo vmaf
for i = 0:numFrames-1
    
    frame = frames.item(i);
    % Extrair o valor do atributo 'frameNum'
    frame_str = char(frame.getAttribute('frameNum'));
    % Converter para número
    frame_nums(i+1) = str2double(frame_str);    
    
    vmaf_str = char(frame.getAttribute('vmaf')); % pega o valor como string
    vmaf_values(i+1) = str2double(vmaf_str);     % converte para número
end

q = frame_nums;
v = vmaf_values;