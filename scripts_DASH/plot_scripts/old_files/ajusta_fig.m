% Abrir a figura existente
fig = openfig('taxa_comp_01.fig');

% Ajustar fontes dos eixos
axesHandles = findall(fig, 'Type', 'axes');
for ax = axesHandles'
    ax.FontSize = 12; % Fonte dos eixos
end

% Ajustar fonte da legenda
legendHandle = findall(fig, 'Type', 'legend');
for lgd = legendHandle'
    lgd.FontSize = 10; % Fonte da legenda
end

% Ajustar o tamanho da figura em centímetros
set(fig, 'Units', 'centimeters');
set(fig, 'Position', [5, 5, 12, 11]); % [x, y, largura, altura]

% Exportar a figura (opcional)
print(fig, 'figura_ajustada', '-dpng', '-r300'); % Exporta em alta resolução

% Salvar a figura ajustada, se quiser manter como .fig também
savefig(fig, 'figura_ajustada.fig');