# Start the current node as a manager
:ok = ElvenGard.Cluster.Testing.LocalCluster.start()

# Run all tests!
ExUnit.start()
