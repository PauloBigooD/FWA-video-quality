import pandas as pd

# Carregar o arquivo CSV (substitua 'captura.csv' pelo caminho do seu arquivo)
df = pd.read_csv('172.31.0.51_fwa.csv')

# Filtrar pacotes com Protocol = HTTP e Source = 172.31.0.51
http_source_packets = df[(df['Protocol'] == 'HTTP') & (df['Source'] == '172.31.0.51')]

# Exibir os pacotes filtrados
print(http_source_packets)

# Opcional: Salvar os pacotes filtrados em um novo arquivo CSV
http_source_packets.to_csv('172.31.0.51_filtrados.csv', index=False)
