#!/bin/bash

#
# SPDX-License-Identifier: BSD-3-Clause
# Copyright(©) 2024 Intel Corporation
# Intel® Tiber™ Broadcast Suite
#

. VARIABLES.rc 2>/dev/null

# Check if VFIO_PORT_R is set
if [ -z "$VFIO_PORT_R" ]; then
    echo -e "\e[31mError: VFIO_PORT_R is not set.\e[0m"
    echo "Use dpdk-devbind.py -s to check pci address of vfio device"
    exit 1
fi

function help() {
    echo "Usage: $0 [-l]"
    echo
    echo "Options:"
    echo "  -l    Run the pipeline on bare metal locally."
    echo
    echo "For more information, please refer to docs/run.md."
    exit 0
}

while getopts "lh" opt; do
    case ${opt} in
        l )
            echo "Running pipeline on bare metal locally..."
            ffmpeg -y \
                -qsv_device /dev/dri/renderD128 -hwaccel qsv \
                -p_port "${VFIO_PORT_R}" -p_sip 192.168.2.2 -p_rx_ip 192.168.2.1 -udp_port 20000 -payload_type 112 -fps 25 -pix_fmt yuv422p10le \
                -video_size 3840x2160 -f mtl_st20p -i "0" \
                -filter_complex "[0:v]split=2[in1][in2];\
                    [in1]hwupload,scale_qsv=iw/2:ih/2[out1]; \
                    [in2]hwupload,scale_qsv=iw/4:ih/4[out2]" \
                -map "[out1]" -c:v hevc_qsv src/recv-quarter.mp4 \
                -map "[out2]" -c:v hevc_qsv src/recv-sixteenth.mp4
            exit 0
            ;;
        h )
            help
            ;;
        \? )
            echo "Invalid option: -$OPTARG" >&2
            help
            ;;
    esac
done

docker run -it \
   --user root\
   --privileged \
   --device=/dev/vfio:/dev/vfio \
   --device=/dev/dri:/dev/dri \
   --cap-add ALL \
   -v "$(pwd)":/videos \
   -v /usr/lib/x86_64-linux-gnu/dri:/usr/local/lib/x86_64-linux-gnu/dri/ \
   -v /tmp/kahawai_lcore.lock:/tmp/kahawai_lcore.lock \
   -v /dev/null:/dev/null \
   -v /tmp/hugepages:/tmp/hugepages \
   -v /hugepages:/hugepages \
   -v /var/run/imtl:/var/run/imtl \
   --network=my_net_801f0 \
   --ip=192.168.2.2 \
   --expose=20000-20170 \
   --ipc=host -v /dev/shm:/dev/shm \
      video_production_image -y \
      -qsv_device /dev/dri/renderD128 -hwaccel qsv \
      -p_port "${VFIO_PORT_R}" -p_sip 192.168.2.2 -p_rx_ip 192.168.2.1 -udp_port 20000 -payload_type 112 -fps 25 -pix_fmt yuv422p10le \
      -video_size 3840x2160 -f mtl_st20p -i "0" \
      -filter_complex "[0:v]split=2[in1][in2];\
          [in1]hwupload,scale_qsv=iw/2:ih/2[out1]; \
          [in2]hwupload,scale_qsv=iw/4:ih/4[out2]" \
      -map "[out1]" -c:v hevc_qsv /videos/recv-quarter.mp4 \
      -map "[out2]" -c:v hevc_qsv /videos/recv-sixteenth.mp4
