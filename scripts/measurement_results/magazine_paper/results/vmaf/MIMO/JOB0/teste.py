import re

nome = "64-QAM_MIMO_usr_1_job_0_vmaf.xml"
padrao = re.compile(r"(64|256)-QAM_(MIMO|SISO)_usr_([135])_job_\d+_vmaf\.xml", re.IGNORECASE)

match = padrao.match(nome)
if match:
    print("Match encontrado:", match.groups())
else:
    print("Não encontrou match")
