- Feature Name: ramp-interface
- Start Date: 2020-03-09
- Tremor Issue: [wayfair-tremor/tremor-runtime#0107](https://github.com/wayfair-tremor/tremor-runtime/issues/107) TBD
- RFC PR: [wayfair-tremor/tremor-rfcs#0018](https://github.com/wayfair-tremor/tremor-rfcs/pull/0018)

# Summary
[summary]: #summary


This RFC proposes a generalized interface for onramps(sources) and offramps(sinks). This interface can serve as a basis for the PDK as it unifies how tremor core addresses ramps. As a second benefit, it could serve as a de facto standard for sources and sinks in the broader rust event processing ecosystem.

# Motivation
[motivation]: #motivation

The [RFC 0006](https://rfcs.tremor.rs/0006-plugin-development-kit/) outlines the need and plan to implement a plugin development kit to allow decoupling parts of tremor to make development less centered around a single artefact.

To enable plugins, plugins of the same type need to share a standard interface over which they communicate with the outside world. As of today, ramps are the least standardized component in tremor where each ramp, in no small degree, "does its own thing." A standardized interface paves the way to implement ramps in the PDK.

The secondary motivation is that there is an emerging event processing ecosystem in the rust world, providing a standardized interface that helps with code reusability, quality, and sharing. For example, sharing code with timber.io's Vector project.

# Guide-level explanation
[guide-level-explanation]: #guide-level-explanation


We introduce a Sink and a Source trait. Those traits abstract over the following parts:

- configuration
- data handling
- status handling (errors, failures, backpressure for sinks)
- event handoff (either to or from the onramp)
- circuit breaker control/signals/events

These changes to interface trigger a redesign of the current codecs and pre/post processors as they would likely be outside of the scope of a sink or source.

The simplest possible trait for Sources that seems to be possible to wokr is:

```rust
pub(crate) enum SourceState {
    Connected,
    Disconnected,
}
pub(crate) enum SourceReply {
    Data(Vec<u8>),
    StateChange(SourceState),
}
pub(crate) trait Source {
    async fn read(&mut self) -> Result<SourceReply>;
    async fn init(&mut self) -> Result<SourceState>;
}
```

# Reference-level explanation
[reference-level-explanation]: #reference-level-explanation

TBD - this requires additional research spike in overlap in different interfaces to find a common denominator.

# Drawbacks
[drawbacks]: #drawbacks

Generalized sinks and sources are less specialized than custom-built ones. The chances are good that it complicates some of the implementations and can have a slight negative impact on performance.

# Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

- Why is this design the best in the space of possible designs?
- What other designs have been considered and what is the rationale for not choosing them?
- What is the impact of not doing this?

TBD - once the reference level explanation is provided and spike is done

Not generalizing ramps excludes them from the PDK.

# Prior art
[prior-art]: #prior-art

Generalized interfaces are a typical pattern. One example is the [ring](https://github.com/ring-clojure/ring), a common abstraction over web applications that allows the reuse of shared parts and logic. Other applications and domains use the same principle to create a more extensive ecosystem around a concept.

# Unresolved questions
[unresolved-questions]: #unresolved-questions

This RFC does not address linked on/offramps since they are a particular case.

# Future possibilities
[future-possibilities]: #future-possibilities

A further opportunity is to extend the concept of generalized ramps to linked on and offramps.
