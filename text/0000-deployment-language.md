- Feature Name: deployment_language
- Start Date: 2020-12-15
- Tremor Issue: [tremor-rs/tremor-runtime#0000](https://github.com/tremor-rs/tremor-runtime/issues/0000)
- RFC PR: [tremor-rs/tremor-rfcs#0000](https://github.com/tremor-rs/tremor-rfcs/pull/0000)

# Summary
[summary]: #summary

Add a deployment language to tremor with which whole event flows, consisting of sinks, sources and pipelines can be defined, instantiated, run and removed again.

# Motivation
[motivation]: #motivation

The main reason is that current deployments are split in several parts:

1. sink/source (onramp/offramp) definition
2. pipeline definition in trickle
3. linking definition which connects 1. to 2.
4. mapping definition, which instatiates and finally deploys the connected parts from 3.

We have to split those across at least 2 files: 1 yaml file for artefacts, linking and mapping, 1 trickle file for the pipeline.

It would be much nicer for users to define their deployment in one unit, one file.
Also, given our experiences with tremor-script and trickle, a DSL that is well suited for the task at hand can provide benefits such as:

* helpful feedback on errors
* modularization, outsourcing common definitions to reusable modules (e.g. HTTP proxy setup with onramps, offramps, pipeline)
* more expressive
* makes it possible to introduce a REPL for issuing language statements against a tremor installation (be it a single server or a cluster)

The main advantage is that we can integrate the whole pipeline and script definitions seamlessly and reuse language concepts and idioms, so users will
get a look and feel of the deployment language, trickle and tremor-script to be 1 language with slight extensions based on context (e.g. pipeline definition).


# Guide-level explanation
[guide-level-explanation]: #guide-level-explanation

A full tremor deployment always consists of one or more `onramps`, connected to one or more `pipelines` connected to one or more `offramps`.
These are deployed as a single unit that describes how these artefacts are connected.

The lifecycle of an artefact during deployment is (in very verbose terms) the following:

* publish its definition (with all configuration) via unique (per artefact type) artefact id
  - publishes the artefact definition to the repository under the artefact id
  - makes it resolvable via a Tremor URL
* create an instance from the artefact referenced by its type and id (or via Tremor URL) with a unique (per artefact) instance id
  - instantiates the artefact and publishes it to the registry under the artefact-id and instance-id
  - makes it resolvable via a Tremor URL
* link the instance to other compatible instances (e.g. pipeline -> offramp or onramp -> pipeline), thus creating a connected and actively running event flow

There are also the following steps:

* Disconnect an artefact instance from all its connections (e.g. disconnect an offramp from its pipelines)
* Destroy an artefact instance and thus stop its operation
* Remove the artefact definition from the repository

The main scope of the Tremor Deployment language (Troy for short) are the lifecycle steps of deploying, connecting and running artefacts.
It tries to be flexible and powerful by exposing statements for all lifecycle operations, while also optimizing for a convenient experience in the common case of deploying rather simple event flows.

Troy files can be deployed to a Tremor instance or cluster on startup or via API endpoint. It is also possible to issue Troy statements inside a REPL-like setup, but this is outside of the scope of this RFC.

Whenever a Troy file is deployed the statements within it are executed.

Similar to trickle, Troy also supports modularization and `use` statements using the same mechanism as is employed in trickle (loading the "`used`" file contents into the current file). This allows for defining commonly used artefacts in separate files.

## Example

```
define 
```



Explain the proposal as if it was already included in Tremor and you were teaching it to another Tremor user. That generally means:

- Introducing new named concepts.
- Explaining the feature largely in terms of examples.
- Explaining how stakeholders should *think* about the feature, and how it should impact the way they use tremor. It should explain the impact as concretely as possible.
- If applicable, provide sample error messages, deprecation warnings, or migration guidance.
- If applicable, describe the differences between teaching this to existing tremor stakeholders and new tremor programmers.

For implementation-oriented RFCs (e.g. for language internals), this section should focus on how language contributors should think about the change, and give examples of its concrete impact. For policy RFCs, this section should provide an example-driven introduction to the policy, and explain its impact in concrete terms.

# Reference-level explanation
[reference-level-explanation]: #reference-level-explanation

## Artefact definition

## Instantiating artefacts

## Connecting Artefact instances

### Deployments

### Top-Level Connect statements

This is the technical portion of the RFC. Explain the design in sufficient detail that:

- Its interaction with other features is clear.
- It is reasonably clear how the feature would be implemented.
- Corner cases are dissected by example.

The section should return to the examples given in the previous section, and explain more fully how the detailed proposal makes those examples work.

# Drawbacks
[drawbacks]: #drawbacks

* YAML is a widely known and used configuration format, we can assume a certain level of familiarity amongst developers
* A new DSL to learn, steepens the learning curve for tremor


# Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

- Why is this design the best in the space of possible designs?
- What other designs have been considered and what is the rationale for not choosing them?
- What is the impact of not doing this?

# Prior art
[prior-art]: #prior-art

Discuss prior art, both the good and the bad, in relation to this proposal.
A few examples of what this can include are:

- For language, library, tools, and clustering proposals: Does this feature exist in other programming languages and what experience have their community had?
- For community proposals: Is this done by some other community and what were their experiences with it?
- For other teams: What lessons can we learn from what other communities have done here?
- Papers: Are there any published papers or great posts that discuss this? If you have some relevant papers to refer to, this can serve as a more detailed theoretical background.

This section is intended to encourage you as an author to think about the lessons from other projects, provide readers of your RFC with a fuller picture.
If there is no prior art, that is fine - your ideas are interesting to us whether they are brand new or if it is an adaptation from other projects.

Note that while precedent set by other projects is some motivation, it does not on its own motivate an RFC.
Please also take into consideration that tremor sometimes intentionally diverges from similar projects.

# Unresolved questions
[unresolved-questions]: #unresolved-questions

## Nicer record syntax for configuration

The syntax in trickle for providing configuration values in a key-value structure for configuring operators etc. is as follows:

```trickle
define qos::backpressure operator bp
with
  timeout = 100,
  steps = [1, 2, 3]
end;
```

The key value structure is introduced with the `with` keyword. Keys don't require quotes like strings, and values are given after `=` those values can be any trickle expression. Now with connectors / onramps / offramps, the `config` setting requires to introduce nesting. But with the current syntax, we would have to use a [record literal](https://docs.tremor.rs/tremor-script/#records) to provide a key-value structure:

```
define connector my_ws_client
with
  type = "ws_client",
  config = {
      "endpoint": "ws://127.0.0.1:12345/path",
      "connect_timeout": 12345
  },
  codec = "json"
end;
```

This is inconsistent and confusing for users. Ideally we should use the same syntax regardless of the nesting.
Options here are:

1. use record syntax also at the top level

```
define connector my_ws_client
with {
  "type": "ws_client",
  "config": {
    "endpoint": "ws://127.0.0.1:12345/path",
    "connect_timeout": 12345
  },
  "codec": "json"
}
end;
```

As the goal is consistency this would also be changed in trickle/tremor-script, so this would be a breaking change.

The downside of this, while we have increased consistency, is that it is less readable.

2. extend the configuration key-value syntax to a simplified record structure that is nestable

This would introduce a whole new expression for encoding json-like records that might be usable in other places too.

```
define connector my_ws_client
with record
    type = "ws_client",
    config = record
      endpoint = "ws://127.0.0.1:12345/path",
      connect_timeout = 12345
    end,
    codec = "json"
end;
```

We might want to reuse the `with` keyword signalling the start of the `configuration record`, but could also use `record`, `object` or `config` here.

- What parts of the design do you expect to resolve through the RFC process before this gets merged?
- What parts of the design do you expect to resolve through the implementation of this feature before stabilization?
- What related issues do you consider out of scope for this RFC that could be addressed in the future independently of the solution that comes out of this RFC?

# Future possibilities
[future-possibilities]: #future-possibilities

## Define Codecs and interceptors (a.k.a pre- and post-processors)

It might be nice to be able to define codecs and interceptors as well in the deployment language.
That will mean:

* builtin codecs and interceptors are predefined in something like a Troy stdlib:

```
intrinsic codec json;
```

* codecs and interceptors can be provided with configuration and be referencable under a unique name.

```
define codec pretty_json from json
with
    pretty = true,
    indent = 4,
end;
```

This will solve the current problem that `pre-` and `postprocessors` are not configurable.
It will nonetheless introduce another type of `artefact` that actually isnt a proper artefact, and so applying the language concepts to it might not fully work out and lead to confusion.

Also it is not possible to fully define codecs and interceptors inside troy. They are all written in rust for performance reasons. The only thing we can do is to configure them and associate a codec/interceptor with its configuration and make this pair referencable within the language.

Think about what the natural extension and evolution of your proposal would
be and how it would affect Tremor as a whole in a holistic way. Try to use
this section as a tool to more fully consider all possible interactions with the
project in your proposal. Also consider how the this all fits into the roadmap for
the project and of the relevant sub-team.

This is also a good place to "dump ideas", if they are out of scope for the
RFC you are writing but otherwise related.

If you have tried and cannot think of any future possibilities,
you may simply state that you cannot think of anything.

Note that having something written down in the future-possibilities section
is not a reason to accept the current or a future RFC; such notes should be
in the section on motivation or rationale in this or subsequent RFCs.
The section merely provides additional information.
