#!/bin/bash
set -e
set -x

## ******************************************************************************
## This source code is licensed under the MIT license found in the
## LICENSE file in the root directory of this source tree.
##
## Copyright (c) 2024 Georgia Institute of Technology
## ******************************************************************************

# Example: NS3 simulation with 8 NPUs in Ring topology

SCRIPT_DIR=$(dirname "$(realpath $0)")
ASTRA_SIM_DIR="${SCRIPT_DIR:?}"/../../..
EXAMPLES_DIR="${ASTRA_SIM_DIR:?}"/examples
NS3_DIR="${ASTRA_SIM_DIR:?}"/extern/network_backend/ns-3

# Configurations
WORKLOAD="${EXAMPLES_DIR:?}"/workload/microbenchmarks/all_reduce/8npus_1MB/all_reduce
SYSTEM="${EXAMPLES_DIR:?}"/system/native_collectives/Ring_4chunks.json
NETWORK="${NS3_DIR:?}"/scratch/config/config_ring_8nodes.txt
LOGICAL_TOPOLOGY="${EXAMPLES_DIR:?}"/network/ns3/sample_8nodes_1D.json

MEMORY="${EXAMPLES_DIR:?}"/remote_memory/analytical/no_memory_expansion.json
COMM_GROUP_CONFIGURATION="empty"

# Navigate to NS3 build directory
cd "${NS3_DIR}/build/scratch"

echo "========================================"
echo "ASTRA-sim + NS3: Ring 8 NPUs"
echo "========================================"
echo "Workload: all_reduce (1MB, 8 NPUs)"
echo "Topology: Ring"
echo "System: Ring with 4 chunks"
echo "========================================"
echo ""

# Run NS3 simulation
./ns3.42-AstraSimNetwork-default \
    --workload-configuration=${WORKLOAD} \
    --system-configuration=${SYSTEM} \
    --network-configuration=${NETWORK} \
    --remote-memory-configuration=${MEMORY} \
    --logical-topology-configuration=${LOGICAL_TOPOLOGY} \
    --comm-group-configuration=${COMM_GROUP_CONFIGURATION}

echo ""
echo "========================================"
echo "Simulation completed!"
echo "========================================"

cd "${SCRIPT_DIR:?}"

