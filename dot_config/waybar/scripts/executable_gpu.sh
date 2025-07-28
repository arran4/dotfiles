#!/bin/sh
nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits |
  awk -F', *' '{printf "%s%% %s/%s MiB\n", $1, $2, $3}'
