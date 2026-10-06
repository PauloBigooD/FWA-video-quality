function [q,s] = processa_ssim(nome_arq)

% Nome do arquivo de log gerado pelo FFmpeg
logFileName = nome_arq;

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

q=frames;
s=ssim_avg;