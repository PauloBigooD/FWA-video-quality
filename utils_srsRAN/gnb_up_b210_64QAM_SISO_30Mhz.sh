#!/bin/bash
echo Running gNB with gnb_b210_64QAM_SISO_30Mhz configuration file

sudo ../srsRAN_Project/build/apps/gnb/gnb -c gnb_conf_64QAM_SISO_30Mhz.yaml  #-c qam256.yml -c mimo_2x2.yml
