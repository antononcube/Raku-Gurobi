# Raku-Gurobi

A small Raku `NativeCall` interface to the Gurobi numerical optimization C API.

This project defaults to the Gurobi 13 shared library bundled by `gurobipy` at
`/home/vscode/.local/lib/python3.14/site-packages/gurobipy/.libs/libgurobi130.so`.
For another installation, set `RAKU_GUROBI_LIB` before starting Raku.

```sh
RAKU_GUROBI_LIB=/path/to/libgurobi130.so raku -Ilib examples/Small-model.raku
raku -Ilib xt/01-small-model.rakutest
```

The integration test skips when no usable Gurobi license is configured.
