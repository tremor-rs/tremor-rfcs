- Feature Name: graph-rewrite-to-eliminate-passthrough
- Start Date: 2020-01-29
- Tremor Issue: [wayfair-incubator/tremor-runtime#0033](https://github.com/wayfair-incubator/tremor-runtime/issues/0033)
- RFC PR: [wayfair-incubator/tremor-rfcs#0011](https://github.com/wayfair-incubator/tremor-rfcs/pull/0011)

# Summary
[summary]: #summary

There are currently including passthrough nodes with no functionality in the pipeline, this helps building it but before the pipeline is executed it makes sense to eliminate the nodes.

# Motivation
[motivation]: #motivation

Passthrough nodes in the pipeline graph serve no value during execution time but still take up time.

# Guide-level explanation
[guide-level-explanation]: #guide-level-explanation

This RFC is a purely technical choice and has no guide level impact.

# Reference-level explanation
[reference-level-explanation]: #reference-level-explanation

Passthrough nodes are used to connect operators when compiling a trickle script into a pipeline both as inputs and outputs as well as in optimization steps to simplify operators without effect.

This RFC proposes eliminating them as a second step before turning the pipeline into an executable graph. When handled in a generic re-writing step other optimizations might be added later.

In short the chain `op1 -(some-output)-(in)-> passthrough -(out)-(some-input) -> op2` needs to be rewritten as `op1 -(some-output)-(some-input) -> op2`. In repeating this transformation until no more changes are observed we would get chained passthorugh operators optimized out 'for free'.


# Drawbacks
[drawbacks]: #drawbacks

We lose a one to one mapping between the script and the executable graph.

# Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

An alternative is changing the compilation step of trickle not to generate passthrough operators in the first place. This approach does not require rewriting the graph. However it also is a less generic solution that will be harder to extend in the future.

# Prior art
[prior-art]: #prior-art

We are using similar techniqus of rewriting parts of the tremor script AST as part of the optimization step.

# Unresolved questions
[unresolved-questions]: #unresolved-questions

As of writing this there are no unresolved questions.

# Future possibilities
[future-possibilities]: #future-possibilities

With a generic rewriting mechanism for the graph, we open up the possibility to do additional optimization on the graph level of the runtime.