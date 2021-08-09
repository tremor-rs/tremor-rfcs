- Feature Name: Expression based path root
- Start Date: 2021-08-01
- Tremor Issue: [tremor-rs/tremor-runtime#1165](https://github.com/tremor-rs/tremor-runtime/pull/1165)
- RFC PR: [tremor-rs/tremor-rfcs#0000](https://github.com/tremor-rs/tremor-rfcs/pull/0000)

# Summary
[summary]: #summary

This RFC suggests extending that path to allow additional root elements, namely (immutable) expressions. This includes function calls, record, and list (semi)literals and complex expressions enclosed in `()`.

# Motivation
[motivation]: #motivation

It is sometimes cumbersome to store a result in an intermediate value to extract only a single sub-element from the result. It is also counterintuitive not to use an expression such as `function(arg).something` and can lead to unexpected syntax errors from tremor.

# Guide-level explanation
[guide-level-explanation]: #guide-level-explanation

No new concepts are introduced. The existing concept of a path is extended. As of today, a path could originate from:

- `event` an event
- `$` the event metadata
- a local variable
- a constant
- the build-in keywords `args`, `group` and `state`

We suggest extending this with four more variants:

- `{...}` record literals
- `[...]` array literals
- `struct::keys(a_record)` a function call or a the return for it
- `(<immutable expr>)` any immutable expression in paratheses


# Reference-level explanation
[reference-level-explanation]: #reference-level-explanation

This is realized by either:

* using the returned reference from the expression as a root for a lookup
* introducing a new temporary local variable to assign the returned owned variable to and then using a reference to this as a root for the lookup

# Drawbacks
[drawbacks]: #drawbacks

The only drawback discovered during this PR is that it introduces a possibility to create less readable scripts where it would have made sense to introduce a named variable for readability, but instead, an expression root was used.

For example the first can be more readable then the second especially if the match statement grows:

```tremor
let key = match event of
   case %{present k1} => event.k1
   case %{present k2} => event.k2
   case %{present k3} => event.k3
   case _ => event
end;
key.badger

## or:

(match event of
   case %{present k1} => event.k1
   case %{present k2} => event.k2
   case %{present k3} => event.k3
   case _ => event
end).badger
```

# Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

An alternative would be leaving it as it is, but in many cases, this is counterintuitive. For example, `struct::keys(event)[0]` for "get me the first event key" feels natural while `let keys = struct::keys(event); keys[0]` does not.

# Prior art
[prior-art]: #prior-art

The current expression syntax is realistically the prior art this lead to, along with many other languages that allow path expressions on functions, expressions, or literals.

# Unresolved questions
[unresolved-questions]: #unresolved-questions

Should we allow **any** expression as a root? Right now, we purposefully exclude mutable expressions to prevent complexity from creeping into scripts. Still, there also is an argument to be made to allow any expression as a root since tremor-script is ultimately an expression-oriented language.

# Future possibilities
[future-possibilities]: #future-possibilities

- Extend this to other expressions as root elements.
- Include constant folding for looking up keys in constant roots.
