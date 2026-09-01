#!/bin/bash
echo Running gNB with gnb_b210_256QAM_MIMO configuration file

sudo ../build/apps/gnb/gnb -c gnb_conf_256QAM_MIMO.yaml # -c qam256.yml -c mimo_2x2.yml
