- Feature Name: rfc-0022-network-protocol-api
- Start Date: 2021-01-15
- Tremor Issue: [tremor-rs/tremor-runtime#0174](https://github.com/tremor-rs/tremor-runtime/pull/174)
- RFC PR: [tremor-rs/tremor-rfcs#0021](https://github.com/tremor-rs/tremor-rfcs/pull/0021)

# Summary

[summary]: #summary

Tremor Messaging Protocol Specification - API Proxy Model

# Motivation

[motivation]: #motivation

Extends the tremor network protocol specification with a protocol
that proxies tremor's REST-based API.

Through exposing the tremor API over the network protocol consumers of
the tremor network protocol do not need to maintain separate code that
targets the REST based tremor API.

# Guide-level explanation

[guide-level-explanation]: #guide-level-explanation

This specification provides a mechanism to invoke the tremor API as a network
protocol extension.

Through exposing the tremor API over the network protocol - implementations of
the network protocol can leverage the API without writing and maintaining separate
code to target the REST API.

# Reference-level explanation

[reference-level-explanation]: #reference-level-explanation

This section describes how to `connect`, and interact with the
tremor API.

The `close` operation is a nil operation that does nothing for this protocol.

## Connect

A minimally correct instanciation is as follows:

```json
  { "tremor": 
    { "connect": 
      { "protocol": "api",
      }
    }
  }
```

## Commands

Assuming an `api` session is established and the session is aliased as `example`
via the network protocol control plane `connect` command as follows:

```json
  { "tremor": 
    { "connect": 
      { "protocol": "api",
        "alias": "example"
      }
    }
  }
```

API requests are of the general form

```json
{ 
  "example": { "artefact": "onramp", "operation": "fetch", "id": "metronome", "data": "encoded-string" format="json", "instance": "01" }}
}
```

Where:
- `artefact` and `operation` MUST be provided always
- `list` operations MUST NOT provide an `id`, `data` or `format`
- `fetch` and `delete` operations MUST provide an `id`, but MUST NOT provide `data` or `format`
- `create` operations MUST provide all fields
- `instance` operations MUST provide an `artefact` and `instance`
- `activate` and `deactivate` operations MUST provide an `artefact` and `instance`

## Close

There is no state to clean up so the implementation simply closes and unregisters
the api session.

# Drawbacks

[drawbacks]: #drawbacks

None

# Rationale and alternatives

[rationale-and-alternatives]: #rationale-and-alternatives

The `api` protocol extension is a developer/operator convenience

# Prior art

[prior-art]: #prior-art

This protocol extension is a form of `bridge` or `proxy` that provides
an asynchronous non-blocking interface to a REST based backend deployed
on the target tremor instance.

# Unresolved questions

[unresolved-questions]: #unresolved-questions

A decision needs to be made on whether or not the `api` protocol is available
when the `api` is configured to inactive on the target tremor instance.

- We could normalize for consistency with the api flag in `tremor server run` so
  that if the api is enabled/disabled via that flag then the api protocol is configured
  similarly. Where the api is disabled, creating an `api` session would be an error.

- We could normalize for consistency of operation so that the `api` is always available
  or never available via the messaging protocol based on operator provided configuration

The correct answer may be use case, deployment and situation dependent.

#Future possibilities
[future-possibilities]: #future-possibilities

Changes to the tremor REST API imply changes to this protocol extension and changes to
this document.

----