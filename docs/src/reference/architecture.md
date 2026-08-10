# Architecture

The system is layered so that process execution, backend selection, and typed
interpretation can be used independently.

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

This keeps the public package definition and shared result conventions
available before higher-level wrappers are loaded.

## Runtime path

For a normalized command, the runtime path is:

```text
repository handle
  -> backend lookup and operation mapping
  -> executable plus argument vector
  -> cl-process-kit result or task
  -> optional parser / typed observation
```

The raw command layer ends at the process result. Structured readers continue
through a parser and construct typed objects. This separation lets callers
keep backend-specific options when they need them while using typed data where
the library has a defined format.

## Extensibility points

Backends are data objects registered in a process-wide registry. A backend can
provide marker paths for detection, normalized command mappings, capability
metadata, and structured-operation declarations. Operation mappings may be
exact, aliases, approximate, or native to the backend.

The public API does not require a backend to implement every normalized
operation. Callers should inspect capability metadata before dispatching a
dynamic operation. See [operations](../guide/operations.md) and
[compatibility](compatibility.md).
