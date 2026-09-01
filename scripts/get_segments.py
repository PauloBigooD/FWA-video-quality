import os
import subprocess

# Diretório onde estão os arquivos .har
diretorio = "."  # Altere para o caminho do seu diretório, se necessário
diretorio_saida = "segments_csv"

# Comando jq base
comando_jq = '''jq -r '.log.entries[] | select(.request.url | contains("http://172.31.0.51/video-dash/segment_bbb_sunflower")) | .request.url' {input_file} > {output_file}'''
comando_insert_column_name = '''sed -i '1i Request URI' {output_file}'''
comando_mv = '''mv *.csv segments_csv/'''
comando_rm = '''rm -rf downloaded_segments'''
comando_concat = '''python3 concat_filter_2.py segments_csv/{output_file}'''

# Listar todos os arquivos .har no diretório
for arquivo in os.listdir(diretorio):
    if arquivo.endswith(".har"):
        # Caminho completo do arquivo .har
        caminho_arquivo = os.path.join(diretorio, arquivo)
        # Nome do arquivo de saída .csv
        arquivo_saida = arquivo.replace(".har", ".csv")
        caminho_saida = os.path.join(diretorio, arquivo_saida)
        
        # Montar o comando completo
        comando1 = comando_jq.format(input_file=caminho_arquivo, output_file=caminho_saida)
        comando2 = comando_insert_column_name.format(output_file=caminho_saida)
        comando3 = comando_mv
        comando4 = comando_rm
        
        try:
            # Executar o comando
            subprocess.run(comando1, shell=True, check=True)
            subprocess.run(comando2, shell=True, check=True)
            subprocess.run(comando3, shell=True, check=True)
            subprocess.run(comando4, shell=True, check=True)
            #subprocess.run(comando5, shell=True, check=True)
            print(f"Processado: {arquivo} -> {arquivo_saida}")
        except subprocess.CalledProcessError as e:
            print(f"Erro ao processar {arquivo}: {e}")

print("Processamento concluído!")

for arquivo_2 in os.listdir(diretorio_saida):
    if arquivo_2.endswith(".csv"):
        saida_csv = arquivo_2
        comando5 = comando_concat.format(output_file=saida_csv)
        
        try:
            subprocess.run(comando4, shell=True, check=True)
            subprocess.run(comando5, shell=True, check=True)
            print(f"Concatenacao concluida")
        except subprocess.CalledProcessError as e:
            print(f"Erro ao concatenar videos")
