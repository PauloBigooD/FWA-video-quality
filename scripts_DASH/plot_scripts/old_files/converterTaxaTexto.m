function taxa_Mbps = converterTaxaTexto(vet_texto)
    % Converte vetores como '1.06 kb/s' para Mbps
    n = numel(vet_texto);
    taxa_Mbps = zeros(n, 1);
    for i = 1:n
        txt = strtrim(vet_texto{i});
        if contains(txt, 'kb/s')
            valor = sscanf(txt, '%f');
            taxa_Mbps(i) = valor / 1000;  % kb/s → Mbps
        elseif contains(txt, 'Mb/s')
            valor = sscanf(txt, '%f');
            taxa_Mbps(i) = valor;  % já em Mbps
        elseif contains(txt, 'b/s')
            valor = sscanf(txt, '%f');
            taxa_Mbps(i) = valor / 1e6;  % b/s → Mbps
        else
            taxa_Mbps(i) = 0;
        end
    end
end