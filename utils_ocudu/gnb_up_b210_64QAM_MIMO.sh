#!/bin/bash
echo Running gNB with gnb_b210_64QAM_MIMO configuration file

sudo ../build/apps/gnb/gnb -c gnb_conf_64QAM_SISO.yaml -c mimo_2x2.yml 
