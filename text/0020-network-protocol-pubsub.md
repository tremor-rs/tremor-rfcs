- Feature Name: rfc-0020-network-protocol-pubsub
- Start Date: 2021-01-15
- Tremor Issue: [tremor-rs/tremor-runtime#0174](https://github.com/tremor-rs/tremor-runtime/pull/174)
- RFC PR: [tremor-rs/tremor-rfcs#0021](https://github.com/tremor-rs/tremor-rfcs/pull/0021)

# Summary

[summary]: #summary

Tremor Messaging Protocol Specification - Publish/Subscribe Model

# Motivation

[motivation]: #motivation

Extends the tremor network protocol specification with publish/subscribe
message delivery semantics

Enables publishing data to tremor and subscribing to data from tremor
over the tremor network protocol.

# Guide-level explanation

[guide-level-explanation]: #guide-level-explanation

This specification normatively defines the `pubsub` protocol extension
of the tremor network protocol specification core.

A `pubsub` session can be established by the [connect] control plane
event message with an optional list of initial subscriptions to data
sources available to tremor.

Once subscribed, events received on subscriptions will be forwarded
to the `pubsub` session.

Subscriptions are tremor urls that encapsulate data sources. It SHOULD
be possible to subscribe to onramp or source connectors as well as the
default or named user defined output streams of tremor pipelines.

To publish data to pipeline inputs or directly to the inputs of data
sink or offramp connectors requires a subscription for publication.

This specification reserves the string literal `pubsub` as a valid built in
protocol type supported by implementations of the tremor network protocol
specification.

It is an error to attempt to register a protocol backend that
consumes the `pubsub` literal or that overrides the implementation provided
by tremor itself.

# Reference-level explanation

[reference-level-explanation]: #reference-level-explanation

This section describes how to `connect`, `subscribe` and `unsubscribe`
from data sources available within tremor over the tremor network protocol.

This section further describes the `list` utility function and the correct
behaviour upon a normal `close` operation on an established `pubsub` session.

The `pubsub` extension allows publish-subscribe message channels to
be established via control plane `connect` messages.

## Connect

A minimally correct instanciation is as follows:

```json
  { "tremor": 
    { "connect": 
      { "protocol": "pubsub",
      }
    }
  }
```

Connecting with an initial subscription that taps into a
source connector deployed within the connected tremor instance:

```json
  { "tremor": 
    { "connect": 
      { "protocol": "pubsub",
        "properties": {
          "subscriptions": [
            "/onramps/metronome/in"
          ]
        }
      }
    }
  }
```

Connecting with an initial subscription into a pipeline deployed
within the connected tremor instance:

```json
  { "tremor": 
    { "connect": 
      { "protocol": "pubsub",
        "properties": {
          "subscriptions": [
            "/pipeline/passthrough/out"
          ]
        }
      }
    }
  }
```

Connecting with an initial subscription for publication that
taps into a sink or offramp connector deployed within the connected
tremor instance:

```json
  { "tremor": 
    { "connect": 
      { "protocol": "pubsub",
        "properties": {
          "publications": [
            "/offramps/kafka/in"
          ]
        }
      }
    }
  }
```

Connecting with an initial subscription for publication that
allows pushing event data to a pipeline deployed in the target
tremor instance:

```json
  { "tremor": 
    { "connect": 
      { "protocol": "pubsub",
        "properties": {
          "publications": [
            "/pipeline/passthrough/in"
          ]
        }
      }
    }
  }
```

Connecting with multiple subscriptions and publications:

```json
  { "tremor": 
    { "connect": 
      { "protocol": "pubsub",
        "properties": {
          "subscriptions": [
            "/onramps/metronome/in",
            "/pipeline/passthrough/out"
          ],
          "publications": [
            "/offramps/kafka/in",
            "/pipeline/passthrough/in"
          ]
        }
      }
    }
  }
```

## Commands

Assuming a `pubsub` session is established and the session is aliases as `example`
via the network protocol control plane `connect` command as follows:

```json
  { "tremor": 
    { "connect": 
      { "protocol": "pubsub",
        "properties": {
          "subscriptions": [
            "/pipeline/passthrough/out"
          ]
        },
        "alias": "example"
      }
    }
  }
```

Subscriptions can be dynamically registered via the `subscribe` event as follows:

```json
{ 
  "example": { "subscribe": [
            "/pipeline/example/out"
  ]}
}
```

Active subscriptions can be unsubscribed via the `unsubscribe` event as follows:

```json
{ 
  "example": { "unsubscribe": [
            "/pipeline/example/out"
  ]}
}
```

Attempting to unsubscribe to an endpoint that does not exist in the
connect tremor target instance will result in an error that closes
the connection.

The active subscriptions can be queried via the `list` event as follows:

```json
{ "example": "list" }
```

The set of active subscriptions is returned as follows:

```json
{ 
  "example": { 
    "list": { 
      "subscriptions": [
        "/onramps/metronome/in",
        "/pipeline/passthrough/out"
      ],
      "publications": [
        "/offramps/kafka/in",
        "/pipeline/passthrough/in"
      ]
    }
  }
}
```

The `version` event returns the specification revision or version of
the protocol as described in this document:

```json
{ "example": "version" }
```

```json
{ "example": { "version": "0.10" } }
```

## Event format

Data sent or received by the protocol may be batched. Each event
has a set of optional headers, and a payload. The payload can be any
legal well formed tremor value.

```json
{
  "pubsub": {
    "messages": [{
      "headers": {
        "key": "value",
      },
      "data": "any-legal-tremor-value"
    }]
  }
}
```

## Close

When the network protocol session in its entirety is closed, or a `pubsub`
session is disconnected and closed, All active subscriptions are closed and
any resources cleaned up.

The implementation details are not specified nor defined at this time.

# Drawbacks

[drawbacks]: #drawbacks

This revision of the `pubsub` extension to the tremor network protocol
does not standardize quality of service semantics nor does it expose
signals or contraflow control events generated by the tremor runtime.

# Rationale and alternatives

[rationale-and-alternatives]: #rationale-and-alternatives

Tremor ships with a growing set of source (onramp), sink (offramp) connectors
that allow tremor to bridge to or integrate with external systems using network
protocols, transports and distribution/communication and data encodings that are
non-native and outside of the control of the tremor project.

The `pubsub` extension provides a minimal extension to the tremor network protocol
to support publish-subscribe messaging semantics natively in tremor.

# Prior art

[prior-art]: #prior-art

The publish-subscribe messaging [pattern](https://en.wikipedia.org/wiki/Publish%E2%80%93subscribe_pattern) is a well known pattern for asynchronous
communication of events between systems.

The `pubsub` extension to the tremor network protocol provides a minimal
implementation of the pattern over the tremor network protocol.

# Unresolved questions

[unresolved-questions]: #unresolved-questions

None

#Future possibilities
[future-possibilities]: #future-possibilities

Explicit support for guaranteed delivery, acknowledgements and other quality of
service guarantees is elided in this revision of the `pubsub` network protocol
extension.

It is likely that headers will be defined ( and reserved ) in future revisions of this
specification.

----