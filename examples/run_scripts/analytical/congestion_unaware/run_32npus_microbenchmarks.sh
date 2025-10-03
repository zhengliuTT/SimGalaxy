#!/bin/bash
set -e

## ******************************************************************************
## This source code is licensed under the MIT license found in the
## LICENSE file in the root directory of this source tree.
##
## Copyright (c) 2024 Georgia Institute of Technology
## ******************************************************************************

# find the absolute path to this script
SCRIPT_DIR=$(dirname "$(realpath "$0")")
PROJECT_DIR="${SCRIPT_DIR:?}/../../../.."
EXAMPLE_DIR="${PROJECT_DIR:?}/examples"

# paths
ASTRA_SIM="${PROJECT_DIR:?}/build/astra_analytical/build/bin/AstraSim_Analytical_Congestion_Unaware"
SYSTEM="${EXAMPLE_DIR:?}/system/native_collectives/Ring_4chunks.json"
REMOTE_MEMORY="${EXAMPLE_DIR:?}/remote_memory/analytical/no_memory_expansion.json"

# Topologies to test
TOPOLOGIES=("Mesh" "Switch")
# Collectives to test
COLLECTIVES=("all_reduce" "all_gather" "all_to_all")

# start
echo "========================================"
echo "[ASTRA-sim] Running 32 NPUs Microbenchmarks"
echo "========================================"
echo ""

# Compile (if not already compiled)
echo "[ASTRA-sim] Ensuring ASTRA-sim is compiled..."
"${PROJECT_DIR:?}"/build/astra_analytical/build.sh -t congestion_unaware
echo ""

# Run simulations
for TOPOLOGY in "${TOPOLOGIES[@]}"; do
    NETWORK="${EXAMPLE_DIR:?}/network/analytical/${TOPOLOGY}_32npus.yml"
    
    for COLLECTIVE in "${COLLECTIVES[@]}"; do
        WORKLOAD="${EXAMPLE_DIR:?}/workload/microbenchmarks/${COLLECTIVE}/32npus_1MB/${COLLECTIVE}"
        
        echo "========================================"
        echo "[ASTRA-sim] Running: ${TOPOLOGY} - ${COLLECTIVE}"
        echo "========================================"
        echo ""
        
        # run ASTRA-sim
        "${ASTRA_SIM:?}" \
            --workload-configuration="${WORKLOAD}" \
            --system-configuration="${SYSTEM:?}" \
            --remote-memory-configuration="${REMOTE_MEMORY:?}" \
            --network-configuration="${NETWORK:?}"
        
        echo ""
        echo "[ASTRA-sim] Finished: ${TOPOLOGY} - ${COLLECTIVE}"
        echo ""
    done
done

# finalize
echo "========================================"
echo "[ASTRA-sim] All simulations completed!"
echo "========================================"


