import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'dart:core';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as IMG;
import 'package:byte_util/byte_util.dart';

import 'dart:developer' as developer;

import '../main.dart';

enum ScreenMode { liveFeed, gallery }

class CameraView extends StatefulWidget {
  static final GlobalKey<_CameraViewState> globalKey = GlobalKey();
  // super(key: globalKey);
  CameraView(
      {required this.title,
      required this.customPaint,
      required this.onImage,
      this.initialDirection = CameraLensDirection.back})
      : super(key: globalKey);

  final String title;
  final CustomPaint? customPaint;
  final Function(InputImage inputImage) onImage;
  final CameraLensDirection initialDirection;

  @override
  _CameraViewState createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  ScreenMode _mode = ScreenMode.liveFeed;
  CameraController? _controller;
  File? _image;
  CameraImage? camImg;
  ImagePicker? _imagePicker;
  int _cameraIndex = 0;
  double zoomLevel = 0.0, minZoomLevel = 0.0, maxZoomLevel = 0.0;
  bool _allowPicker = true;
  bool _changingCameraLens = false;
  Size screenSize = Size(0.0, 0.0);
  var scale;

  @override
  void initState() {
    super.initState();

    _allowPicker = false;
    _imagePicker = ImagePicker();

    if (cameras.any(
      (element) =>
          element.lensDirection == widget.initialDirection &&
          element.sensorOrientation == 90,
    )) {
      _cameraIndex = cameras.indexOf(
        cameras.firstWhere((element) =>
            element.lensDirection == widget.initialDirection &&
            element.sensorOrientation == 90),
      );
    } else {
      _cameraIndex = cameras.indexOf(
        cameras.firstWhere(
          (element) => element.lensDirection == widget.initialDirection,
        ),
      );
    }

    _startLiveFeed();
  }

  @override
  void dispose() {
    _stopLiveFeed();
    super.dispose();
  }

  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (_allowPicker)
            Padding(
              padding: EdgeInsets.only(right: 20.0),
              child: GestureDetector(
                onTap: _switchScreenMode,
                child: Icon(
                  _mode == ScreenMode.liveFeed
                      ? Icons.photo_library_outlined
                      : (Platform.isIOS
                          ? Icons.camera_alt_outlined
                          : Icons.camera),
                ),
              ),
            ),
        ],
      ),
      body: _body(),
      floatingActionButton: _floatingActionButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget? _floatingActionButton() {
    if (_mode == ScreenMode.gallery) return null;
    if (cameras.length == 1) return null;
    return SizedBox(
        height: 70.0,
        width: 70.0,
        child: FloatingActionButton(
          child: Icon(
            Platform.isIOS
                ? Icons.flip_camera_ios_outlined
                : Icons.flip_camera_android_outlined,
            size: 40,
          ),
          onPressed: _switchLiveCamera,
        ));
  }

  Widget _body() {
    Widget body;
    if (_mode == ScreenMode.liveFeed) {
      body = _liveFeedBody();
    } else {
      body = _galleryBody();
    }
    return body;
  }

  Widget _liveFeedBody() {
    if (_controller?.value.isInitialized == false) {
      return Container();
    }

    screenSize = MediaQuery.of(context).size;
    // calculate scale depending on screen and camera ratios
    // this is actually size.aspectRatio / (1 / camera.aspectRatio)
    // because camera preview size is received as landscape
    // but we're calculating for portrait orientation
    developer.log("MediaQuery Size => " + screenSize.toString(), name: 'my.other.category');
    scale = screenSize.aspectRatio * _controller!.value.aspectRatio;

    // to prevent scaling down, invert the value
    if (scale < 1) scale = 1 / scale;
    developer.log("scale => " + scale.toString(), name: 'my.other.category');
    // _getPosition();

    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Transform.scale(
            scale: scale,
            child: Center(
              child: _changingCameraLens
                  ? Center(
                      child: const Text('Changing camera lens'),
                    )
                  : CameraPreview(_controller!),
            ),
          ),
          if (widget.customPaint != null) widget.customPaint!,
          // Positioned(
          //     bottom: 100,
          //     left: 50,
          //     right: 50,
          //     child: IconButton(
          //       enableFeedback: true,
          //       color: Colors.white,
          //       onPressed: () async {},
          //       icon: const Icon(
          //         Icons.camera,
          //       ),
          //       iconSize: 92,
          //     )),
          // SizedBox(
          //   height: 50,
          // ),
        ],
      ),
    );
  }

  Widget _galleryBody() {
    return ListView(shrinkWrap: true, children: [
      _image != null
          ? SizedBox(
              height: 400,
              width: 400,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  Image.file(_image!),
                  if (widget.customPaint != null) widget.customPaint!,
                ],
              ),
            )
          : Icon(
              Icons.image,
              size: 200,
            ),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: ElevatedButton(
          child: Text('From Gallery'),
          onPressed: () => _getImage(ImageSource.gallery),
        ),
      ),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: ElevatedButton(
          child: Text('Take a picture'),
          onPressed: () => _getImage(ImageSource.camera),
        ),
      ),
    ]);
  }

  Future _getImage(ImageSource source) async {
    final pickedFile = await _imagePicker?.pickImage(source: source);
    if (pickedFile != null) {
      _processPickedFile(pickedFile);
    }
    setState(() {});
  }

  void _switchScreenMode() async {
    if (_mode == ScreenMode.liveFeed) {
      _mode = ScreenMode.gallery;
      await _stopLiveFeed();
    } else {
      _mode = ScreenMode.liveFeed;
      await _startLiveFeed();
    }
    setState(() {});
  }

  Future _startLiveFeed() async {
    final camera = cameras[_cameraIndex];
    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );
    _controller?.initialize().then((_) {
      if (!mounted) {
        return;
      }
      _controller?.getMinZoomLevel().then((value) {
        zoomLevel = value;
        minZoomLevel = value;
      });
      _controller?.getMaxZoomLevel().then((value) {
        maxZoomLevel = value;
      });
      _controller?.startImageStream(_processCameraImage);
      setState(() {});
      _controller?.setFlashMode(FlashMode.off);
    });
  }

  Future _stopLiveFeed() async {
    // await _controller?.stopImageStream();
    await _controller?.dispose();
    _controller = null;
  }

  Future _switchLiveCamera() async {
    setState(() => _changingCameraLens = true);
    _cameraIndex = (_cameraIndex + 1) % cameras.length;

    await _stopLiveFeed();
    await _startLiveFeed();
    setState(() => _changingCameraLens = false);
  }

  Future _processPickedFile(XFile? pickedFile) async {
    final path = pickedFile?.path;
    if (path == null) {
      return;
    }
    setState(() {
      _image = File(path);
    });
    final inputImage = InputImage.fromFilePath(path);
    widget.onImage(inputImage);
  }

  Future _processCameraImage(CameraImage image) async {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final Size imageSize =
    Size(image.width.toDouble(), image.height.toDouble());

    final camera = cameras[_cameraIndex];
    final imageRotation =
        InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
            InputImageRotation.rotation0deg;

    final inputImageFormat =
        InputImageFormatValue.fromRawValue(image.format.raw) ??
            InputImageFormat.nv21;

    final planeData = image.planes.map(
          (Plane plane) {
        return InputImagePlaneMetadata(
          bytesPerRow: plane.bytesPerRow,
          height: plane.height,
          width: plane.width,
        );
      },
    ).toList();

    final inputImageData = InputImageData(
      size: imageSize,
      imageRotation: imageRotation,
      inputImageFormat: inputImageFormat,
      planeData: planeData,
    );

    final inputImage =
    InputImage.fromBytes(bytes: bytes, inputImageData: inputImageData);

    setState(() {
      camImg = image;
    });

    widget.onImage(inputImage);
  }



  Future _saveImage(IMG.Image img) async{
    Directory appDocDir = await getTemporaryDirectory();
    Directory? externalDirectory = await getExternalStorageDirectory();
    String appDocPath = appDocDir.path;

    String timestamp() => DateTime.now().millisecondsSinceEpoch.toString();
    final Directory? extDir = await getExternalStorageDirectory();
    final String dirPath = '${extDir!.path}/Pictures';
    final myImgDir = await new Directory(dirPath).create();

    var cv_img = await new File('$dirPath/id_card-${timestamp()}.jpg')
        .writeAsBytes(IMG.encodePng(img));
  }

  Future processtakePicture(Map<String, dynamic> hitInfo) async {
    IMG.Image? src;

    if(camImg!.format.group == ImageFormatGroup.yuv420){
      src = await convertYUV420toImageColor(camImg!);
    }else{
      src = await IMG.Image.fromBytes(
          camImg!.planes[0].bytesPerRow,
          camImg!.height,
          camImg!.planes[0].bytes,
          format: IMG.Format.bgra,
        );
    }
    if(src != null){
      
      await _controller?.stopImageStream();

      Directory appDocDir = await getTemporaryDirectory();
      Directory? externalDirectory = await getExternalStorageDirectory();
      String appDocPath = appDocDir.path;

      String timestamp() => DateTime.now().millisecondsSinceEpoch.toString();
      final Directory? extDir = await getExternalStorageDirectory();
      final String dirPath = '${extDir!.path}/Pictures';
      final myImgDir = await new Directory(dirPath).create();

      // await _controller?.stopImageStream();
      // XFile file = await _controller!.takePicture();
      // final bytes = await File(file.path).readAsBytes();
      // final IMG.Image src = IMG.decodeJpg(bytes)!;
      // ImageProperties properties = await FlutterNativeImage.getImageProperties(file.path);
      // // var y = [properties.height,properties.width].reduce(max);
      // // var x = [properties.height,properties.width].reduce(min);
      // final int h = properties.height;

      // final int w = properties.width;
      // final size = MediaQuery.of(context).size;
      // final int h = src.height; //1280
      // final int w = src.width; //720

      double hScale = screenSize.height / src.height;
      double sScale = src.height / screenSize.height;

      developer.log("Image Size => w:" + src.width.toString() + " h:"+ src.height.toString() + " hScale:" + hScale.toString(), name: 'my.other.category');

      
      final int h = ((hitInfo["bottom"] - hitInfo["top"])).round(); //1280
      
      int left = (hitInfo["right"] - h*1.84).round();

      final int w = ((hitInfo["right"] - left)).round();  //720
      // int sw = (hitInfo["left"] * scale - w * 0.11).round();
      // int nw = ((hitInfo["right"] * scale + w * 0.1)).round();
      int sw = ((left)).round();
      int nw = (w + h*0.16).round();
      // int sh = (hitInfo["top"] * scale - w * 0.09).round();
      // int nh = ((hitInfo["bottom"] * scale + w * 0.01)).round();
      int sh = (hitInfo["top"] - h*0.11).round();
      int nh = (h + h*0.23).round();
      // var x = min(h, w);
      // var y = max(h, w);
      // int sw = 0;
      // int nw = 0;
      // int sh = 0;
      // int nh = 0;

      // sw = (w * 0.13).round();
      // nw = w - sw * 2;
      // nh = (w / 1.59).round();
      // sh = ((h / 2 - nh / 2)).round();
      // nh = ((nh - ((w * 0.08) * 2))).round();
      // if (scale > 1) {
      //   // sw = ((w * scale - w) / 2).round();
      //   // nw = (w / scale).round();
      //   // sh = (h * scale / 2  - w / 2).round();
      //   // nh = (nw / 1.55 ).round();
      //   sw = (((w * scale - w) / 2) + (w * scale * 0.01))
      //       .round();
      //   nw = ((w / scale) - (w * scale * 0.05)).round();
      //   sh = ((h * scale / 2 - w * scale / 2.7)).round();
      //   nh = (nw - (h * scale * 0.115)).round();
      // } else {
      //   sw = (w - w * scale).round();
      //   nw = (w / scale).round();
      //   sh = (h * scale / 2 - w / 2).round();
      //   nh = (nw / 1.59 / scale).round();
      // }

      IMG.Image img = IMG.copyCrop(src, sw, sh, nw, nh);

      var cv_img = await new File('$dirPath/id_card-${timestamp()}.jpg')
          .writeAsBytes(IMG.encodePng(img));
    }
  }

var shift = (0xFF << 24);
Future<IMG.Image?> convertYUV420toImageColor(CameraImage image) async {
      try {
        final int width = image.width;
        final int height = image.height;
        final int uvRowStride = image.planes[1].bytesPerRow;
        final int uvPixelStride = image.planes[1].bytesPerPixel!;

        print("uvRowStride: " + uvRowStride.toString());
        print("uvPixelStride: " + uvPixelStride.toString());

        // imgLib -> Image package from https://pub.dartlang.org/packages/image
        // var img = IMG.Image(width, height); // Create Image buffer
        var img = IMG.Image(height, width);

        // Fill image buffer with plane[0] from YUV420_888
        for(int x=0; x < width; x++) {
          for(int y=0; y < height; y++) {
            final int uvIndex = uvPixelStride * (x/2).floor() + uvRowStride*(y/2).floor();
            final int index = y * width + x;

            final yp = image.planes[0].bytes[index];
            final up = image.planes[1].bytes[uvIndex];
            final vp = image.planes[2].bytes[uvIndex];
            // Calculate pixel color
            int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
            int g = (yp - up * 46549 / 131072 + 44 -vp * 93604 / 131072 + 91).round().clamp(0, 255);
            int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);     
            // color: 0x FF  FF  FF  FF 
            //           A   B   G   R
            // img.data[index] = shift | (b << 16) | (g << 8) | r;
            if (img.boundsSafe(height-y, x)){ 
              img.setPixelRgba(height-y, x, r , g ,b ,shift); 
            } 
          }
        }

        // IMG.PngEncoder pngEncoder = new IMG.PngEncoder(level: 0, filter: 0);
        // List<int> png = pngEncoder.encodeImage(img);
        // muteYUVProcessing = false;
        return img;  
      } catch (e) {
        print(">>>>>>>>>>>> ERROR:" + e.toString());
      }
      return null;
  }
}
