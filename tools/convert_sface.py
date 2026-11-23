"""Converts OpenCV Zoo's SFace face-recognition model (Apache 2.0) to the Core ML model WatchMyFace ships.

    python3.12 -m venv .venv && .venv/bin/pip install coremltools onnx onnx2torch "torch==2.7.0" onnxruntime numpy
    .venv/bin/python tools/convert_sface.py

Downloads face_recognition_sface_2021dec.onnx, checks its SHA-256, converts it through PyTorch to an ML program
(float16 weights) and checks the Core ML embedding against ONNX Runtime's on random faces-sized inputs. Writes
Sources/WatchMyFace/Resources/SFace.mlpackage.

The model takes a 112 x 112 RGB face aligned on five points (eyes, nose tip, mouth corners; see FaceAlignment.swift)
as plain 0-255 pixels: its own first two layers subtract 127.5 and divide by 128. Out comes a 128-number embedding.
"""

import hashlib
import pathlib
import shutil
import tempfile
import urllib.request

import coremltools as ct
import numpy as np
import onnx
import onnxruntime
import torch
from onnx2torch import convert

URL = "https://huggingface.co/opencv/face_recognition_sface/resolve/main/face_recognition_sface_2021dec.onnx"
SHA256 = "0ba9fbfa01b5270c96627c4ef784da859931e02f04419c829e83484087c34e79"
ROOT = pathlib.Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "Sources/WatchMyFace/Resources/SFace.mlpackage"


def download(directory: pathlib.Path) -> pathlib.Path:
    path = directory / "sface.onnx"
    urllib.request.urlretrieve(URL, path)
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    if digest != SHA256:
        raise SystemExit(f"Unexpected SHA-256 {digest}; the upstream file changed.")
    return path


def strip_initializer_inputs(path: pathlib.Path) -> onnx.ModelProto:
    """The 2021 export lists every weight as a graph input too, which onnx2torch reads as a real input."""
    model = onnx.load(path)
    weights = {initializer.name for initializer in model.graph.initializer}
    inputs = [graph_input for graph_input in model.graph.input if graph_input.name not in weights]
    del model.graph.input[:]
    model.graph.input.extend(inputs)
    return model


def main() -> None:
    with tempfile.TemporaryDirectory() as directory:
        onnx_path = download(pathlib.Path(directory))
        onnx_model = strip_initializer_inputs(onnx_path)
        cleaned = pathlib.Path(directory) / "clean.onnx"
        onnx.save(onnx_model, cleaned)

        torch_model = convert(onnx_model).eval()
        example = torch.rand(1, 3, 112, 112) * 255
        traced = torch.jit.trace(torch_model, example)

        mlmodel = ct.convert(
            traced,
            inputs=[ct.ImageType(name="face", shape=(1, 3, 112, 112), color_layout=ct.colorlayout.RGB, scale=1.0)],
            outputs=[ct.TensorType(name="embedding")],
            convert_to="mlprogram",
            compute_precision=ct.precision.FLOAT16,
            minimum_deployment_target=ct.target.macOS14,
        )
        mlmodel.short_description = "SFace (MobileFaceNet), OpenCV Zoo, Apache 2.0"
        mlmodel.author = "Yaoyao Zhong (SFace); ONNX by Chengrui Wang; Core ML conversion for WatchMyFace"
        mlmodel.license = "Apache License 2.0"
        mlmodel.input_description["face"] = "112 x 112 RGB face, aligned on eyes, nose tip and mouth corners"
        mlmodel.output_description["embedding"] = "128-number face embedding; compare by cosine similarity"

        check(mlmodel, cleaned)
        if OUTPUT.exists():
            shutil.rmtree(OUTPUT)
        mlmodel.save(str(OUTPUT))
        print(f"Wrote {OUTPUT.relative_to(ROOT)}")


def check(mlmodel: ct.models.MLModel, onnx_path: pathlib.Path) -> None:
    """Core ML must give (nearly) the same direction as ONNX Runtime, the reference implementation."""
    from PIL import Image

    session = onnxruntime.InferenceSession(str(onnx_path))
    rng = np.random.default_rng(7)
    for _ in range(8):
        pixels = rng.integers(0, 256, size=(112, 112, 3), dtype=np.uint8)
        reference = session.run(None, {"data": pixels.transpose(2, 0, 1)[None].astype(np.float32)})[0][0]
        converted = mlmodel.predict({"face": Image.fromarray(pixels)})["embedding"].reshape(-1)
        cosine = float(np.dot(reference, converted) / np.linalg.norm(reference) / np.linalg.norm(converted))
        if cosine < 0.999:
            raise SystemExit(f"Core ML and ONNX Runtime disagree: cosine {cosine:.5f}")
    print("Core ML matches ONNX Runtime (cosine >= 0.999 on 8 inputs).")


if __name__ == "__main__":
    main()
