#!/bin/bash
# Test script for distributed ECS functionality
# Starts 3 nodes and runs the distributed game example

set -e

echo "🎮 Ecstatic Distributed ECS Test"
echo "================================"
echo ""
echo "This script will:"
echo "1. Start 3 Elixir nodes (node_a, node_b, node_c)"
echo "2. Connect them into a cluster"
echo "3. Run the distributed game example"
echo ""
echo "Press Ctrl+C in any terminal to stop"
echo ""

# Get hostname
HOSTNAME=$(hostname -s)

# Function to start a node
start_node() {
    local node_name=$1
    local color=$2

    echo "Starting $node_name..."

    # Start in new terminal if possible
    if command -v gnome-terminal &> /dev/null; then
        gnome-terminal -- bash -c "echo -e '$color'; iex --sname $node_name --cookie ecstatic_test -S mix; bash"
    elif command -v xterm &> /dev/null; then
        xterm -e "iex --sname $node_name --cookie ecstatic_test -S mix" &
    else
        echo "No terminal emulator found. Please run manually:"
        echo "  iex --sname $node_name --cookie ecstatic_test -S mix"
    fi
}

echo "📋 Manual Instructions:"
echo ""
echo "Terminal 1:"
echo "  iex --sname node_a --cookie ecstatic_test -S mix"
echo ""
echo "Terminal 2:"
echo "  iex --sname node_b --cookie ecstatic_test -S mix"
echo ""
echo "Terminal 3:"
echo "  iex --sname node_c --cookie ecstatic_test -S mix"
echo ""
echo "Then in node_a:"
echo "  Node.connect(:\"node_b@$HOSTNAME\")"
echo "  Node.connect(:\"node_c@$HOSTNAME\")"
echo "  DistributedGame.run(entities: 20, duration: 30000)"
echo ""
echo "Or use the helper:"
echo "  DistributedGame.connect_cluster()"
echo "  DistributedGame.run()"
echo ""
