# srsRAN Project Multi-Container Solution

This folder contains a multi-container application, composed of:

- Grafana (+ InfluxDB + srsRAN metrics server): a UI solution to monitor metrics from srsRAN gnb.

To launch the full multi-container solution, please run:

```bash
docker compose -f docker/docker-compose.yml up
```

or

```bash
cd docker/
docker compose up
```

- To force a new build of the containers (including a new build of srsRAN gnb), please add a `--build` flag at the end of the previous command.
- To run it in background, please add a `-d` flag at the end of the previous command.
- For more options, check `docker compose up --help`

To see services' output, you can run:

```bash
docker compose logs [OPTIONS] [SERVICE...]
```

- For more options, check `docker compose logs --help`

To stop it:

```bash
docker compose -f docker/docker-compose.yml down
```

- If you also want to remove all internal data except the setup, you can add `--volumes` flag at the end of the previous command.
- For more options, check `docker compose down --help`

If you're not familiarized with `docker compose` tool, it will be recommended to check its [website](https://docs.docker.com/compose/) and `docker compose --help` output.

## Enabling metrics reporting in the gnb

To be able to see gnb's metric in the UI solution (grafana + influxdb + metrics-server) it's required to enable metrics reporting in the gnb config.
For example:

```yml
metrics:
  enable_json_metrics: true
  addr: 172.19.1.4  # Metrics-server IP
  port: 55555       # Metrics-server Port
```

## Run some services

Instead of running all services provided, a partial run is allowed by doing:

```bash
docker compose -f docker/docker-compose.yml up <service_to_run>
```

Main options are:

- `gnb`: It will start the srsRAN Project gNB + Open5G core, without UI stack.
- `grafana`: It will start the full Grafana + InfluxDB + metrics-server stack, without srsRAN Project gnb and Open5g services.

However, any service declared in the docker-compose.yml can be started standalone, like `5gc` or `influxdb`.

## Customizations

- Default docker compose uses `configs/gnb_rf_b200_tdd_n78_20mhz.yml` config file. You can change it by setting the variable `${GNB_CONFIG_PATH}` in the shell, in the `docker compose up` command line or using the existing env-file `.env`. More info about how to do it in docker documentation here: <https://docs.docker.com/compose/environment-variables/set-environment-variables/>

- Network: If you are using an existing core-network on same machine, then you can comment the `5gc` service section and also link your srsran container to some existing AMF N2/N3 subnet, doing something like this:

```yml
  gnb: ...
    networks:
      network1:
          ipv4_address: 192.168.70.163 # Setting a fixed IP in the "network1" net

networks:
  network1:
    name: my-pre-existing-network
    external: true
```
