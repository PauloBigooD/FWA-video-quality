#!/bin/bash
echo Running gNB with gnb_b210_256QAM_MIMO_30Mhz configuration file

sudo ../srsRAN_Project/build/apps/gnb/gnb -c gnb_conf_256QAM_SISO_30Mhz_E2.yaml
