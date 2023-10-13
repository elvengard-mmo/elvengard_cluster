## Setup

Mix.install([{:elvengard_cluster, path: Path.join(__DIR__, "../..")}])

## Code

opts = [
  nodes: [node()]
]

ElvenGard.Cluster.DistributedSupervisor.start_link(opts)

Process.sleep(:infinity)
