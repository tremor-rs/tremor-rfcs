- Feature Name: Interceptors
- Start Date: 2020-11-03
- Tremor Issue: [tremor-rs/tremor-runtime#0000](https://github.com/tremor-rs/tremor-runtime/issues/0000)
- RFC PR: [tremor-rs/tremor-rfcs#0000](https://github.com/tremor-rs/tremor-rfcs/pull/0000)

# Summary
[summary]: #summary

Interceptors are part of sources/sinks/connectors. They statefully process byte sequences, possibly change their internal state and produce 0 to many output byte sequences. Interceptors are bidirectional, the operation they perform can thus be reversed. Interceptors form a serialization/deserialization chain from the wire where raw data is received to the dispatch point where an event is generated and in reverse.

# Motivation
[motivation]: #motivation

Currently sources can define a list of `preprocessors`, they take a `&[u8]` and produce a `Vec<Vec<u8>>`.
Sinks can define a list of `postprocessors`, they take a `&[u8]` and produce a `Vec<Vec<u8>>`.
When chained for each output `Vec<u8>` the next processor in the chain is called. In the source after preprocessors are done, each `Vec<u8>` is fed to a `Codec` that creates an `Value` from it. Before the `postprocessor` chain in a sink, a `Codec` creates an `Option<Vec<u8>>` from every event `Value`.

A `Codec` is stateless and bidirectional. All existing pre- and postprocessors define the same operation (e.g. split a given byte sequence into lines). Interceptors would join those dual operations into one entity.

It might be interesting at some point to not only allow a simple chain of interceptors, feeding bytes through them, but allow graphs with branching and joining, decisions where to continue based on investigation of the current chunk.

Also pre- and postprocessors currently are not configurable, so we have different lines processors, differing only in the delimiter. This is undesirable. Thus interceptors need to be configurable.

It is currently unclear how batched events are handled in sinks. Some treat each element of a batch as a single outbound unit (e.g. kafka sink where each element becomes its own message), some group batch elements in one outbound unit (e.g. elastic sink which builds up 1 request for a batch).

# Guide-level explanation
[guide-level-explanation]: #guide-level-explanation

Interceptors take a single byte sequence, and return zero or more byte sequences. They are stateful. So, they are able to split and join byte sequences.
They are used to handle bytes in two different directions:

* From the wire to the dispatch point, where each byte sequence is decoded and turned into an event
* From the dispatch point (from a pipeline) to the wire, where each byte sequence is put on the wire, be it into a TCP stream or as UDP packet or as HTTP request body.

Interceptors are intended for tasks like splitting an incoming byte-sequence into chunks at some delimiter, compression like gzip, lz4, snappy etc., encodings like base64, handle length-prefix framing and other framing types.

They are configured on sinks and sources as interceptor chains. One chain for each direction. 

The `in` chain is going from the wire, starting at the first element in the list, to the dispatch point, after the last element of the list. 

The `out` chain is going from the dispatch point, receiving data from the tremor-runtime, the pipeline, starting at the first element of the list, to the wire, after the last element of the `out` list.

Example configuration (with imaginmary interceptors):

```yaml
source:
  - id: ws-in
    type: ws
    interceptors:
      in:
        - type: gzip
          config:
            operation: decompress
        - type: split
          config:
            delimiter: '\n'
      out:
        - type: join
          config:
            delimiter: '\n'
            max_elements: 100
            max_wait_ms: 1000
        - type: gzip
          config:
            operation: compress
    codec:
      type: json
      config:
        pretty: true
        indent: "  "
    config:
      host: localhost
      port: 8888
```

This allows to define different interceptors for each direction. We do not differentiate between pre- and postprocessors anymore. Their API surface is the same. We could use a line splitter on incoming and outgoing data. There is nothing specific to the direction the data flows in the operation of the interceptor.

Tremor allows to batch events using either windows or the batch operator. How such batched events are handled on sinks is currently sink-specific and is not in scope of this RFC. Some sinks concatenate batched events and their resulting byte sequences after post-processing into a singler unit, a request or packet or similar entity, some treat each as single unit.

We should consolidate towards one canonical method of batching multiple events into a single outgoing unit (request, packet etc).
this method should be interceptor based. That means an imaginary `join` or `batch` interceptor should be added that takes over event batching into single outbound units.

# Reference-level explanation
[reference-level-explanation]: #reference-level-explanation

Preprocessors and Postprocessors will be deleted. Sinks and Sources will move to interceptors.
Most of the existing pre- and postprocessors will be moved to interceptors so that we do not lose functionality.

The `Interceptor` trait and exposed API is as follows:

```rust
trait Interceptor<S> {
  fn name(&self) -> &str;
  fn new_state(&self) -> Result<S>;

  /// static function with no reference to the interceptor instance for easier sharing
  fn intercept(data: &[u8], ingest_ns: u64, state: &mut S) -> Result<Vec<Vec<u8>>>;
}
```

The InterceptorChain will drive the interceptors creating their state, and feeding data through them.
For each new stream, a new chain of states will be created inside the InterceptorChain, thus it will react on stream lifecycle signals (scope of another PR).
This chain will be used to pick the correct state for processing bytes coming in on a certain stream.

# Drawbacks
[drawbacks]: #drawbacks

- It introduces a new concept, and thus is not only a breaking change but also requires learning new concept in order to understand how to make a usecase work in tremor.

# Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

- We want to both ease and streamline configuration of sinks and sources and make handling more consistent so it bears less bad surprises to users.

- In this RFC we do not make the codec part of the interceptor chain, although one might argue that it should be part of it.
  But then we would need to add some special validation to the last or first element of the list being special. This just introduces more complexity than is necessary.
  When it comes to defining interceptors as graphs it might be worth revisiting this decision.

# Prior art
[prior-art]: #prior-art

None.

# Unresolved questions
[unresolved-questions]: #unresolved-questions

None.

# Future possibilities
[future-possibilities]: #future-possibilities

Interceptors can be nicely created and shared in a future deployment language.

Also we could move from a simple chain to a graph, where users can decide which branch to proceed given some condition. It is crrently nmot defined / decided upon how and where this condition should be implemented.
