import os
import subprocess

# Diretório onde estão os arquivos .har
diretorio = "results-siso-13062025/"  # Altere para o caminho do seu diretório, se necessário
diretorio_saida = "segments_csv"
get_ssim = '''ffmpeg -i 4k.mp4 -i {input_file} -lavfi ssim="{output_file}" -f null - '''
get_psnr = '''ffmpeg -i 4k.mp4 -i {input_file} -lavfi psnr="{output_file}" -f null -'''

for job_dir in os.listdir(diretorio):
    print (job_dir)
    for arquivo in os.listdir(diretorio+"/"+job_dir):
    	print (arquivo)
    	caminho_arquivo = os.path.join(diretorio, job_dir, arquivo)
    	arquivo_entrada = arquivo
    	arquivo_saida_ssim = arquivo.replace(".mp4", "_ssim.csv")
    	arquivo_saida_psnr = arquivo.replace(".mp4", "_psnr.csv")
    	
    	comando1 = get_ssim.format(input_file=caminho_arquivo, output_file=arquivo_saida_ssim)
    	comando2 = get_psnr.format(input_file=caminho_arquivo, output_file=arquivo_saida_psnr)
    	try:
    	    #subprocess.run(comando1, shell=True, check=True)
    	    subprocess.run(comando2, shell=True, check=True)
    	except subprocess.CalledProcessError as e:
    	    print(f"Erro ao processar {arquivo}: {e}")
