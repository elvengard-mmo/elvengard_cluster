## Setup

Mix.install([{:elvengard_cluster, path: Path.join(__DIR__, "../..")}])

## Code

nodes = [node()]
ElvenGard.Cluster.DistributedSupervisor.start_link(nodes: nodes)

Process.sleep(:infinity)
