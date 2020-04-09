- Feature Name: `rfc_0009_onramp_offramp_exec`
- Start Date: 2020-02-21
- Rust Issue: [wayfair-incubator/tremor-rfcs#0000](https://github.com/wayfair-incubator/tremor-rfcs/issues/0000)
- RFC PR: [wayfair-incubator/tremor-rfcs#0000](https://github.com/wayfair-incubator/tremor-rfcs/pull/0000)

# Summary
[summary]: #summary

Ability to use a script/executable as source of data in onramp. Ability to use a
script/executable in offramp.

# Motivation
[motivation]: #motivation

Integrating with various sources of data mandates development of an onramp. Such
an activity is costly from point of view of development time, Tremor codebase
growth and maintenance. It would be far easier to just have Tremor run
scripts/executables in an onramp that would then interface with whatever data
source necessary. That is not to say that building dedicated onramps/offramps
does not make sense.

# Guide-level explanation
[guide-level-explanation]: #guide-level-explanation

Example `onramp.yml`:

```yml
id: stats
type: exec
codec: string
config:
  type: periodic
  timeout_ms: 2000
  interval_ms: 10000
  commands:
    - 'ps aux | sort -nk +4 | tail'
    - 'bpftrace -e \'tracepoint:raw_syscalls:sys_enter { @[comm] = count(); }\''
```

Example `onramp.yml`:

```yml
id: stats
type: exec
codec: string
config:
  type: continuous
  commands:
    - "vmstat 1 | awk '{now=strftime("%Y-%m-%d %T "); print now $0}'"
```

Example `offramp.yml`:

```yml
id: twitter_bot
type: exec
config:
  command: 'curl -u user:pass -d status="{}" http://twitter.com/statuses/update.xml'
```

# Reference-level explanation
[reference-level-explanation]: #reference-level-explanation

# Drawbacks
[drawbacks]: #drawbacks

# Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

# Prior art
[prior-art]: #prior-art

# Unresolved questions
[unresolved-questions]: #unresolved-questions

# Future possibilities
[future-possibilities]: #future-possibilities
