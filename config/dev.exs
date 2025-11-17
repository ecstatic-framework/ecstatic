import Config

# Development configuration
config :logger, level: :debug

# For local development, use epmd-based clustering
config :libcluster,
  topologies: [
    local: [
      strategy: Cluster.Strategy.Epmd,
      config: [
        hosts: []
      ]
    ]
  ]
