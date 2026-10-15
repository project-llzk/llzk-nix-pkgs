"""Check nanobind registration, generated operations, and installed MLIR libraries."""

import numpy as np

from mlir import ir
from mlir._mlir_libs import _mlirRegisterEverything
from mlir.dialects import arith
from mlir.passmanager import PassManager


registry = ir.DialectRegistry()
_mlirRegisterEverything.register_dialects(registry)

try:
    _mlirRegisterEverything.register_dialects(object())
except TypeError:
    pass
else:
    raise AssertionError("register_dialects accepted an invalid registry")

with ir.Context() as context, ir.Location.unknown():
    context.append_dialect_registry(registry)
    context.allow_unregistered_dialects = False
    module = ir.Module.create()
    with ir.InsertionPoint(module.body):
        constant = arith.ConstantOp(ir.IntegerType.get_signless(32), 42)
    assert constant.operation.name == "arith.constant"
    assert module.operation.verify()
    reparsed = ir.Module.parse(str(module))
    assert reparsed.operation.verify()
    PassManager.parse("builtin.module(canonicalize)").run(reparsed.operation)

    values = np.array([1, 2, 3], dtype=np.int32)
    dense = ir.DenseElementsAttr.get(values)
    np.testing.assert_array_equal(np.asarray(dense), values)

print("Installed MLIR Python bindings passed")
