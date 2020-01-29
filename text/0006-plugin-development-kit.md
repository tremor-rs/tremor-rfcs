- Feature Name: plugin_development_kit
- Start Date: (fill me in with today's date, YYYY-MM-DD)
- Tremor Issue: [wayfair-incubator/tremor-runtime#0037](https://github.com/wayfair-incubator/tremor-runtime/issues/37)
- RFC PR: [wayfair-incubator/tremor-rfcs#0010](https://github.com/wayfair-incubator/tremor-rfcs/pull/0010)

# Summary
[summary]: #summary

A plugin development kind (PDK for short) allows modularizing tremor's components and decupling their development. The two main requirements for the PDK are loading linked libraries that expose the artifacts and extending the current hardcoded registry to allow referencing those artifacts.

# Motivation
[motivation]: #motivation

There are multiple motivating factors for allowing plugins to be loaded and developed seperately.

The first benefit of a PDK is to decouple the deployment of the tremor executable and its plugins. Decupling allows shipping, deploying, or updating artifacts after initial deployment.

The second benefit is taking the burden of the core project. It makes it easier and less involved to add new artifacts as they can be developed, shipped, and tested seperately without the requirement to always include them.

Lastly, rust compile times are high. Excluding components such as ramps, and plugins from the compilation part, and allowing them to be compiled only when they change, reduces build times and in result that development times. 

# Guide-level explanation
[guide-level-explanation]: #guide-level-explanation

The PDK allows to build linked libraries that can contain the following tremor components:

- Onramps
- Offramps
- Codecs
- Preprocessors
- Postprocessors
- Operators
- Functions

The resulting plugins can be loaded into a tremor instance either at start-time or dynamically and then used in deployments.

# Reference-level explanation
[reference-level-explanation]: #reference-level-explanation

The PDK requires to extend the registries we use for various artifacts; we need to allow registering additional dynamic elements in addition to the current hardcoded ones. It is worth to consider nested namespacing to prevent collisions.

We need to consider handling unloading, in this RFC, we suggest that this is forbidden to eliminate the complexity of dependency tracking, and the only way o unload a plugin is a restart of the runtime. The implementation still needs to consider not blocking later avenues of adding unloading plugins.

Lastly, developer tooling such as template projects, traits, examples, and eventually, testing frameworks will go a long way to make it easier and more accessible.

# Drawbacks
[drawbacks]: #drawbacks

Possible drawbacks to consider are the additional complexity of deployment. While right now, tremor is a single binary that can be deployed with ease, adding plugins means keeping not only that binary but all plugins in sync, especially when deploying multiple versions.

A secondary possible issue that is worth considering is versioning. Once the PDK is published, internal interfaces become public interfaces, and by that nature, a lot harder to change. So they need to be designed more carefully.

We need to consider ownership of plugins. Aside from code-related issues, we need a process for promoting plugins to officially maintained plugins and in some cases officially maintained into internalized artifacts.

# Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

One alternative to plugins and a PDK is to internalize every artifact, this is the current approach, and while it is manageable with a singular development team, it quickly becomes a burden, with external contributors, and this is not maintainable in the long run.

Another alternative is to make it possible to 'soft code' plugins in tremor script or another dialect. For some artifacts, such as codecs, or pre and post processors, this might be an alternative and worth investigating. However, given the performance-critical nature of many of the artifacts and the existence of well tested and widely used libraries for many tasks, it is not a generally applicable approach, that could fully replace plugins.

# Prior art
[prior-art]: #prior-art

- [Java package name conventions](https://docs.oracle.com/javase/tutorial/java/package/namingpkgs.html)
- [libloading rust crate for dynamic library loading](https://docs.rs/libloading/0.5.2/libloading/index.html)

# Unresolved questions
[unresolved-questions]: #unresolved-questions

It remains to be discussed how clustering affects a PDK. It internalizes the deployment problem for an operational to a cluster concern. This makes loading plugins more complicated as it requires to ship, syncroniuze, and load those plugins from a central source..

# Future possibilities
[future-possibilities]: #future-possibilities

Future possibilities are a central plugin registry (think cargo for plugins), clustering and deployment of plugins, bundles, and dependencies amongst plugins.