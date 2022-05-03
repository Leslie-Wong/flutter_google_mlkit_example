import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_ml_kit/google_ml_kit.dart';

import 'camera_view.dart';
import 'painters/face_detector_painter.dart';
import 'painters/text_detector_painter.dart';


import 'overlay_shape.dart';
import 'model.dart';

class FaceDetectorView extends StatefulWidget {

  // Function function;
  // FaceDetectorView({this.function});

  @override
  _FaceDetectorViewState createState() => _FaceDetectorViewState();
}

class _FaceDetectorViewState extends State<FaceDetectorView> {
  final TextRecognizer _textRecognizer = TextRecognizer();
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      // enableContours: true,
      enableClassification: true,
      enableTracking: true,
      enableLandmarks: true,
      minFaceSize: 0.8,
      mode: FaceDetectorMode.accurate 
    ),
  );
  bool _isBusy = false;
  CustomPaint? _customPaint;


  List<int> hitCorrectCount = [0];

  int img_h = 0; //1280
  int img_w = 0; //720

  final overlay = GlobalKey();
  GlobalKey cameraView = GlobalKey();

  double? X_Position = 0.00;
  double? Y_Position = 0.00;
  Size size = Size(0.0, 0.0);

  void _getPosition() {
    if (overlay.currentContext != null) {
      RenderBox? box = overlay.currentContext!.findRenderObject() as RenderBox?;
      size = box!.size;
      Offset position = box.localToGlobal(Offset.zero);

      setState(() {
        X_Position = position.dx;
        Y_Position = position.dy;
      });
    }
  }

  void takePhoto(){
    CameraView.globalKey.currentState!.processtakePicture();
  }

  @override
  void dispose() {
    _faceDetector.close();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          CameraView(
          title: 'Face Detector',
          customPaint: _customPaint,
          onImage: (inputImage) {
            _getPosition();
            processImage(inputImage);
          },
        initialDirection: CameraLensDirection.back,
    ),
    OverlayShape(
      CardOverlay.byFormat(OverlayFormat.cardID1),
      key: overlay,
    )]
    )
    );
  }

  Future<void> processImage(InputImage inputImage) async {
    if (_isBusy) return;
    _isBusy = true;
    img_h = inputImage.inputImageData!.size.width.round();
    img_w = inputImage.inputImageData!.size.height.round();
    final faces = await _faceDetector.processImage(inputImage);
    final recognizedText = await _textRecognizer.processImage(inputImage);
    if (inputImage.inputImageData?.size != null &&
        inputImage.inputImageData?.imageRotation != null) {
      final painter = FaceDetectorPainter(
          recognizedText,
          faces,
          inputImage.inputImageData!.size,
          inputImage.inputImageData!.imageRotation,
          _checkInsiteCard,
          _checkLeftTop,
          hitCorrectCount,
          takePhoto);
      _customPaint = CustomPaint(painter: painter);
    } else {
      _customPaint = null;
    }
    // final recognizedText = await _textRecognizer.processImage(inputImage);
    // if (inputImage.inputImageData?.size != null &&
    //     inputImage.inputImageData?.imageRotation != null) {
    //   final painter = TextRecognizerPainter(
    //       recognizedText,
    //       inputImage.inputImageData!.size,
    //       inputImage.inputImageData!.imageRotation);
    //   _customPaint = CustomPaint(painter: painter);
    // } else {
    //   _customPaint = null;
    // }
    _isBusy = false;
    if (mounted) {
      setState(() {});
    }
  }

  int _test(int x){
    return x;
  }

  bool _checkInsiteCard(double x, double y, double w, double h){

    int sw = (img_w * 0.12).round();
    int nw = (img_w - sw * 2) + (sw / 2).round();
    int nh = (img_w / 1.59).round();
    int sh = ((img_h / 2 - nh / 2)).round();
    nh = ((nh - ((img_w * 0.08) * 2))).round() + (sh / 1.15).round();

    if(x > sw && x < nw && y > sh && y < nh)
      return true;
    
    return false;
  }

  bool _checkLeftTop(double x){

    int sw = (img_w * 0.12).round();

    if(x > sw * 1.8 )
      return true;
    
    return false;
  }
}
