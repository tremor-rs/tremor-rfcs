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
* modularization, outsourcing common definitions to reusable modules (e.g. HTTP proxy setup with sources, sinks, pipeline)
* more expressive
* makes it possible to introduce a REPL for issuing language statements against a tremor installation (be it a single server or a cluster)

The main advantage is that we can integrate the whole pipeline and script definitions seamlessly and reuse language concepts and idioms, so users will
get a look and feel of the deployment language, trickle and tremor-script to be 1 language with slight extensions based on context (e.g. pipeline definition).


# Guide-level explanation
[guide-level-explanation]: #guide-level-explanation

A full tremor deployment always consists of one or more `sources`, connected to one or more `pipelines` connected to one or more `sinks`.
These are deployed as a single unit that describes how these artefacts are connected.

The lifecycle of an artefact during deployment is (in very verbose terms) the following:

* publish its definition (with all configuration) via unique (per artefact type) artefact id
  - publishes the artefact definition to the repository under the artefact id
  - makes it resolvable via a Tremor URL
* create an instance from the artefact referenced by its type and id (or via Tremor URL) with a unique (per artefact) instance id
  - instantiates the artefact and publishes it to the registry under the artefact-id and instance-id
  - makes it resolvable via a Tremor URL
* link the instance to other compatible instances (e.g. pipeline -> sink or source -> pipeline), thus creating a connected and actively running event flow

There are also the following steps:

* Disconnect an artefact instance from all its connections (e.g. disconnect an offramp from its pipelines)
* Destroy an artefact instance and thus stop its operation
  * Stopping artefacts will also stop artefacts that are no longer in use (e.g. sources without connected pipelines)
* Remove the artefact definition from the repository

The main scope of the Tremor Deployment language (Troy for short) are the lifecycle steps of deploying, connecting and running artefacts.
It tries to be flexible and powerful by exposing statements for all lifecycle operations, while also optimizing for a convenient experience in the common case of deploying rather simple event flows.

Troy files can be deployed to a Tremor instance or cluster on startup or via API endpoint. It is also possible to issue Troy statements inside a REPL-like setup, but this is outside of the scope of this RFC.

Whenever a Troy file is deployed the statements within it are executed.

Similar to trickle, Troy also supports modularization and `use` statements using the same mechanism as is employed in trickle (loading the "`used`" file contents into the current file). This allows for defining commonly used artefacts in separate files.

## Example

```

# define a connector with arguments
define http_server connector my_http_connector
args
  server = "Tremor/1.2.3",
with
  codec = "json",
  interceptors = [ "newline" ],
  config.headers = {
      "Server": args.server
  }
end;

# define a file connector
define file connector my_file
with
    config.path = "/snot/badger.json",
    codec = "json",
    interceptors = [ "newline" ]
end;

# define the simplest pipeline
define pipeline passthrough
query
    select event from in into out;
end;

# instantiate a connector
create connector instance "01" from my_http_connector
with
    server = "Tremor/3.2.1"
end;

# define a flow - connecting artefact instances
define flow my_flow
links
    # reference artefacts by id - these instances are not recreated if they are already created
    connect "/connector/my_http_connector/01/out" to "/pipeline/passthrough/in";
    # implicit default ports - here we auto-create instances
    connect passthrough to my_file;
end;

# instantiate a flow - let the events flow ~~~
create instance "01" from flow/my_flow;
```

For an overview of alternatives we considered and discussed, see [Rationale and Alternatives](#rationale-and-alternatives)

# Reference-level explanation
[reference-level-explanation]: #reference-level-explanation

Troy supports two very basic operations / kinds of statements:

 * Definition of artefacts
 * Creation of artefacts

## Artefact definition

Artefact definition creates a referencable artefact inside the tremor repository.
It contains:

 * an id that is unique per repository
 * intrinsic connector type this artefact is based on
 * generic connector config
 * specific config for the connector type
 * possibly a list of arguments that can/need to be provided upon creating/instantiating this artefact

There are many artefacts like connectors, sources, sinks, pipelines, deployments.
Here we want to describe 3 special artefacts: Connectors, Pipelines, Deployments:


### Connectors

EBNF Grammar:

```
connector       = "define" connector_type "connector" artefact_id
                  [ "args" argument_list ]
                  ( with_block | script_block )
                  "end"
connector_type  = [ module_path "::" ] id      
module_path     = id [ "::" module_path ]
artefact_id     = id     
argument_list   = ( id | id "=" expr ) [ "," argument_list ]
with_block      = "with" assignment_list
assignment_list = assignment [ "," assignment_list ]
assignment      = let_path "=" expr
let_path        = id [ "." id ]
script_block    = "script" tremor_script
```

Whitespace and newlines are not significant here.

**Examples:**


Every connector can be configured using the `with` statement which introduces a key-value mapping which resembles (and actually is implemented as) a tremor-script multi-let. Keys are possible tremor-script identifiers, values can be any tremor-script expressions.

It is also possible to add `args` which can be provided upon artefact creation/instantiation and can be referenced from within the `with` block: 

```
define http connector my_http
args
    required_argument,
    optional_arg_with_default = "default value"
with
    codec = "json",
    interceptors = [ 
        {
            "type": "split",
            "config": {
                "split_by": "\n"
            }
        },
        "base64"
    ],
    config.host = "localhost",
    config.port = args.required_argument,
    err_required = args.optional_arg_with_default
end;
```


#### Required Tremor Script Changes

In order to make defining config entries in tremor-script convenient, we introduced the `with` block. We need to add a few features to tremor-script to make this work reasonably well in a configuration context, where all we want is to return a record value without too much fuss and ceremony:

* Add multi-let statements, that combine multiple `let`s inside a single statement whcih defined the variables therein and returns a record value with all those definitions.
* Add auto-creation of intermediary path segments in let stetements:

  ```
  let config.nested.value = 1;
  ```

  In this case if `config.nested` does not exist we would auto-create it as part of this let as an empty record. This statement would fail, if we would try to *nest* into an existing field that is not a record.

### Pipelines

Pipelines are defined using a unique pipeline id, optionally some arguments and a mandatory query block that embeds a trickle query:

EBNF Grammar:

```
pipeline      = "define" "pipeline" pipeline_id
                [ "args" argument_list ]
                "query" 
                trickle_query
                "end"
pipeline_id   = id
argument_list = ( id | id "=" expr ) [ "," argument_list ]
```

Whitespace and newlines are not significant here.

**Example:**

`args` can be referenced within the trickle query via the `args` root. As these are filled upon creation/instantiation
a pipeline definition becomes a template:

```
define pipeline my_pipeline
args
    required_argument,
    optional_arg_with_default = "default value"
query
    use std::datetime;
    define tumbling window fifteen_secs
    with
        interval = datetime::with_seconds(args.required_argument),
    end;

    select { "count": aggr::stats::count(event) } from in[fifteen_secs] into out having event.count > 0;
end; # we probably need to find a different way to terminate an embedded trickle query or find some trick
```

It might be interesting to be able to load a trickle query from a trickle file.
To that end we add new config directives to trickle that can define arguments and their default values.

```trickle
#!config arg my_arg = "foo"
#!config arg required_arg
...
```

### Flow

Flows are a new type of artefact that incorporates the previous concepts of `binding` and `mapping`.
Flows define how artefacts are connected to form an event flow from sources via pipelines towards sinks.

EBNF Grammar:

```
flow          = "define" "flow" flow_id
                [ "args" argument_list ]
                "links"
                  link_list
                "end"
flow_id       = id
argument_list = ( id | id "=" expr ) [ "," argument_list ]
link_list     = link ";" [ link_list ]
link          = "connect" tremor_url "to" tremor_url
instance_port = artefact_id [ "/" instance_id ] ":" port
```

Example:

```
define flow my_eventflow
args
    required_arg,
    optional_arg = "default value"
links
    connect "tremor://onramp/my_source/{required_arg}/out" to my_pipeline:in;
    connect my_pipeline:out to my_sink:in;
end;
```

#### Connect Statements

Flows consists of `connect` statements, which connect two or more artefact instances via their ports. E.g. every instance
that receives events has an `in` port. Event go out via the `out` port and error events are usually sent via the `err` port.
A connect statement defines a connection between two instance-port references. These are provided as strings containing tremor urls
in the following variants:

* with instance-id and port (e.g. "/pipeline/my_pipeline/instance_id:in" )
* without instance-id but with port (e.g. "/pipeline/my_pipeline:in" )
* without instance id or port (e.g. "/pipeline/my_pipeline" )

If no instance id is given, as part of the flow instantiation a new instance of the artefact is created with the flow instance id filled in as instance id. So, users can omit an instance id if they want to have their artefacts be auto-created as part of an event flow.
They will also be auto-deleted upon flow deletion. Our goal with this setup is to make it possible for users to define their tremor setup
as one unit, the `Flow`. It can be instantiated and deleted with one command or API call.

If an already existing artefact instance is referenced via an instance-port reference in a connect statement, the `flow` will not take ownership of those instances. It will just release the connections that are defined in the `links` section of its definition.
With this logic, users are able to dynamically create and manage connections between existing artefacts separately from those artefacts itself.

For this to work the `flow` instance needs to track which instances it created in order to destroy them upon the process of itself being destroyed.

If the port is ommitted, based on its position a default port is chosen. If a reference is on the LHS the port `out` is chosen, on the RHS `in` is implied. This matches the normal event flow: From the `out` port of an artefact to an `in` port of another one. Other cases need to be handled explicitly.

#### Connect Statement Sugar

Connect statements describe the very primitive operation needed to establish an event flow from sources/connectors via pipelines towards sinks/connectors. Defining each single connection manually might be a bit too verbose. That is why we will provide some more convenient versions that basically all encode `connect` statements, but are much more concise and expressive.

We call them `arrow` statements. Both the LHS and the RHS are Tremor URL string. The LHS of a simple `arrow` statement is the "sender" of events, the RHS is the "receiver". The direction of the arrow describes the flow direction. If no port is provided, the LHS uses the `out` port, the RHS uses the `in` port, so users dont need to specify them in the normal case.

Examples:

```
# without ports
"/source/stdin" -> "/pipeline/pipe";
"/pipeline/pipe/err" -> "/sink/system::stderr";

# with ports
"/pipeline/pipe:err" -> "/sink/my_error_file:in";
```

`Arrow` statements also support chaining. This works as follows: As `arrow` statements when used as expression, will expose its RHS if used as LHS and its LHS if it is used as RHS. The arrow statements handle other arrow statements as LHS and RHS separately. In effect chaining `arrow` statements is just writing multiple TremorURLs connected via `arrows`:

```
"/source/system::stdin" -> "/pipeline/system::passthrough" -> "/sink/system::stderr";
```

This is equivalent to the following, when adding explicit parens to show precedence:

```
("/source/system::stdin/out" -> "/pipeline/system::passthrough/in") -> "/sink/system::stderr/in";
```

Which resolves via desugaring:

```
connect "/source/system::stdin/out" to "/pipeline/system::passthrough/in";
connect "/pipeline/system::passthrough/out" to "/sink/system::stderr/in";
```

`Arrow` statements also support tuples of Tremor URLs or tuples of other `Arrow` statements. These describe branching and joining
at the troy level.

```
"/source/system::stdin/out" -> ("/pipeline/system::passthrough", "/pipeline/my_pipe" ) -> "/sink/system::stderr/in";
```

This desugars to:

```
"/source/system::stdin/out" -> "/pipeline/system::passthrough" -> "/sink/system::stderr/in";
"/source/system::stdin/out" -> "/pipeline/my_pipe" -> "/sink/system::stderr/in";
```

If we have multiple tuples within a statement, we create statements for each combination of them. Example:

```
# full sugar
("/source/my_file", "/source/my_other_file") -> ("/pipeline/pipe1", "/pipeline/pipe2") -> "/sink/system::stderr";

# desugars to:

"/source/my_file" -> "/pipeline/pipe1" -> "/sink/system::stderr";
"/source/my_file" -> "/pipeline/pipe2" -> "/sink/system::stderr";
"/source/my_other_file" -> "/pipeline/pipe1" -> "/sink/system::stderr";
"/source/my_other_file" -> "/pipeline/pipe2" -> "/sink/system::stderr";
```

The immediate win in terseness is obvious, we hope.

It will be very interesting to explore how to expose the same sugar to trickle select queries. This is a future possibility.

## Instantiating artefacts

Every artefact that was defined can be created, optionally passing arguments:


EBNF:

```
create          = "create" "instance" instance_id "from" artefact_type "/" artefact_id
                  [ "with" assignment_list ]
                  "end"
assignment_list = assignment [ "," assignment_list ]
assignment      = let_path "=" expr
let_path        = id [ "." id ]
```

The result is a running instance that is registered via its `instance-id` within the registry and thus globally resolvable.

**Examples:**

```
create instance "01" from pipeline/my_pipeline
with
    window_size = 15
end;
```

It might be interesting to use a tremor URL instead of ids as artefact_type and artefact id. This is an open question.

### Instantiating Flows

Flows are an exception as their creation will possibly create other artefact instances.

When creating any instances within a flow fails, all the instances connected and instantiated with that flow shall be stopped and destroyed again in order to make flow creation not leak resources in the error case.

## Top-Level Connect statements

Connect statements have been introduced as part of `flow` definitions. It will greatly simplify setting up tremor installations if we could write them at the top level of a troy script.

The process of describing a tremor deployment would then consist conceptually of the following steps:

1. define artefacts to be connected
2. connect those artefacts

These steps describe a good intuition about setting up a graph of nodes for events to flow through.

Example:

```
define file connector my-file-connector
with
  source = "/my-file.json",
  codec = "json"
end;

connect "/connector/my-file-connector/out" to "/pipeline/system::passthrough/in";
connect "/pipeline/system::passthrough/out" to "/connector/system::stderr/in";
```

For setting up tremor with this script, the conecpt of a `flow` doesnt event need to be introduced. Escpecially for getting started and
trying out simple setups in a local dev environment or for tutorials and workshops, this removes friction and descreases `time-to-get-something-running-and-have-fun-understanding`.

What is going on under the hood here to make this work?

Those connect statements will be put into a synthetic `flow` artefact with the artefact id being the file in which they are declared. There is exactly one such synthetic `flow` artefact for a troy file, but only if at least 1 globale `connect` statement is given. The `flow` instance id will be `default`.
This `flow` artefact is defined and created without args upon deployment of the troy script file.

Following this route it sounds reasonable to also add `disconnect` statements as the dual of `connect`:

```
disconnect "/connector/my-file-connector/out" from "/pipeline/system::passthrough/in";
```

With `flows` we would destroy the whole `flow` instance to delete the connections therein at once. With top level `connect` statements,
we cannot reference any such instance, unless we reference it using the naming scheme above. But we would lose the power to modify single connections if we'd refrain from looking into `disconnect`.

# Drawbacks
[drawbacks]: #drawbacks

* YAML is a widely known and used configuration format, we can assume a certain level of familiarity amongst developers
* A new DSL to learn, steepens the learning curve for tremor

# Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

- YAML - we don't like it. Significant whitespace might be readable on first sight, but brings lots of other problems.


## Versions we considered and discarded

One initial draft contained `with` as a keyword for starting a key-value mapping (a record in tremor-script)
as a special case only used in configuration contexts:

```
define connector artefact ws_conn
with
  type = ws,
  # nested record
  config with
    host = "localhost",
    port = 8080
  end,
  codec = my_json with ... end
  interceptors = ...
end;
```

This was discarded because `with` as a keyword doesn't really work as keyword for a key-value mapping. To be consistent with tremor-script, it should be `record`. But finally we decided to not burn a keyword and search for another solution.

The first name for `flow` was `deployment` but it was way too generic as a term. In a `flow` we connect sources to pipelines and pipelines to sinks, thus creating a flow of events. So `flow` sounded much more suitable. We were clear that `binding` and `mapping` weren't suitable anymore as well.
# Prior art
[prior-art]: #prior-art

We might want to look at languages like the one used in hashicorps terraform. Its concept is to describe a desired state of set of resources, not to encode commands against the current state of those resources. Comparing the desired state against the actual state will result in the set of commands to issue to get to the desired one.

But we might want to enable the usage of a REPL like setup, for which the terraform model doesnt work.

# Unresolved questions
[unresolved-questions]: #unresolved-questions

- Should we use Tremor URLs in Create statements to reference artefacts we create instances from?
- Should we add means to instead of using a TremorURL also enable referencing artefacts by id (or artefact-type, artefact-id pair)?
- Should we really allow users to create instances of unconnected artefacts? While it gives power to users it might also be a source of misconfiguration. Trade-offs...

# Future possibilities
[future-possibilities]: #future-possibilities

## Configure Artefacts using Script blocks

Given the plan is to implement the with block as syntax sugar around a tremor-script block with a `multi-let` expression, we could enable the feature to use a more complex script block to define the configuration record. E.g. if we need to dispatch on som arguments and chose different config entries based on that, this would not be possible using a `with` block.

Example:

```
define file connector my_file_connector
args 
    dispatch_arg = "default"
script
    match dispatch_arg of
        case "snot" => {"snot": true, "arg": dispatch_arg}
        case "badger" => {"badger": true, "arg": dispatch_arg}
        default => {"default": true}
    end
end
```

## Graceful Operations

We could add statement variants for create that fail if an instance with the same id already exists or that gracefully do nothing if that is the case. This graceful behavior needs to be able to verify that the existing instance is from the very same artefact, and for this might be checking the artefact content too, not just its name.
## Non-String Tremor-URLs

It would be nice for static analysis of troy scripts to have tremor urls in connect statements to not be strings,
but to have them use ids as references to defined artefacts or already created artefact instances. string urls allow references
outside the context of the current troy script though, which might or might not be valid based on the state of the registry at the point of creation. So maybe, an id based syntax for tremor-urls might help with error detection in troy scripts but would only work when referencing artefacts and instances is limited to the current troy script (including imports).

Some ideas to spawn discussion:

```
pipeline:my_pipeline/instance_id:in
```

If we change the requirement for artefact ids to be globally unique, not only per artefact type, we wouldnt even need to prefix them with their artefact type every time:

```
my_pipeline/instance_id:in
```

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
