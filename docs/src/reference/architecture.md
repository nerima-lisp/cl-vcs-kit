# Architecture

Process execution, backend selection, and typed interpretation are separate
layers.

## Load order

The ASDF system loads the `src/` components serially. The broad dependency
direction is:

1. package names and shared types;
2. conditions and execution controls;
3. async and process helpers;
4. GHQ and repository discovery;
5. parsers and structured observation types;
6. backend definitions and command mappings;
7. Git operations, GHQ operations, and structured readers.

The public package definition and shared result conventions load before
higher-level wrappers.

## Runtime path

For a normalized command, the runtime path is:

```text
repository handle
  -> backend lookup and operation mapping
  -> executable plus argument vector
  -> cl-process-kit result or task
  -> optional parser / typed observation
```

The raw command layer ends at the process result. Structured readers parse that
result into typed objects. Callers can keep backend-specific options while
using typed data for supported formats.

## Extensibility points

Backends are data objects registered in a process-wide registry. A backend can
provide marker paths for detection, normalized command mappings, capability
metadata, and structured-operation declarations. Operation mappings may be
exact, aliases, approximate, or native to the backend.

The public API does not require a backend to implement every normalized
operation. Callers should inspect capability metadata before dispatching a
dynamic operation. See [operations](../guide/operations.md) and
[compatibility](compatibility.md).
