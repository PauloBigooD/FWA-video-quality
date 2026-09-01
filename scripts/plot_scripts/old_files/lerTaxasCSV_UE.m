function [tempo_s, downlink_Mbps, uplink_Mbps] = lerTaxasCSV_UE(filename)
    % Lê tempo, downlink e uplink de um CSV no formato Prometheus

    % Leitura da tabela
    opts = detectImportOptions(filename, 'Delimiter', ',');
    opts = setvartype(opts, {'Time'}, 'string');  % Garante leitura de tempo como string
    tbl = readtable(filename, opts);

    % Converte tempo para segundos desde o início
    tempo_str = tbl.Time;
    tempo_dt = datetime(tempo_str, 'InputFormat', 'yyyy-MM-dd HH:mm:ss');
    tempo_s = seconds(tempo_dt - tempo_dt(1));

    % Extrai e converte downlink
    dl_raw = tbl{:,2};
    downlink_Mbps = converterTaxa(dl_raw);

    % Extrai e converte uplink
    ul_raw = tbl{:,3};
    uplink_Mbps = converterTaxa(ul_raw);

    % Plot para visualização
    figure;
    plot(tempo_s, downlink_Mbps, 'b', tempo_s, uplink_Mbps, 'r');
    xlabel('Tempo (s)');
    ylabel('Taxa de Transmissão (Mbps)');
    legend('Downlink', 'Uplink');
    title('Taxas de Transmissão');
    grid on;
end

function taxa_Mbps = converterTaxa(vet_texto)
    % Converte texto como '1.06 kb/s', '0 b/s' para Mbps
    n = numel(vet_texto);
    taxa_Mbps = zeros(n, 1);
    for i = 1:n
        txt = strtrim(vet_texto{i});
        if contains(txt, 'kb/s')
            valor = sscanf(txt, '%f');
            taxa_Mbps(i) = valor / 1000;  % kb/s → Mbps
        elseif contains(txt, 'Mb/s')
            valor = sscanf(txt, '%f');
            taxa_Mbps(i) = valor;  % já está em Mbps
        elseif contains(txt, 'b/s')
            valor = sscanf(txt, '%f');
            taxa_Mbps(i) = valor / 1e6;  % b/s → Mbps
        else
            taxa_Mbps(i) = 0;
        end
    end
end