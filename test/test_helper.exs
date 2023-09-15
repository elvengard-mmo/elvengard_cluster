# start the current node as a manager
:ok = ElvenGard.Cluster.Testing.LocalCluster.start()

# run all tests!
ExUnit.start()
