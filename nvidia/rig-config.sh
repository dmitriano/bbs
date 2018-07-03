export DISPLAY=:0
nvidia-settings -a [gpu:0]/GPUPowerMizerMode=1
nvidia-settings -a [gpu:0]/GPUFanControlState=1
nvidia-settings -a [fan:0]/GPUTargetFanSpeed=90

