#!/bin/bash

# Defina o caminho do Node que você usa (verifique com `which node`)
export PATH=/home/paulobigood/.nvm/versions/node/v18.20.8/bin:$PATH

cd ~/fwa

# Chamar o Node direto no index.js
/home/paulobigood/.nvm/versions/node/v18.20.8/bin/node index.js >> ~/har_logs/cron.log 2>&1

