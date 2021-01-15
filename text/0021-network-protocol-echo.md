- Feature Name: rfc-0020-network-protocol-echo
- Start Date: 2021-01-15
- Tremor Issue: [tremor-rs/tremor-runtime#0174](https://github.com/tremor-rs/tremor-runtime/pull/174)
- RFC PR: [tremor-rs/tremor-rfcs#0021](https://github.com/tremor-rs/tremor-rfcs/pull/0021)

# Summary

[summary]: #summary

Tremor Messaging Protocol Specification - Echo Model

# Motivation

[motivation]: #motivation

Extends the tremor network protocol specification with an echo facility
for debug purposes.

The echo facility is a simple request-response facility where the
request is returned as a response or echo'd back to the originator.

# Guide-level explanation

[guide-level-explanation]: #guide-level-explanation

Echo returns the data sent as a response

# Reference-level explanation

[reference-level-explanation]: #reference-level-explanation

This section describes how to `connect`, and send data via the
echo protocol.

The `close` operation is a nil operation that does nothing for this protocol.

## Connect

A minimally correct instanciation is as follows:

```json
  { "tremor": 
    { "connect": 
      { "protocol": "echo",
      }
    }
  }
```

## Commands

Assuming an `echo` session is established and the session is aliased as `example`
via the network protocol control plane `connect` command as follows:

```json
  { "tremor": 
    { "connect": 
      { "protocol": "echo",
        "alias": "example"
      }
    }
  }
```

Data can be sent to the target instance as follows

```json
{ 
  "example": { "beep": "boop" }
}
```

The target instance will echo or return the data it was sent:

```json
{ 
  "example": { "beep": "boop" }
}
```

## Event format

Any legal tremor value may be sent by an established echo session channel.

## Close

There is no state to clean up so the implementation simply closes unregisters
the echo session.

# Drawbacks

[drawbacks]: #drawbacks

None

# Rationale and alternatives

[rationale-and-alternatives]: #rationale-and-alternatives

Protocol extensions are typically non-trivial in their implementation.

The `echo` protocol extension can be used to evidence whether the target
instance connected is alive and responsive and healthy, or unhealthy.

# Prior art

[prior-art]: #prior-art

The most well known echo protocol is the one defined as part of the
[Internet Protocol Suite](https://en.wikipedia.org/wiki/Internet_Protocol_Suite) as
defined in [RFC 862](https://tools.ietf.org/html/rfc862).

It was originally designed for testing and measurement of round-trip times.

# Unresolved questions

[unresolved-questions]: #unresolved-questions

None

#Future possibilities
[future-possibilities]: #future-possibilities

None

----