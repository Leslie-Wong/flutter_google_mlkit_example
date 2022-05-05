import 'dart:ui';
import 'dart:ui' as ui;
import 'dart:io';

import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:google_ml_kit/google_ml_kit.dart';

import 'coordinates_translator.dart';

class FaceDetectorPainter extends CustomPainter {
  FaceDetectorPainter(this.recognizedText, this.faces, this.absoluteImageSize, this.rotation, this._check, this._checkLeftTop, this.hitInfo, this._takePhoto);

  final Size absoluteImageSize;
  final List<dynamic> faces;
  // final List<Face> faces;
  final RecognizedText recognizedText;

  final InputImageRotation rotation;
  Map<String, dynamic>  hitInfo;

  Function _check;
  Function _checkLeftTop;
  Function _takePhoto;

  int hitCheckCount = 0;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.red;
      
    final Paint background = Paint()..color = Color(0x99000000);

    final Paint paintLTRB = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Color.fromARGB(84, 0, 0, 0);

    hitCheckCount = 0;
    for (final Face face in faces) {
      //print('face.boundingBox =>' + face.boundingBox.toString());
      print('face.boundingBox =>' + face.boundingBox.size.toString());
      debugPrint("log me");
      bool check = _check(face.boundingBox.left, face.boundingBox.top, face.boundingBox.right, face.boundingBox.bottom);
      if(check){
        if(face.boundingBox.size.width > 75 && face.boundingBox.size.width < 110){
          hitInfo["size"] = size;
          hitCheckCount++;
          canvas.drawRect(
            Rect.fromLTRB(
              translateX(face.boundingBox.left, rotation, size, absoluteImageSize),
              translateY(face.boundingBox.top, rotation, size, absoluteImageSize),
              translateX(face.boundingBox.right, rotation, size, absoluteImageSize),
              translateY(
                  face.boundingBox.bottom, rotation, size, absoluteImageSize),
            ),
            paintLTRB,
          );

          void paintContour(FaceContourType type) {
            final faceContour = face.contours[type];
            if (faceContour?.positionsList != null) {
              for (final Offset point in faceContour!.positionsList) {
                canvas.drawCircle(
                    Offset(
                      translateX(point.dx, rotation, size, absoluteImageSize),
                      translateY(point.dy, rotation, size, absoluteImageSize),
                    ),
                    1,
                    paint);
              }
            }
          }

          void paintLandmark(FaceLandmarkType type) {
            final landmarkContour = face.landmarks[type];
            // print(landmarkContour.toString());
            Offset? pos = landmarkContour?.position;
            if (pos != null) {
              canvas.drawCircle(
                Offset(
                  translateX(pos.dx, rotation, size, absoluteImageSize),
                  translateY(pos.dy, rotation, size, absoluteImageSize),
                ),
                1,
                paint);
            }
          }

          paintLandmark(FaceLandmarkType.leftEye);
          paintContour(FaceContourType.face);
          // paintContour(FaceContourType.leftEyebrowTop);
          // paintContour(FaceContourType.leftEyebrowBottom);
          // paintContour(FaceContourType.rightEyebrowTop);
          // paintContour(FaceContourType.rightEyebrowBottom);
          paintContour(FaceContourType.leftEye);
          paintContour(FaceContourType.rightEye);
          // paintContour(FaceContourType.upperLipTop);
          // paintContour(FaceContourType.upperLipBottom);
          // paintContour(FaceContourType.lowerLipTop);
          // paintContour(FaceContourType.lowerLipBottom);
          // paintContour(FaceContourType.noseBridge);
          // paintContour(FaceContourType.noseBottom);
          // paintContour(FaceContourType.leftCheek);
          // paintContour(FaceContourType.rightCheek);
        }
        
      }
      
    }

    for (final textBlock in recognizedText.blocks) {
      bool check = _check(textBlock.rect.left, textBlock.rect.top, textBlock.rect.right, textBlock.rect.bottom);

      if(check){
        final ParagraphBuilder builder = ParagraphBuilder(
          ParagraphStyle(
              textAlign: TextAlign.left,
              fontSize: 16,
              textDirection: TextDirection.ltr),
        );
        builder.pushStyle(
            ui.TextStyle(color: Colors.lightGreenAccent, background: background));
        builder.addText(textBlock.text);
        builder.pop();

        final left =
            translateX(textBlock.rect.left, rotation, size, absoluteImageSize);
        final top =
            translateY(textBlock.rect.top, rotation, size, absoluteImageSize);
        final right =
            translateX(textBlock.rect.right, rotation, size, absoluteImageSize);
        final bottom =
            translateY(textBlock.rect.bottom, rotation, size, absoluteImageSize);

        canvas.drawRect(
          Rect.fromLTRB(left, top, right, bottom),
          paint,
        );

        canvas.drawParagraph(
          builder.build()
            ..layout(ParagraphConstraints(
              width: right + left,
            )),
          Offset(left, top),
        );

        if(
          (textBlock.text.contains("HONG KONG") && textBlock.text.contains("CARD") && _checkLeftTop(textBlock.rect.left)) 
        ){
          hitInfo["left"] = textBlock.rect.left;
          hitInfo["top"] = textBlock.rect.top;
          // if(textBlock.text.contains("HONG KONG")){
          //   hitInfo["top"] = true;
          // }else{
          //   hitInfo["top"] = false;
          // }
          hitCheckCount++;
        }

        if(((textBlock.text.contains(RegExp(r"([A-Z][0-9][0-9][0-9][0-9][0-9][0-9]+)([ ]+)([(][A-Z-0-9][)])")) || textBlock.text.contains(RegExp(r"([A-Z][0-9][0-9][0-9][0-9][0-9][0-9]+)([(][A-Z-0-9][)])"))) && textBlock.rect.left > size.width/2)){
          hitInfo["right"] = textBlock.rect.right;
          hitInfo["bottom"] = textBlock.rect.bottom;
          hitCheckCount++;
        }
      }
      
    }

    if(hitCheckCount >= 3){
      hitInfo["count"]++;
    }else{
      hitInfo["count"] = 0;
    }
    // print("hitCheckCount => " + hitCheckCount.toString());

    if(hitInfo["count"] > 1){
      _takePhoto();
    }
    // stderr.writeln('print me');
    // developer.log("hitCheckCount => " + hitCheckCount.toString(), name: 'my.other.category');
    developer.log("hitCorrectCount => " + hitInfo.toString(), name: 'my.other.category');
    // print("hitCheckCount = hitCorrectCount => " + hitCorrectCount.toString());
  }

  @override
  bool shouldRepaint(FaceDetectorPainter oldDelegate) {
    return oldDelegate.absoluteImageSize != absoluteImageSize ||
        oldDelegate.faces != faces;
  }
}
