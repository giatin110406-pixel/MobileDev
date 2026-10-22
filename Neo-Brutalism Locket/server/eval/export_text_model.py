"""Export the MobileCLIP2-S0 text encoder for search on the phone (archive-ai-search-plan.md, A1).

Writes, into --out:
  search_text_encoder.onnx        float32: token ids [1, 77] int64 -> L2-normalised embedding [1, 512]
  search_text_encoder_4bit.onnx   what the phone downloads: MatMul weights in 4-bit blocks of 32
                                  (MatMulNBits), the token table in 4-bit blocks of 32 too, packed
                                  two per byte and unpacked with standard ops for the <= 77 rows a
                                  query uses; activations stay float32
  search_text_meta.json           context length, vocabulary size, logit scale, size

Measured on Flickr30k 1k (eval.search_eval), PyTorch R@1 / R@5 / R@10 68.8 / 89.7 / 93.8 %:
  v1 (2026-10-22, table int8, 49.8 MB):        68.4 / 89.6 / 93.8 %
  v2 (2026-10-23, table 4-bit, this script):   68.2 / 89.6 / 93.8 % (exact simulation)
Dropped: dynamic int8 (activations quantised too: cosine 0.95, R@1 -6 points); onnxruntime's own
4-bit Gather (GatherBlockQuantized) needs opset 21, and the upgrade broke ReduceL2.
The float32 file is only for the checks in eval.search_eval; never ship it (254 MB).

Usage (from server/, onnx + onnxruntime on PYTHONPATH, see docs section 8.3):
    $env:PYTHONPATH = ".eval_tools"
    .venv/Scripts/python.exe -m eval.export_text_model --out D:/clip_eval_tmp/text_model
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import open_clip
import torch

MODEL = "MobileCLIP2-S0"
PRETRAINED = "dfndr2b"
BLOCK = 32


class TextEncoder(torch.nn.Module):
    def __init__(self, model):
        super().__init__()
        self.model = model

    def forward(self, tokens):
        feat = self.model.encode_text(tokens)
        return feat / feat.norm(dim=-1, keepdim=True)


def pack_token_table_4bit(model, table_name: str):
    """The [vocab, dim] token table -> 4-bit, symmetric, one float16 scale per BLOCK values.

    Stored as uint8 [vocab, dim/2] (low nibble = even column, high nibble = odd column, value
    q + 8 for q in -8..7) and float16 [vocab, dim/BLOCK]. The Gather of the table is replaced by
    a Gather of both, then integer ops that unpack only the gathered rows, so the phone never
    holds the table as floats. Only opset 17 ops.
    """
    from onnx import TensorProto, helper, numpy_helper

    graph = model.graph
    init = next(i for i in graph.initializer if i.name == table_name)
    w = numpy_helper.to_array(init)
    vocab, dim = w.shape
    blocks = w.reshape(vocab, dim // BLOCK, BLOCK)
    scale = np.abs(blocks).max(axis=2, keepdims=True) / 7.0
    scale[scale == 0] = 1.0
    scale = scale.astype(np.float16).astype(np.float32)   # what the phone will use
    q = (np.clip(np.round(blocks / scale), -8, 7) + 8).astype(np.int16).astype(np.uint8)
    q = q.reshape(vocab, dim)
    packed = (q[:, 0::2] | (q[:, 1::2] << 4)).astype(np.uint8)

    gather = next(n for n in graph.node if n.op_type == "Gather" and n.input[0] == table_name)
    tokens, out = gather.input[1], gather.output[0]
    p = "tok4_"
    consts = {
        p + "packed": packed,
        p + "scales": scale.reshape(vocab, dim // BLOCK).astype(np.float16),
        p + "sixteen": np.array(16, np.int32),
        p + "eight": np.array(8, np.float32),
        p + "last": np.array([-1], np.int64),
        p + "shape_dim": np.array([0, 0, dim], np.int64),
        p + "shape_blocks": np.array([0, 0, dim // BLOCK, BLOCK], np.int64),
    }
    nodes = [
        helper.make_node("Gather", [p + "packed", tokens], [p + "rows"], axis=0),
        helper.make_node("Cast", [p + "rows"], [p + "rows32"], to=TensorProto.INT32),
        helper.make_node("Div", [p + "rows32", p + "sixteen"], [p + "hi"]),
        helper.make_node("Mul", [p + "hi", p + "sixteen"], [p + "hi16"]),
        helper.make_node("Sub", [p + "rows32", p + "hi16"], [p + "lo"]),
        helper.make_node("Unsqueeze", [p + "lo", p + "last"], [p + "lo1"]),
        helper.make_node("Unsqueeze", [p + "hi", p + "last"], [p + "hi1"]),
        helper.make_node("Concat", [p + "lo1", p + "hi1"], [p + "pairs"], axis=-1),
        helper.make_node("Reshape", [p + "pairs", p + "shape_blocks"], [p + "q"]),
        helper.make_node("Cast", [p + "q"], [p + "qf"], to=TensorProto.FLOAT),
        helper.make_node("Sub", [p + "qf", p + "eight"], [p + "centred"]),
        helper.make_node("Gather", [p + "scales", tokens], [p + "s16"], axis=0),
        helper.make_node("Cast", [p + "s16"], [p + "s"], to=TensorProto.FLOAT),
        helper.make_node("Unsqueeze", [p + "s", p + "last"], [p + "s1"]),
        helper.make_node("Mul", [p + "centred", p + "s1"], [p + "values"]),
        helper.make_node("Reshape", [p + "values", p + "shape_dim"], [out]),
    ]
    graph.initializer.remove(init)
    graph.initializer.extend(numpy_helper.from_array(v, k) for k, v in consts.items())
    at = list(graph.node).index(gather)
    graph.node.remove(gather)
    for offset, node in enumerate(nodes):
        graph.node.insert(at + offset, node)
    return model


def gemm_to_matmul(model):
    """Gemm(A, W, b) with a constant W -> MatMul(A, W') + b, so the 4-bit quantizer (MatMul
    only) takes it too. The attention out_proj layers are exported as Gemm with transB=1."""
    from onnx import helper, numpy_helper

    graph = model.graph
    inits = {i.name: i for i in graph.initializer}
    for node in list(graph.node):
        if node.op_type != "Gemm" or node.input[1] not in inits:
            continue
        attrs = {a.name: helper.get_attribute_value(a) for a in node.attribute}
        if attrs.get("transA", 0) or attrs.get("alpha", 1.0) != 1.0 or attrs.get("beta", 1.0) != 1.0:
            continue
        w = numpy_helper.to_array(inits[node.input[1]])
        if attrs.get("transB", 0):
            w = w.T
        name = node.input[1] + "_kn"
        graph.initializer.append(numpy_helper.from_array(np.ascontiguousarray(w), name))
        at = list(graph.node).index(node)
        graph.node.remove(node)
        product = node.output[0] + "_mm" if len(node.input) > 2 else node.output[0]
        new = [helper.make_node("MatMul", [node.input[0], name], [product], name=node.name + "_mm")]
        if len(node.input) > 2:
            new.append(helper.make_node("Add", [product, node.input[2]], [node.output[0]],
                                        name=node.name + "_bias"))
        for offset, n in enumerate(new):
            graph.node.insert(at + offset, n)
    used = {i for n in graph.node for i in n.input}
    for init in list(graph.initializer):
        if init.name not in used:
            graph.initializer.remove(init)
    return model


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)

    model, _, _ = open_clip.create_model_and_transforms(MODEL, pretrained=PRETRAINED)
    model.eval()
    tokenizer = open_clip.get_tokenizer(MODEL)
    encoder = TextEncoder(model).eval()

    # The fused attention kernel (aten::_native_multi_head_attention) has no ONNX form.
    torch.backends.mha.set_fastpath_enabled(False)
    probe = tokenizer(["a dog running on the beach"])
    fp32 = args.out / "search_text_encoder.onnx"
    with torch.no_grad():
        torch.onnx.export(encoder, probe, str(fp32), opset_version=17,
                          input_names=["tokens"], output_names=["embedding"], dynamo=False)
    print(f"wrote {fp32} ({fp32.stat().st_size / 1e6:.1f} MB)")

    import onnx
    import onnxruntime as ort
    from onnxruntime.quantization.matmul_4bits_quantizer import MatMul4BitsQuantizer

    # Fold constant Transposes first: the attention out_proj weights reach their MatMul through
    # one, and the 4-bit quantizer only takes a MatMul whose weight is a plain initializer
    # (without this, 12 x 1 MB stayed float32).
    folded = args.out / "_folded.onnx"
    options = ort.SessionOptions()
    options.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_BASIC
    options.optimized_model_filepath = str(folded)
    ort.InferenceSession(str(fp32), options, providers=["CPUExecutionProvider"])
    packed = pack_token_table_4bit(gemm_to_matmul(onnx.load(str(folded))),
                                   "model.text.token_embedding.weight")
    folded.unlink()
    quantizer = MatMul4BitsQuantizer(packed, block_size=BLOCK, is_symmetric=True,
                                     op_types_to_quantize=("MatMul",))
    quantizer.process()
    four = args.out / "search_text_encoder_4bit.onnx"
    onnx.checker.check_model(quantizer.model.model)
    onnx.save(quantizer.model.model, str(four))
    print(f"wrote {four} ({four.stat().st_size / 1e6:.1f} MB)")

    (args.out / "search_text_meta.json").write_text(json.dumps({
        "model": f"{MODEL}/{PRETRAINED}",
        "contextLength": int(probe.shape[1]),
        "vocabSize": int(model.vocab_size),
        "dim": int(model.text_projection.shape[1]) if hasattr(model, "text_projection")
        and model.text_projection is not None else 512,
        "logitScale": float(model.logit_scale.exp()),
        "bytes4bit": four.stat().st_size,
    }, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main()
