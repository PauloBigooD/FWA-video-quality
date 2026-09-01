## Zabbix Server / Grafana

> ⚠️ É recomendado dedicar um Host ou uma Máquina Virtual para a instalação do Zabbix Server.

#### Alterne para o seguinte diretório:

```bash
cd zabbix/zabbix-server-docker
```

> Caso o Host não tenha o Docker instalado utilize o script `install-docker.sh` e realize a instalação.

### Iniciar Zabbix Server

```bash
sudo docker compose up -d
```

> Após executar o deployment do docker-compose as APIs do Zabbix e Grafana estarão disponíveis no IP local da Host. O acesso é feito a partir do navegador WEB.


`Zabbix: 192.168.170.78`

`Username: Admin`

`Password: zabbix`

<img src="https://raw.githubusercontent.com/PauloBigooD/O-RAN_Monitoring/refs/heads/main/figs/Zabbix_API.png">

---

`Grafana: 192.168.170.78:3000`

`Username: admin`

`Password: Grafana`

#### Dashboard Zabbix Server
<img src="https://raw.githubusercontent.com/PauloBigooD/O-RAN_Monitoring/refs/heads/main/figs/Dashboard_Zabbix-Server.png">

#### Dashboard E2 Node
<img src="https://raw.githubusercontent.com/PauloBigooD/O-RAN_Monitoring/refs/heads/main/figs/Dashboard.png">

