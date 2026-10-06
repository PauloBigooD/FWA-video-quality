[q1,p1] = function processa_psnr(nome_arq)
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