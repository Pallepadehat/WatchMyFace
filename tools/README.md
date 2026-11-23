# The face model

WatchMyFace ships [SFace](https://github.com/opencv/opencv_zoo/tree/main/models/face_recognition_sface), a
face-recognition model from the OpenCV Model Zoo under Apache 2.0, at `Sources/WatchMyFace/Resources/SFace.mlpackage`.
To rebuild it from the original ONNX file:

```sh
python3.12 -m venv tools/.venv
tools/.venv/bin/pip install coremltools onnx onnx2torch "torch==2.7.0" "torchvision==0.22.0" onnxruntime numpy pillow
tools/.venv/bin/python tools/convert_sface.py
```

It checks the download's SHA-256 and that Core ML's output matches ONNX Runtime's.

# Using another face-recognition model

You can swap in a different model in Core ML format, such as ArcFace. Well-known ArcFace weights come with licenses
that don't allow redistribution (InsightFace's are for non-commercial research), so WatchMyFace doesn't ship them.
Check the license of any model you use.

## Install a model

Put it at:

```
~/Library/Application Support/WatchMyFace/Models/FaceEmbedder.mlpackage
```

(`FaceEmbedder.mlmodelc`, already compiled, works too.) Quit and reopen WatchMyFace. Settings › Faces shows the model
in use. Profiles made with the old model are marked "Made with another face model": scan your face again.

## What the model must look like

| | |
| --- | --- |
| Input | One image input, 112 × 112 RGB. WatchMyFace hands it the face aligned on five points (pupils, nose tip, mouth corners) to the standard ArcFace template. |
| Output | One multi-array output: the embedding. Any length; WatchMyFace normalizes it. |
| Preprocessing | Baked into the model (scaling, channel order), since WatchMyFace passes plain pixels. |
| Description | Optional. The model's description, if set, is the name Settings shows. |

The glance project has a [conversion script](https://github.com/jonnyoo/glance/tree/main/tools) that turns InsightFace's
ArcFace ONNX weights into a model of this shape, and checks the conversion is numerically sound.
