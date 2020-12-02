- Feature Name: `string_interpolation`
- Start Date: 2020-11-30
- Tremor Issue: [tremor-rs/tremor-runtime#0000](https://github.com/tremor-rs/tremor-runtime/issues/0000)
- RFC PR: [tremor-rs/tremor-rfcs#0000](https://github.com/tremor-rs/tremor-rfcs/pull/0000)

# Summary
[summary]: #summary

This RFC covers the implementation and behavior of string interpolation in both strings and heredocs.



# Motivation
[motivation]: #motivation

String interpolation is a powerful tool to create text in a dynamic fashion. Getting it to work in a consistent and unsurprising manner however is non-trivial. The goal of this RFC is to cover various edge cases to find an optimal interface. It also will discuss integration with the `std::string::format` function as it offers a related mechanism.

# Guide-level explanation
[guide-level-explanation]: #guide-level-explanation

Interpolation should work equally in heredocs and strings, for readability we will refer to it as `string interpolation` in an inclusive way.


The goal of string interpolation is making the creation of strings simpler. The basic facility is the ability to embed code inside a string that is executed and it's result then integrated into the string. There are more advanced systems such as templating libraries like [mustache](https://mustache.github.io/), however for now that kind of feature set is outside of the scope of the RFC.

For simplicity of use we will include strings and numbers verbatim but render all other data structures as JSON. An alternative approach would be to enforce the type to be primitive or even string but that feels like an unnecessary burden as auto conversion does not prevent manual conversion.


## Considerations for tremor

The syntax we are looking at is using `{}` to encapsulate data to be interpolated.

```tremor
"13 + 29 = {13 + 29}"
```

We are also using `{}` in `string::format` which leads to conflicts.

An alternative would be to adopt a more verbose form of interpolation and prefix the `{...}` with an additional character. A few options could be:

* `${ ... }` - the drawback being here is that $ is already used to stand for `metadata`, by that overloading the sign.
* `#{ ... }` - `#` is currently used for comments, by that overloading the sign.
* `%{ ... }` - the `%` sign with squiggly is currently also a record pattern for extractors, by that overloading the sign.
* `!{ ... }` - the `!` sign is easy to miss and not very readable
* `@{ ... }` - no overloading at the moment

## Use cases

### string only

```tremor
"13 + 29 = {13 + 29} escaped: \{} {{}}"
"13 + 29 = ${13 + 29} escaped: \${}"
"13 + 29 = #{13 + 29} escaped: \#{}"
"13 + 29 = %{13 + 29} escaped: \%{}"
"13 + 29 = !{13 + 29} escaped: \!{}"
"13 + 29 = @{13 + 29} escaped: \%{}"
```
### object keys

```tremor
{
  "key_{13 + 29} escaped: \{} {{}}": 1,
  "key_${13 + 29} escaped: \${}": 2,
  "key_#{13 + 29} escaped: \#{}": 3,
  "key_%{13 + 29} escaped: \%{}": 4,
  "key_!{13 + 29} escaped: \!{}": 5,
  "key_@{13 + 29} escaped: \@{}": 6
}
```

### code generation

```
"""
# using \ escape
\{
    "key": \{
        "key1": 42
    },
    "snot": {badger},
}
# using {{}} escape
{{
    "key": {{
        "key1": 42
    }},
    "snot": {badger},
}}
# using any of the prefix ones
{
    "key": {
        "key1": 42
    },
    "snot": #{badger},
}
"""
```

### Interaction with format

#### use case: building a format string dynamically and inputting data
```tremor
let f = match event.type of
  case "warning" => "be warned, something went wrong: {}"
  case "error" => "ERROR OMG! {}",
  default => "oh, hi, you can ignore this: {}"
end;

string::format(format, event.msg);
```

#### format and interpolation

```tremor
string::format("this should work {}", 42) == "this should work 42";
string::format("this should {"also work"} {}", 42) == "this should also work 42";
string::format("this should create a {{}} and say {}", 42) == "this should create a {} and say 42";
string::format("this should {"also work"}, create a {{}} and show {}", 42)  == "this should also work, create a {} and say 42";
```

This can cause issues since both interpolation and format give `{}` a special meaning. There are multiple possible solutions to this.

1. "Deal with it" this means that passing an interpolated string into format will require different escaping as a non interpolated string. This adds an unnecessary burden and learning curve on users and should be avoided.
2. Choose a different placeholder for format. This will break backward compatibility it has the advantage that revisiting string::format might make it more powerful.
3. Choose a different for interpolation, such as a prefix. would also resolve the problem and break backward compatibility but allow exploring alternative ways for interpolation.
4. Remove string::format, this would break backward compatibility but simplify things in the long run

Option 2 and 3 are non-exclusive



# Reference-level explanation
[reference-level-explanation]: #reference-level-explanation

The implementation holds a few requirements:

1. non interpolated strings should have no additional overhead.
2. constant folding should apply to interpolation.
3. interpolated strings should, at worst, have the same cost as string concatenation, at best be more preformat.
4. errors should remain hygienic and useful.
5. the behavior of interpolation should be the same in strings and heredocs
6. aside of the interpolation, behavior of interpolated and non interpolated strings should remain the same (read: adding an interpolated item to a string should not change behavior)


# Drawbacks
[drawbacks]: #drawbacks

There are some drawbacks to consider.

From a user perspective string interpolation adds to the cognitive complexity as it introduces a new logical element and new escaping requirements, this can partially be mitigated with good integration in highlighting to ease the readability.

Another drawback to consider is hidden performance cost, a string, intuitively, feels cheep as it is a primitive datatype, by adding interpolation strings become significantly more 'expensive' without being very explicit about it.

The overlap with string::format introduces the situation where we have two mechanisms that to the most degree solve the same problem. Giving users this choice makes it harder to write (and by that read) 'idiomatic' tremor code.

The choice of syntax comes with different drawbacks. Using a single `{}` style will force additional escaping, a longer syntax, for example one of the prefixed ones, will be more typing but would resolve a lot of escaping needs as `*{` is going to be a lot less common then a single `{`.

# Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

String interpolation feels more natural then using format functions or concatenation. While the aforementioned drawbacks exist they are outweighed by the gain in usability.

An alternative would be to extend the format function and drop interpolation, but the general aim for operator friendliness and usability rules this out.

# Prior art
[prior-art]: #prior-art

There are many existing implementations of string interpolation, for reference here are a few each producing the string `13 + 29 = 42`:

**Ruby** / **Elixir**
```ruby
"13 + 29 = #{13 + 29}
```

**Python**
```python
f'13 + 29 = {13 + 29}'
```

**Javascript**
```js
`13 + 29 = ${13 + 29}`
```

**BASH**
```bash
"13 + 12 = $(expr 13 + 29)"
```

**Kotlin**
(limited to variables)
```kotlin
    var answer = 13 + 29;
    "13 + 29 = $answer"
```

# Unresolved questions
[unresolved-questions]: #unresolved-questions

- Is it worth sticking with `{}` for interpolation despite the drawbacks on escaping
- What longer sequence would be the most appropriate

# Future possibilities
[future-possibilities]: #future-possibilities

This RFC does exclude considerations for a templateing language. This is however a possible extension for the future worth keeping in mind but would require a separate file format to keep the complexity at bay.