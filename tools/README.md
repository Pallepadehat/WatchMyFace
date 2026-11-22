# Using a face-recognition model

Out of the box, WatchMyFace measures faces with Apple's Vision feature print. It's built in and needs nothing, but it's
a general image model, not a face model, so it tells people apart by a smaller margin. For sharper recognition, you can
give WatchMyFace a face-recognition model in Core ML format, such as ArcFace.

WatchMyFace doesn't ship one: the well-known pretrained face models come with licenses that don't allow
redistribution in an MIT project (InsightFace's ArcFace weights, for example, are for non-commercial research). Check
the license of any model you use.

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
| Input | One image input, 112 × 112 RGB. WatchMyFace hands it an upright, square crop of the face with a little margin. |
| Output | One multi-array output: the embedding. Any length; WatchMyFace normalizes it. |
| Preprocessing | Baked into the model (scaling, channel order), since WatchMyFace passes plain pixels. |
| Description | Optional. The model's description, if set, is the name Settings shows. |

The glance project has a [conversion script](https://github.com/jonnyoo/glance/tree/main/tools) that turns InsightFace's
ArcFace ONNX weights into a model of this shape, and checks the conversion is numerically sound.
