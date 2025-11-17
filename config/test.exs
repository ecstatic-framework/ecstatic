import Config

# Test configuration
config :logger, level: :warn

# Disable automatic clustering in tests
config :libcluster, topologies: []
