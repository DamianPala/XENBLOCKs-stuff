#!/bin/bash

# Configuration
gpus=7
power=280
fan_speed=90
max_gpu_clock=1875
declare -A gpuClockOffsets=( [0]=+30 [1]=+30 [2]=+30 [3]=+30 [4]=+30 [5]=+30 [6]=+30 )
declare -A memoryOffsets=( [0]=+100 [1]=+100 [2]=+100 [3]=+100 [4]=+100 [5]=+100 [6]=+100 )

# Functions
declare -A UUID_TO_SMI_ID
declare -A UUID_TO_SETTINGS_ID

function start_xserver() {
    # Check if the X server is already running on display :0
    if ! xdpyinfo -display :0 > /dev/null 2>&1; then
        echo "Starting the X server on display :0..."
        X :0 &
        X_PID=$!
        
        echo "Waiting for the X server to start..."
        for i in {1..10}; do
            if xdpyinfo -display :0 > /dev/null 2>&1; then
                echo "X server is up and running."
                break
            fi
            echo "Waiting for X server to start..."
            sleep 1
        done
        
        # Check if the X server failed to start after the loop
        if ! xdpyinfo -display :0 > /dev/null 2>&1; then
            echo "X server failed to start."
            kill $X_PID
            return 2
        fi
        
        echo "X server started successfully with PID $X_PID."
    else
        echo "X server is already up and running on display :0."
    fi
}

function populate_smi_lookup_table() {
    while IFS= read -r line; do
        local uuid=$(echo "$line" | awk -F', ' '{print $1}')
        local smi_id=$(echo "$line" | awk -F', ' '{print $2}')
        UUID_TO_SMI_ID["$uuid"]=$smi_id
    done < <(nvidia-smi --query-gpu=gpu_uuid,index --format=csv,noheader)
}

function populate_settings_lookup_table() {
    local uuid=""
    local gpu_id=""
    
    while IFS= read -r line; do
        if [[ "$line" =~ GPU-([0-9]+)$ ]]; then
            gpu_id=${BASH_REMATCH[1]}
        elif [[ "$line" =~ GPU-([0-9a-f\-]+) ]] && [[ "${#BASH_REMATCH[1]}" -gt 10 ]]; then
            uuid=${BASH_REMATCH[1]}
            if [[ -n "$gpu_id" && -n "$uuid" ]]; then
                UUID_TO_SETTINGS_ID["GPU-$uuid"]=$gpu_id
                uuid=""
                gpu_id=""
            fi
        fi
    done < <(nvidia-settings -q gpus)
}

# Function to get 'nvidia-settings' GPU ID from 'nvidia-smi' GPU ID
function get_settings_id_from_smi_id() {
    local smi_id=$1
    local target_uuid=""
    
    for uuid in "${!UUID_TO_SMI_ID[@]}"; do
        if [[ "${UUID_TO_SMI_ID[$uuid]}" == "$smi_id" ]]; then
            target_uuid=$uuid
            break
        fi
    done
    
    echo "${UUID_TO_SETTINGS_ID[$target_uuid]}"
}

# Main execution
export DISPLAY=:0

nvidia-xconfig --allow-empty-initial-configuration --enable-all-gpus --cool-bits=31

if [ $? -ne 0 ]; then
    echo "Failed to configure NVIDIA settings."
    exit 1
fi

start_xserver
populate_smi_lookup_table
populate_settings_lookup_table

nvidia-smi -pm 1

# Set power limit for each GPU
for ((gpu=0; gpu<gpus; gpu++)); do
    nvidia-smi -i $gpu -pl $power
done

# Set max core clock for each GPU
for ((gpu=0; gpu<gpus; gpu++)); do
    nvidia-smi -i $gpu -lgc 0,$max_gpu_clock
done

# Set power mizer mode, fan control state, and target fan speed for each GPU
for ((gpu=0; gpu<gpus; gpu++)); do
    fan1=$((gpu * 2))
    fan2=$((gpu * 2 + 1))
    
    nvidia-settings -a "[gpu:$gpu]/GpuPowerMizerMode=1"
    nvidia-settings -a "[gpu:$gpu]/GPUFanControlState=1" \
                    -a "[fan:$fan1]/GPUTargetFanSpeed=$fan_speed" \
                    -a "[fan:$fan2]/GPUTargetFanSpeed=$fan_speed"
done

for gpu in "${!gpuClockOffsets[@]}"; do
    gpu_settings=$(get_settings_id_from_smi_id $gpu)
    echo "Set clocks for smi id: ${gpu} settings id: ${gpu_settings}"
    nvidia-settings -a "[gpu:$gpu_settings]/GPUGraphicsClockOffsetAllPerformanceLevels=${gpuClockOffsets[$gpu]}"
    nvidia-settings -a "[gpu:$gpu_settings]/GPUMemoryTransferRateOffsetAllPerformanceLevels=${memoryOffsets[$gpu]}"
done
