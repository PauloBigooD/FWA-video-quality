function [tempo_s, downlink_Mbps, uplink_Mbps] = lerTaxasFWA(filename)
    % Lê tempo, downlink e uplink de um CSV com formato Prometheus/FWA

    % Leitura preservando os nomes originais das colunas
    opts = detectImportOptions(filename, 'Delimiter', ',');
    opts.VariableNamingRule = 'preserve';
    tbl = readtable(filename, opts);

    % Exibir os nomes reais das colunas
    disp('Nomes das colunas:');
    disp(tbl.Properties.VariableNames);

    % Converte o tempo para datetime e depois para segundos desde o início
    tempo_dt = datetime(tbl.Time, 'InputFormat', 'yyyy-MM-dd HH:mm:ss');
    tempo_s = seconds(tempo_dt - tempo_dt(1));

    % Acessa as colunas reais de DL e UL
    % Pegando os nomes automaticamente a partir das posições (colunas 2 e 3)
    downlink_raw = tbl{:, 2};
    uplink_raw = tbl{:, 3};

    % Converte texto tipo '1.06 kb/s' ou '0 b/s' para Mbps
    downlink_Mbps = converterTaxaTexto(downlink_raw);
    uplink_Mbps = converterTaxaTexto(uplink_raw);

    % Plot opcional
    figure;
    plot(tempo_s, downlink_Mbps, 'b', tempo_s, uplink_Mbps, 'r');
    xlabel('Tempo (s)');
    ylabel('Taxa de Transmissão (Mbps)');
    legend('Downlink', 'Uplink');
    title('Taxas de Downlink e Uplink (FWA)');
    grid on;
end