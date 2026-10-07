#!/bin/bash

# Create directories for video processing
mkdir video video-dash

# Download the test video
cd video
pip3 install gdown
gdown 'https://drive.google.com/uc?id=1X9iPbrGkkO1EwN1hVC9Hgii6uENZUkCQ'
cd ..

# Install FFmpeg and GPAC (MP4Box)
sudo apt update
sudo apt install -y ffmpeg gpac
