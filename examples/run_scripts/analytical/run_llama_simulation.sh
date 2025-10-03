#!/bin/bash
# ******************************************************************************
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.
#
# Run LLAMA Model Simulation on ASTRA-sim
# ******************************************************************************

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  ASTRA-sim LLAMA Simulation Runner${NC}"
echo -e "${BLUE}========================================${NC}"

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/../../.."
BINARY="${ROOT_DIR}/build/astra_analytical/build/AnalyticalAstra/bin/AstraSimAnalytical"
WORKLOAD_GEN="${ROOT_DIR}/examples/workload/llama/generate_llama_workload.py"

# Default parameters (can be overridden via command line)
MODEL_SIZE="${MODEL_SIZE:-7B}"
NPUS="${NPUS:-32}"
BATCH_SIZE="${BATCH_SIZE:-1}"
SEQ_LEN="${SEQ_LEN:-2048}"
TP_SIZE="${TP_SIZE:-1}"
DP_SIZE="${DP_SIZE:-32}"
TOPOLOGY="${TOPOLOGY:-Switch}"  # Switch, Ring, Mesh

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --model-size)
            MODEL_SIZE="$2"
            shift 2
            ;;
        --npus)
            NPUS="$2"
            shift 2
            ;;
        --batch-size)
            BATCH_SIZE="$2"
            shift 2
            ;;
        --seq-len)
            SEQ_LEN="$2"
            shift 2
            ;;
        --tp-size)
            TP_SIZE="$2"
            shift 2
            ;;
        --dp-size)
            DP_SIZE="$2"
            shift 2
            ;;
        --topology)
            TOPOLOGY="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --model-size    LLAMA model size: 7B, 13B, 70B (default: 7B)"
            echo "  --npus          Number of NPUs (default: 32)"
            echo "  --batch-size    Batch size per GPU (default: 1)"
            echo "  --seq-len       Sequence length (default: 2048)"
            echo "  --tp-size       Tensor parallelism size (default: 1)"
            echo "  --dp-size       Data parallelism size (default: 32)"
            echo "  --topology      Network topology: Switch, Ring, Mesh (default: Switch)"
            echo "  --help, -h      Show this help message"
            echo ""
            echo "Example:"
            echo "  $0 --model-size 7B --npus 32 --tp-size 4 --dp-size 8 --topology Switch"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Validate configuration
if [[ ! "$MODEL_SIZE" =~ ^(7B|13B|70B)$ ]]; then
    echo -e "${YELLOW}Error: Invalid model size. Must be 7B, 13B, or 70B${NC}"
    exit 1
fi

EXPECTED_NPUS=$((TP_SIZE * DP_SIZE))
if [ $NPUS -ne $EXPECTED_NPUS ]; then
    echo -e "${YELLOW}Warning: NPUS ($NPUS) != TP_SIZE ($TP_SIZE) * DP_SIZE ($DP_SIZE) = $EXPECTED_NPUS${NC}"
    echo -e "${YELLOW}Auto-adjusting DP_SIZE to match...${NC}"
    DP_SIZE=$((NPUS / TP_SIZE))
    echo -e "${GREEN}New DP_SIZE: $DP_SIZE${NC}"
fi

# Print configuration
echo ""
echo -e "${GREEN}Configuration:${NC}"
echo "  Model Size:          LLAMA-${MODEL_SIZE}"
echo "  NPUs:                ${NPUS}"
echo "  Batch Size:          ${BATCH_SIZE}"
echo "  Sequence Length:     ${SEQ_LEN}"
echo "  Tensor Parallelism:  ${TP_SIZE}"
echo "  Data Parallelism:    ${DP_SIZE}"
echo "  Network Topology:    ${TOPOLOGY}"
echo ""

# Step 1: Check if binary exists
if [ ! -f "$BINARY" ]; then
    echo -e "${YELLOW}ASTRA-sim binary not found. Building...${NC}"
    cd "${ROOT_DIR}/build/astra_analytical"
    ./build.sh -c
    cd -
fi

# Step 2: Generate workload
echo -e "${BLUE}Step 1/3: Generating LLAMA workload...${NC}"
WORKLOAD_NAME="llama_${MODEL_SIZE}_tp${TP_SIZE}_dp${DP_SIZE}_bs${BATCH_SIZE}_seq${SEQ_LEN}"
WORKLOAD_PATH="${ROOT_DIR}/examples/workload/llama/${WORKLOAD_NAME}"

if [ -d "$WORKLOAD_PATH" ]; then
    echo -e "${YELLOW}Workload already exists. Skipping generation.${NC}"
    echo -e "${YELLOW}To regenerate, delete: ${WORKLOAD_PATH}${NC}"
else
    python3 "$WORKLOAD_GEN" \
        --model-size "$MODEL_SIZE" \
        --npus-count "$NPUS" \
        --batch-size "$BATCH_SIZE" \
        --seq-len "$SEQ_LEN" \
        --tp-size "$TP_SIZE" \
        --dp-size "$DP_SIZE" \
        --output-path "${ROOT_DIR}/examples/workload/llama/"
fi

# Step 3: Select network configuration
echo ""
echo -e "${BLUE}Step 2/3: Selecting network configuration...${NC}"

case $TOPOLOGY in
    Switch)
        if [ $NPUS -eq 8 ]; then
            NETWORK_CFG="${ROOT_DIR}/examples/network/analytical/Switch_8npus.yml"
        elif [ $NPUS -eq 32 ]; then
            NETWORK_CFG="${ROOT_DIR}/examples/network/analytical/Switch_32npus.yml"
        else
            echo -e "${YELLOW}Warning: No pre-configured switch topology for ${NPUS} NPUs${NC}"
            NETWORK_CFG="${ROOT_DIR}/examples/network/analytical/Switch_32npus.yml"
        fi
        ;;
    Ring)
        if [ $NPUS -eq 32 ]; then
            NETWORK_CFG="${ROOT_DIR}/examples/network/analytical/Ring_32npus.yml"
        else
            NETWORK_CFG="${ROOT_DIR}/examples/network/analytical/Ring_32npus.yml"
        fi
        ;;
    Mesh)
        NETWORK_CFG="${ROOT_DIR}/examples/network/analytical/Mesh_32npus.yml"
        ;;
    *)
        echo -e "${YELLOW}Unknown topology: ${TOPOLOGY}. Using Switch.${NC}"
        NETWORK_CFG="${ROOT_DIR}/examples/network/analytical/Switch_32npus.yml"
        ;;
esac

echo "  Network Config: ${NETWORK_CFG}"

# Step 4: Select system and comm group configurations
SYSTEM_CFG="${ROOT_DIR}/examples/system/native_collectives/sample_fully_connected_sys.json"
COMM_GROUP_CFG="${ROOT_DIR}/examples/comm_group/allreduce_all_gpus.json"
REMOTE_MEM_CFG="${ROOT_DIR}/examples/remote_memory/no_memory_expansion.json"

echo "  System Config:  ${SYSTEM_CFG}"
echo "  Comm Groups:    ${COMM_GROUP_CFG}"

# Step 5: Run simulation
echo ""
echo -e "${BLUE}Step 3/3: Running ASTRA-sim simulation...${NC}"
echo ""

# Create output directory
OUTPUT_DIR="${ROOT_DIR}/results/llama_${MODEL_SIZE}_${NPUS}npus_${TOPOLOGY}"
mkdir -p "$OUTPUT_DIR"

# Run the simulation
"$BINARY" \
    --workload-configuration="${WORKLOAD_PATH}/llama_${MODEL_SIZE}" \
    --system-configuration="$SYSTEM_CFG" \
    --network-configuration="$NETWORK_CFG" \
    --remote-memory-configuration="$REMOTE_MEM_CFG" \
    --comm-group-configuration="$COMM_GROUP_CFG" \
    --log-path="$OUTPUT_DIR" \
    | tee "${OUTPUT_DIR}/simulation.log"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Simulation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Results saved to: ${OUTPUT_DIR}"
echo ""
echo "Key output files:"
echo "  - simulation.log:   Full simulation output"
echo "  - *.csv:            Performance metrics"
echo ""
echo -e "${BLUE}To analyze results, check the log files in ${OUTPUT_DIR}${NC}"



