% Nome do arquivo de log gerado pelo FFmpeg
logFileName = 'psnr_log.txt';

% Abrir o arquivo de log
fid = fopen(logFileName, 'r');

% Verificar se o arquivo foi aberto corretamente
if fid == -1
    error('Não foi possível abrir o arquivo de log.');
end

% Inicializar vetores para armazenar os números dos frames e os valores de PSNR
frames = [];
psnr_avg = [];

% Ler o arquivo linha por linha
tline = fgetl(fid);
while ischar(tline)
    % Procurar padrão 'n: <número>' e 'psnr_avg: <valor>'
    framePattern = 'n:\s*(\d+)';
    psnrPattern = 'psnr_avg:\s*([\d.]+)';
    
    % Tentar extrair os números dos frames e os valores de PSNR usando expressões regulares
    frameMatch = regexp(tline, framePattern, 'tokens');
    psnrMatch = regexp(tline, psnrPattern, 'tokens');
    
    % Se ambos os padrões forem encontrados, extrair os valores
    if ~isempty(frameMatch) && ~isempty(psnrMatch)
        frames = [frames, str2double(frameMatch{1}{1})];      % Adicionar frame ao vetor
        psnr_avg = [psnr_avg, str2double(psnrMatch{1}{1})];    % Adicionar PSNR ao vetor
    end
    
    % Ler a próxima linha
    tline = fgetl(fid);
end

% Fechar o arquivo após a leitura
fclose(fid);

% Exibir os resultados
% disp('Frames e PSNRs extraídos do log:');
% disp(table(frames', psnr_avg', 'VariableNames', {'Frame', 'PSNR_Avg'}));

% Nome do arquivo de log gerado pelo FFmpeg
logFileName = 'ssim_log.txt';

% Abrir o arquivo de log
fid = fopen(logFileName, 'r');

% Verificar se o arquivo foi aberto corretamente
if fid == -1
    error('Não foi possível abrir o arquivo de log.');
end

% Inicializar vetores para armazenar os números dos frames e os valores de PSNR
frames = [];
ssim_avg = [];

% Ler o arquivo linha por linha
tline = fgetl(fid);
while ischar(tline)
    % Procurar padrão 'n: <número>' e 'psnr_avg: <valor>'
    framePattern = 'n:\s*(\d+)';
    ssimPattern = 'Y:\s*([\d.]+)';
    
    % Tentar extrair os números dos frames e os valores de PSNR usando expressões regulares
    frameMatch = regexp(tline, framePattern, 'tokens');
    ssimMatch = regexp(tline, ssimPattern, 'tokens');
    
    % Se ambos os padrões forem encontrados, extrair os valores
    if ~isempty(frameMatch) && ~isempty(ssimMatch)
        frames = [frames, str2double(frameMatch{1}{1})];      % Adicionar frame ao vetor
        ssim_avg = [ssim_avg, str2double(ssimMatch{1}{1})];    % Adicionar PSNR ao vetor
    end
    
    % Ler a próxima linha
    tline = fgetl(fid);
end

% Fechar o arquivo após a leitura
fclose(fid);

% Exibir os resultados
% disp('Frames e PSNRs extraídos do log:');
% disp(table(frames', psnr_avg', 'VariableNames', {'Frame', 'PSNR_Avg'}));

doc = xmlread('vmaf_log.xml');

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


% figure(3)
% plot(ssim(:,1),ssim(:,2))
% grid
% axis([10 601,0.5 1.2])
% xlabel('Frames')
% ylabel('SSIM')

% figure(2)
% plot(d2(:,1),d2(:,6))
% grid
% axis([10 601,20 60])
% xlabel('Frames')
% ylabel('PSNR (dB)')
% 

yyaxis left
plot(frames,psnr_avg,'b'); hold on;
plot(frame_nums,vmaf_values,'r');
ylabel('Seno / Cosseno');

% Eixo Y à direita
yyaxis right
plot(frames,ssim_avg,'m');
