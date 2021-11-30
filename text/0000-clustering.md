- Feature Name: clustering
- Start Date: 2020-12-16
- Tremor Issue: [tremor-rs/tremor-runtime#0000](https://github.com/tremor-rs/tremor-runtime/issues/0000)
- RFC PR: [tremor-rs/tremor-rfcs#0000](https://github.com/tremor-rs/tremor-rfcs/pull/0000)

# Summary
[summary]: #summary

TODO expand

Implement basic clustering for Tremor.

# Motivation
[motivation]: #motivation

TODO expand more

Add clustering to Tremor, so that it’s a true distributed system. This will add
resiliency for the pipelines deployed under Tremor, in terms of both host
failures as well as application logic (eg: correct distributed throttling for
logs/metrics even when some Tremor nodes go down). Moreover, it allows for
denser Tremor deployments with regards to the total host footprint (thus saving
more on hardware resources), and also eases the propagation/synchronization of
changes that need to touch all hosts, opening up nicer ways of doing tremor
pipeline deployments.

# Guide-level explanation
[guide-level-explanation]: #guide-level-explanation

Tremor can be operated on a clustered mode, which allows operators to use a
group of tremor nodes collaboratively for their event processing needs, giving
the illusion of a single running tremor instance to the outside world.

A tremor cluster is composed of two sets of nodes: `coordinators` and `workers`.

Coordinator nodes are the ones coordinating the addition and removal of nodes to
the cluster. They also intercept all changes to a running cluster (basically new
workload submissions, or changes to the tremor [repository and registry
state](https://docs.tremor.rs/operations/configuration/#introduction)) and
ensure that all nodes eventually apply the changes -- anytime the [tremor
api](https://docs.tremor.rs/api/) used to submit changes from a node, the
request is routed first to the coordinator node (if the node accepting the
request is not already a coordinator). Thus, the group of coordinator nodes can
be thought of as the brain of the cluster. For the initial clustering
implementation, the allowed number of dedicated coordinator nodes is 3.

If coordinators form the brain, worker nodes are the brawn of the cluster,
hosting the actual running instances of the deployed sources, pipelines and
sinks. Worker nodes accept changes from the coordinator nodes for this and
communicate directly to the cluster-external world as their workload demands
(i.e. as part of the sources/sinks running on the node). There is no set limit
on the number of worker nodes in the cluster, though it will be bound in
practicality by the network constraints of cluster-wide communication.

An example of starting a tremor server process in these two modes:

```sh
# assuming this command is run on host1 and the 3 coordinator nodes are on
# host1, host2, host3 (host1 can be left out here if desired)
tremor server run --coordinator --peers "host1:8139,host2:8139,host3:8139"

# assuming this command is run on host4 (all 3 coordinator nodes have to be specified)
tremor server run --worker --coordinators "host1:8139,host2:8139,host3:8139"
```

The static host list specified above is the current means of cluster discovery
(i.e. how a node finds the tremor cluster to join). The use of `--coordinator`
and `--worker` flag mandates the use of `--peers` and `--coordinators`
respectively -- the server will exit with an error during initialization if one
is used without the other. The default port for cluster communication is 8139
(if port is left-out as part of host details above, that’s the assumed port),
and can be overridden by a `--cluster-port` flag for both coordinators and
workers. Example:

```sh
# cluster-port flag is relevant only when coordinator or worker flag is specified
tremor server run --coordinator --peers "host1:8139,host2:8139,host3:8139" --cluster-port 4242
```

When started without these flags, the server process simulates the behavior of
tremor from its pre-clustering days (i.e. multiple tremor server instances in
this mode behave independently of each other). You can think of it as a [cluster
of one](https://www.youtube.com/watch?v=wW9RCrmOOkI) too, behaving as a
coordinator and worker both):

```sh
# party of one
tremor server run
```

Each worker node runs all the sources, sinks and pipelines deployed in the
cluster. Incoming event stream is distributed among the available worker nodes
for processing, after the initial interception from the running source (TODO
document various distribution strategies here -- round-robin and consistently
hashed to start with -- and how to specify this from Troy). This is made
possible by the way pipelines are hosted. A tremor cluster starts with a
pre-defined number of vnodes (or virtual nodes) that the coordinator nodes try
to distribute evenly among the available physical worker nodes. For a pipeline
in a given deployment mapping, instances are spawned off as part of each
vnode. Taking a typical source -> pipeline -> sink flow as an example, a
source instance running on the physical node will forward the events to
pipeline instances running on the vnodes, where the actual location of the
vnode may or not be the same physical node hosting the source instance
(depending on no of vnodes and their distribution among the available nodes),
and from the pipeline vnode, events end up in the sink instance hosted in the
same physical node where the vnode was. Thus, the unit of pipeline processing
in a tremor cluster is a vnode and the number of vnodes in the cluster
effectively determines the overall number of pipeline instances running at a
time for a given mapping (irrespective of how many worker nodes there are!).

The no of vnodes in the cluster can be set at tremor server startup time (TODO a
sane default to be determined. Can make this mandatory too). It’s best to size
the cluster so that vnode count is the same (or around the same) in all the
nodes (i.e. vnode count as a multiple of the total number of worker nodes). The
cluster will continue to work even if there are less vnodes than the actual
number of nodes -- it just means the extra worker nodes there won’t be involved
in the pipeline processing.

```sh
# if there are 16 worker nodes, each worker node here gets 4 vnodes
tremor server run --worker --coordinators "host1:8139,host2:8139,host3:8139" --no-of-vnodes 64
```

The cluster can handle a failure of 1 coordinator node (out of the set 3) and if
there’s less than 2 of those nodes available, the whole cluster is deemed
unavailable. If a worker node fails (or is removed consciously from the
cluster), its pipeline workload (i.e. the vnodes) is distributed among the
remaining nodes and once the node comes online again, it receives the workload
back. Adding new worker nodes triggers a similar rebalancing of the vnodes in
the cluster.

In principle, the cluster can handle failures of all worker nodes (if there’s no
worker node, the cluster is just on a stand-by mode, accepting the workload
submissions and waiting for a worker to be available), but in practice, the
actual functionality of the cluster will be limited by the total resources
available in the cluster and the kind of workloads running there before node
failures (and if your workload is such that only one worker is needed, you are
better-off using a stand-alone tremor node, without the division of worker vs
coordinator nodes).

# Reference-level explanation
[reference-level-explanation]: #reference-level-explanation

TODO expand

* microring of coordinator nodes using Raft for consensus and a KV store for
  cluster state
* macroring of worker nodes
* strongly consistent microring vs highly available macroring
* communication between coordinator and workers, and eventual consistency for
  worker nodes
* hinted handoffs during node failures
* testing focus

# Drawbacks
[drawbacks]: #drawbacks

TODO

* complexity and the curse of distributed systems (both for implementation as
  well as operation)
* difficulty of integrating with the current tremor featureset and semantics
* performance implications for current usecases

# Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

TODO

* paxos for consensus
* non-ring topologies

# Prior art
[prior-art]: #prior-art

TODO

(Old) prototype exploring our architecture:

* https://github.com/tremor-rs/uring

Inspirations:

* https://github.com/async-raft/async-raft
* https://github.com/tikv/raft-rs
* https://github.com/basho/riak_core
* https://www.allthingsdistributed.com/files/amazon-dynamo-sosp2007.pdf

# Unresolved questions
[unresolved-questions]: #unresolved-questions

TODO

* Troy overlap, especially for data distribution strategies to the pipeline vnodes
* Network protocol overlap

* Default for number of vnodes (or should we make it mandatory)
* Make number of coordinator nodes configurable (eg: 3, 5, 7) even in the initial clustering offering
* Introduce a configuration file to ease setting cluster details at startup (mode, peers/coordinators, port, vnode count)
* Add cluster name configuration
* Alternate terms for `coordinator` and `worker` nodes

# Future possibilities
[future-possibilities]: #future-possibilities

TODO

* Restrict deployments by node (as opposed to having everything available
  everywhere)
* Store repository only on the coordinator nodes
* Dynamic means of cluster discovery, without having to hardcode them everywhere
  (especially for workers which are the ones that will mostly see node changes)
* gdrl, load balancing and other smarter usecases
* Migratable sources/sinks
* Replication for pipelines
* Option for strong consistency in worker nodes
* Ability to specify other microrings (eg: for running source or sink specific
  logic)
