#!/bin/bash
set -e
set -x

## ******************************************************************************
## This source code is licensed under the MIT license found in the
## LICENSE file in the root directory of this source tree.
##
## Copyright (c) 2024 Georgia Institute of Technology
## ******************************************************************************

# Example: NS3 simulation with 32 NPUs in 4x8 logical topology
# Using switch-based physical topology
# This corresponds to the analytical Mesh_32npus.yml configuration

SCRIPT_DIR=$(dirname "$(realpath $0)")
ASTRA_SIM_DIR="${SCRIPT_DIR:?}"/../../..
EXAMPLES_DIR="${ASTRA_SIM_DIR:?}"/examples
NS3_DIR="${ASTRA_SIM_DIR:?}"/extern/network_backend/ns-3

# Configurations
WORKLOAD="${EXAMPLES_DIR:?}"/workload/microbenchmarks/all_reduce/32npus_1MB/all_reduce
SYSTEM="${EXAMPLES_DIR:?}"/system/native_collectives/Ring_4chunks.json
NETWORK="${NS3_DIR:?}"/scratch/config/config_switch_32nodes.txt
LOGICAL_TOPOLOGY="${EXAMPLES_DIR:?}"/network/ns3/sample_32nodes_2D.json

MEMORY="${EXAMPLES_DIR:?}"/remote_memory/analytical/no_memory_expansion.json
COMM_GROUP_CONFIGURATION="empty"

# Navigate to NS3 build directory
cd "${NS3_DIR}/build/scratch"

echo "========================================"
echo "ASTRA-sim + NS3: 32 NPUs (4x8 Logical)"
echo "========================================"
echo "Workload: all_reduce (1MB, 32 NPUs)"
echo "Logical Topology: 4x8 (similar to Mesh_32npus.yml)"
echo "Physical Topology: Switch"
echo "System: Ring with 4 chunks"
echo "Bandwidth: 400 Gbps, Latency: 0.25 µs"
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

