- Feature Name: connectors_and_streams
- Start Date: 2020-11-03
- Tremor Issue: [tremor-rs/tremor-runtime#0000](https://github.com/tremor-rs/tremor-runtime/issues/0000)
- RFC PR: [tremor-rs/tremor-rfcs#0000](https://github.com/tremor-rs/tremor-rfcs/pull/0000)

# Summary
[summary]: #summary

Replace onramps/offramps, sinks/sources with a new more general entity called `Connector`. Streams will become more visible throughout the whole engine via event ids, stream lifecycle events and Circuit Breaker events will become optionally stream based.

# Motivation
[motivation]: #motivation

Currently configuring linked transports is a bit cumbersome, as one needs to add a `linked: true` entry to any onramp or offramp config, that should be used as linked transport. Furthermore, code-wise, we basically implemented onramp logic in offramps, and vice-versa. This is undesirable. Furthermore in both sinks and linked onramps, we do handle events of all streams with the same postprocessors, that means that their state might interleave across events from different streams, wehereas we keep states separated per stream at the onramps. This is inconsistent.

We want find a good abstraction that exposes clear responsibilities and boundaries, that ressembles a clear and intuitive concept to the user, that simplifies our codebase for the linked transport cases and does not impose huge changes to the rest.

Many sources and sinks have a notion of streams, that is a logical separation of events, where speaking about an event order makes sense. E.g. a TCP connection can be considered a stream, as data on a connection has a natural order and it goes to a particular external system. An HTTP Session can be considered a stream, as it basically boils down to a TCP connection. A partition inside a kafka topic can be considered a stream. etc. etc. etc.

As each event originates from exactly 1 stream, and events coming from a source might be interleaved from multiple different streams and there is not necessarily an order to the events outside of their stream, as they can operate in parallel, each event need to carry the information the stream it originates from. Because for linked transports we need to have a way to route "response" events to the correct context (i.e. stream) their causing event originated from. This needs to be baked into the event id. We need to establish the notion that by design an always event originates from a stream within a connector/source and it belongs to that stream.

Currently the notion of stream is only visible inside the onramp/source management, not throughout the pipeline, not to any source and it is not exposed to the user creating pipelines. But whenever a stream is created or closed on a source, any sink connected to it via a pipeline can make good use of this information (e.g. pre-create an outgoing connection for handling this stream, allocating resources for deserialization, ...). 

# Guide-level explanation
[guide-level-explanation]: #guide-level-explanation

## Connectors

A connector maintains connections to the outside world, be it to another system to the filesystem, std-streams etc, through which events can enter and leave the tremor runtime. It maintains those connections and exposes them to the inside of tremor as streams and emit stream lifecycle events to tremor pipelines. A connector is responsible for deserialization and serialization from data on the wire to events and vice versa.

Connectors are artefacts as well as onramps, offramps and pipelines are. They are defined in yaml, instances are created upon binding/linking.

Onramps and offramps are going to be deprectated in favor of connectors. While an onramp or offramp only handles event flow in one direction, a connector is designed to handle inbound and outbound data flow. If a specific connector does not support one way of data flow, an error is raised when linking it in such a way, but before data is flowing.

Serialization and deserialization are defined by a `codec`, optionally a map of dynamically chosen codecs in a `codec_map` and a chain of [`interceptors`]() (TODO add link once the RFC is accepted).

Example connector config:

```yaml
connector:
  - id: my-ws-server
    type: ws-server
    config:
      host: 127.0.0.1
      port: 8888
    codec: json
    interceptors:
      in:
        - type: split
          config:
            delimiter: '\n'
      out:
        - type: join
          config:
            delimiter: '\n'
            max_elements: 1000
            max_wait_ms: 1000
```

Example connector binding:

```yaml
binding:
  id: example
  links:
    "tremor://connector/my-ws-server/{instance}/out": ["tremor://pipeline/system::passthrough/{instance}/in"]
    "tremor://pipeline/system::passthrough/{instance}/out": ["tremor://connector/my-ws-server/{instance}/in"]
    "tremor://pipeline/system::passthrough/{instance}/err": ["tremor://connector/my-ws-server/{instance}/in"]
```

The connector above is defining a websocket server to listen on `127.0.0.1:8888` and deserialize incoming data as 1 json document per line, and serialize outgoing data the same way, but with a batch size of either max `1000` lines per batch or with as much as has arrived within `1000ms`. It will create a stream for each websocket connection. The binding shows that it has an `in` and `out` port. On the `out` port events from a connection are flowing from the outside out of the connector towards the connected pipelines. On the `in` port events are flowing into the connector from the pipeline and towards the outside world (on a websocket connection in this case).

If a connector does not support being linked on the `in` port (or `out`), the deployment fails with an error message similar to `Unable to link to "tremor://connector/my-ws-server/01/in". Connector does not support linking to port "in". It can only act as event source.`

## Streams

Streams are going to become a first class citizen in the tremor event processing world. Every belongs originates not only from a connector, but from a stream, that is managed by a connector. A stream provides an ordered "stream" of events that might have a distinct endpoint compared to other streams which are part of the same source. It can represent a TCP connection, a partition of a kafka topic that we consume from, a file.

Event ids are comprised of:

* numerical connector id
* stream id within that connector
* event id within that stream (can be derived from a simple counter)

The last part, the event id, only needs to be unique within its stream. Events are only ordered in respect to their containing stream. There is no order to all events originating from a connector, only within streams.

The lifecycle of a connector receiving events is always:

```
                   server                           client
                     |                                 |
client connects ---> |                                 |
                     | ---------start stream---------> |
                     |                              connect ----> server
                     | <--------CB open stream-------- |
                     |                                 |
client event ------> | -----------event--------------> | ---------> server
                     |                                 |
                     | <----------ack/fail------------ |
client response <--- |                                 |
                     |                            disconnect <--- server
                     | <--------CB close stream------- |
```

* external connection is established
* `stream-created` lifecycle event is sent as signal to all pipelines connected to the `out` port
* `CB open stream` contraflow event is sent to all pipelines connected to the `in` port
* events are pulled from the connector
* ...
* external connection is closed
* `stream-closed` lifecycle event is sent as signal to all pipelines connected to the `out` port
* `CB close stream` contraflow event is sent to all pipelines connected to the `in` port

The `stream-started` signals make sure, that the whole pipeline and any downstream connector acting as sink are made aware of a new stream being created.

The connector documentation will contain entries on how each connector will react to a `stream-started` signal.

### Streams and Circuit Breakers

As events are now stream based, we need to introduce Circuit Breaker events that are scoped to a stream in addition to CB events scoped to the whole downstream, that is to all stream. When a source creates a stream, it sends a signal to its pipelines. This arrives at all attached connectors, where a stream might also be opened. It is the responsibility of the attached connector to now send a `CB Open stream` contraflow event back, so the source connector knows it may proceed sending events.

This increases complexity, but allows us to scope CB events to the entities that are actually affected, thus be more granular. If a TCP connection fails, it might still be possible to send events to other connections of that TCP connector. We do not necessarily need to stop sending everything.

Nonetheless Users can and should be able to configure that, we maybe want to stop sending further events to any stream of that connector that has 3 streams failing within 1 second. The possibilities for CB configurations are manyfold here. This should be exposed to users to sort out with regards to their use case via tremor-script, operators etc.

**CB Events**

* All Streams Open / All Streams Close
* Single Stream Open / Single Stream close
  * These events need to contain the stream id used at the connector where the stream originated.

Connectors might simply answer every `stream-started` signal immediately with a `CB Single Stream Open`, not keeping track of incoming streams. This connector will only be able to send out `All Streams Open` / `AllStreams Close` events. This is suitable if the connector by design only maintains a single stream.

Connectors might want to handle each stream explicitly (e.g. with a single outgoing TCP connection). In this case they need to track incoming stream identifiers in order to properly deliver stream `Single Stream Open/Close` event.

# Drawbacks
[drawbacks]: #drawbacks

- Introducing stream level circuit breaker events complicates things. Maybe we can get away without them, only adding stream lifecycle events?
- It might be less clear from the type alone, what a `connector` is capable of. `sources` and `sinks` make it perfectly clear what they do. But they fall short when it comes to linked transports.
- We might drastically increase the number of CB events and signals, thus potentially increasing load.

# Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives
### Rationale

- See [Motivation](#motivation).
- The current approach to setting up linked transports is not satisfying both on the levels of our codebase and the configuration surface we expose for that.
- We identified multiple issues with insufficient stream handling.

- The reason for pulling both concepts of `Connectors` and `Streams` into one RFC is that they originated from the same problem, that is solving our dissatisfaction with the current linked transport implementation. We need proper stream handling in order to route linked transport events properly and we need `Connectors` to abstract in a reasonable over the way we handle in- and out-bound events flow with the dawn of linked transports, both in terms of mental concepts exposed and in terms of a healthy and maintainable codebase.

### Alternatives
- We could maybe do without stream based CB events. And just send stream lifecycle signals.

# Prior art
[prior-art]: #prior-art

None that I know of.

# Unresolved questions
[unresolved-questions]: #unresolved-questions

### Multiple downstreams and CB stream events

Given a setup with 1 source connector, a simple passthrough pipeline and two connected sink connectors.

The source connector sends a `stream-created` event. It arrives at both sink connectors at possibly different times. Sink 1 responds first with a CB Single Stream Open, which arrives at the source, which starts issueing events on the pipeline. 

With Sink 2 not being ready, we might lose events on that end, if they are not enqueued.

# Future possibilities
[future-possibilities]: #future-possibilities

A deployment language (other than declarative yaml) would further remove friction from setting up linked transports and
would greatly improve on readbility and usability of linking.
