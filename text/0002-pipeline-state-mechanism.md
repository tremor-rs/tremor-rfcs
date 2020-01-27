- Feature Name: rfc_0002_pipeline_state_mechanism
- Start Date: 2020-01-22
- Issue: [wayfair-incubator/tremor-rfcs#0003](https://github.com/wayfair-incubator/tremor-rfcs/issues/3)
- RFC PR: [wayfair-incubator/tremor-rfcs#0004](https://github.com/wayfair-incubator/tremor-rfcs/pull/4)

# Summary
[summary]: #summary

Legacy tremor YAML configured tremor pipeline and Trickle query language pipelines
currently do not track state across events over time. A mechanism is required to
introduce state management and storage facilities to the tremor runtime and made
available to pipeline implementations.

# Motivation
[motivation]: #motivation

The absence of a state mechanism limits the usefulness and extent of algorithms that
can be implemented by tremor to those that are stateless, or those that leverage builtin
custom operators that maintain state such as the 'bucket' or 'batch' operators.

A state mechanism and supporting user-facing facilities would allow users to exploit
stateful algorithms for session tracking, building and maintaining application state
or for the query language to evolve support for in memory or persistent tables.

# Guide-level explanation
[guide-level-explanation]: #guide-level-explanation

The state mechanism in tremor pipelines allows user defined state management and
storage that persists for the running lifetime of a pipeline algorithm deployed
into the tremor runtime.

The state mechanism introduces the `state` keyword into the tremor scripting
language.

The state keyword introduces a special runtime-managed namespace that is protected for
mutation by the runtime and its facilities.

# Reference-level explanation
[reference-level-explanation]: #reference-level-explanation

To minimise observable changes to behaviour in tremor the `state` namespace
will be runtime managed.

A special sub-region will also be defined for user defined logic.

The `state` keyword and namespace are of record type. Sub regions supported in
the initial implementation are effectively record fields. In general fields
will be read-mostly, but some regions will be read-write depending on the
actor currently handling an event.

The runtime enforces read-only semantics as follows:


|Region|Runtime|Operator|UserDefinedLogic|
|---|---|---|---|
|`state.ops.{operator-id}`|ro|rw|-|
|`state.exports`|ro|ro|rw|


The `state` namespace will be initialialized on pipeline creation,
and will be destroyed on destruction of a pipline when it is undeployed or
the host process is shut down.

Effectively the `state` mechanism encapsulates the entire micro-state of
a pipeline and any captured user defined logic in a supported scripting
language or operator in a pipeline. This allows pipeline state to be recorded
in a snapshot to support advanced use cases such as pipeline migration through
coordinated passivation, serialization, migration, deserialization and re-activation
of a pipeline on a different tremor-runtime node without loss of state.

In the tremor scripting / query language the `state` keyword provides a reference
onto the user defined sub-region of the state record managed by the runtime. The
operator state is not visible to user-defined logic as this would render user-defined
logic to be brittle under refactoring.

In effect the `state` keyword references `state.exports` in the runtime managed
state. The entire state also includes operator state, however: the full state is
not visible to either operators ( who also see a restricited view ) or user defined
logic.

# Drawbacks
[drawbacks]: #drawbacks

Tremor-runtime is a working system and is currently stable.

By consolidating on a single namespace `state` we remain consistent with
other specialized keyword forms such as `args`, `group`, `window` that have
special meaning in tremor in different contexts/situations. This minimises
any introduces cognitive dissonance to the user but in a managed way.

# Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

In this RFC, the basic mechanism as outlined can be implemented and exposed
to the user facing region with minimal changes to the script / query language
required to support an implementation.

An alternative leveraging the metadata facility and usurping the `$state`
namespace would result in marginally less implementation effort, but risks
opening up other constraints to the metadata namespace. Such changes are
user-impacting and as such not desired.

# Prior art
[prior-art]: #prior-art

None.

# Unresolved questions
[unresolved-questions]: #unresolved-questions

This RFC does not specify internals or implementation of the state mechanism
as applies to operators. It is assumed that a `state` variable will be available
to signal, contraflow and event handlers by the runtime that are managed by the
runtime and partitioned by operator.

# Future possibilities
[future-possibilities]: #future-possibilities

This RFC normatively reserves the `state` keyword for pipeline state
management. The internal structure ( schema ) of the implied state record
is managed by this RFC. This RFC should be updated if the internal structure
( schema ) of the implied state record is further specified in the future.
