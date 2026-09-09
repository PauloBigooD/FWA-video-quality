#!/bin/bash
echo Running gNB with gnb_b210_256QAM_SISO_30Mhz configuration file

sudo ../ocudu/build/apps/gnb/gnb -c gnb_conf_256QAM_SISO_30Mhz.yaml  #-c qam256.yml -c mimo_2x2.yml
