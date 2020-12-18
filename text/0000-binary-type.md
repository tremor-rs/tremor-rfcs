- Feature Name: binary-type
- Start Date: 2020-12-16
- Tremor Issue: [tremor-rs/tremor-runtime#0000](https://github.com/tremor-rs/tremor-runtime/issues/0000)
- RFC PR: [tremor-rs/tremor-rfcs#0000](https://github.com/tremor-rs/tremor-rfcs/pull/0000)

# Summary
[summary]: #summary

This RFC proposes the addition of a new type: `binary` along with the underpinnings needed to extend tremors type system.

# Motivation
[motivation]: #motivation

The motivation here is three-fold.

As of writing this RFC tremor has no option to handle 'raw' data. As it stands, even if we never want to inspect or modify a payload we always pay the price of translating the data into tremors internal, JSONesque format or representing it as a utf8 string. Both these choices come at a computation cost at best or are wrong and lossy at worst. A binary type allows us to treat a message as "a bunch of bytes", removing any loss or additional computational cost of encoding/decoding them.

The second reason for a binary datatype is to be able to handle messages that are not covered by existing codes. A binary type along with the functions to inspect, deconstruct or create binary messages gives a new extension point for users to parse their own, non-textual formats.

Last but not least, extending tremor with a binary type, something that JSON isn't capable of representing lays the groundwork for adding more powerful types to tremor. It serves as a case study of the cost/complexity of this and will help simplifying the task for later additions.

# Guide-level explanation
[guide-level-explanation]: #guide-level-explanation

The `binary` type in tremor comes along with additions to the tremor-script syntax, the type system, codecs, the standard library and a specification of the serialization behavior. We will discuss each of those 

## The `binary` type
The easiest way to think about it is that the `binary` type represents an array of bytes.

## Serialization

This is codec dependant and not always symmetric, can not represent binary data and is a general-purpose codec it will default to base64 encoding the data as a string (JSON for example). This is an asymmetric change as we will not by default decode a base64 string as binary given without context we can't determine if this is the desired behavior or not, this can however be done using tremor-scripts functions.

## Syntax

We use the [erlang bit syntax](https://erlang.org/doc/programming_examples/bit_syntax.html) as an inspiration. Tremor script gains support for binary semi-literals using the form of `<< expr1, expr2 >>` where `expr` has to return a 1-byte number. More elaborate forms, such as bitwise size and different types are aimed to be added later and follow the erlang bit syntax.

Binary matching will likely follow the same logical pattern as other matching syntaxes, and aim to provide at least erlang style dissection of binary data.

## stdlib

This RFC introduces the `base64` module for encoding and decoding `binary` data as base64 strings. It also adds the `binary` module with basic functions such as `len`, as well as conversion functions to and from arrays of numbers.

The `string` module gains functions to convert a string to a `binary` as well as a function that will take a `binary` and convert it to a utf8 `string` in a potentially lossy fashion for invalid utf8 data.

The `type` module will gain the `is_binary` function as well as `type::as_string` now returning `"binary"` when appropriate.

## codecs

This RFC introduces the `binary` codec that passes bytes unmodified as binary data.

The `json` codec is changed to serialize `binary` data as a base64 encoded string, however it will not automatically decode base64 strings as binary.

The `msgpack` codec should encode and decode binary as `bin` types.

# Reference-level explanation
[reference-level-explanation]: #reference-level-explanation

The `binary` type is a `Vec<u8>` that serializes as base64 encoded string in simd-json and as `bytes` in serde compatible encoders.

If the new implemented functions are all constant, they will be able to be pre-computed when constant folding is possible.

The binary semi-literals will, whenever possible be turned into full-literals using constant folding, but remain constructs where not following the example of arrays and records.

# Drawbacks
[drawbacks]: #drawbacks

This breaks symmetry with the JSON representation, however all differences can be recovered using the provided tremor-script functionality.
# Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

A quick search showed no decent alternative binary syntax to erlangs binary forms, however any other suggestions are welcome.

# Prior art
[prior-art]: #prior-art

This RFC is heavily inspired by the (erlang bit syntax)[https://erlang.org/doc/programming_examples/bit_syntax.html] .
# Unresolved questions
[unresolved-questions]: #unresolved-questions

As of writing the first draft of this RFC it is still open how far into bit syntax compatibility it will go while balancing benefit and time constraints. Binary comprehensions, as existing in erlang are not part of this RFC. Neither support for 'less then a byte' boundaires.

# Future possibilities
[future-possibilities]: #future-possibilities

Binary comprehensions are a major future possibility for bit syntax. They are also well seperated in the way that extracting them will not harm this RFC.
