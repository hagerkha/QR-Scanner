import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:zxing2/qrcode.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:device_preview/device_preview.dart';

void main() => runApp(
  DevicePreview(
    enabled: !kReleaseMode,
    builder: (context) => MyApp(), // Wrap your app
  ),
);

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentTheme, child) {
        return MaterialApp(
          locale: DevicePreview.locale(context), // Add the locale here
          builder: DevicePreview.appBuilder, // Add the builder here
          debugShowCheckedModeBanner: false,
          title: 'QR Scanner ',
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: currentTheme,
          home: MyHomePage(),
        );
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _result = "Scan Result will appear here";
  Uint8List? _imageBytes;
  final ImagePicker _picker = ImagePicker();

  Future<void> _scanFromFile() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        if (kIsWeb) {
          // Handle web case
          image.readAsBytes().then((bytes) {
            setState(() {
              _imageBytes = Uint8List.fromList(bytes);
            });
            _processImage(Uint8List.fromList(bytes));
          });
        } else {
          // Handle mobile/desktop case
          File file = File(image.path);
          final imageBytes = file.readAsBytesSync();
          setState(() {
            _imageBytes = imageBytes;
          });
          _processImage(imageBytes);
        }
      });
    }
  }

  void _processImage(Uint8List imageBytes) {
    final img.Image? imageDecoded = img.decodeImage(imageBytes);
    if (imageDecoded != null) {
      final luminanceSource = RGBLuminanceSource(imageDecoded.width, imageDecoded.height, _createInt32List(imageDecoded));
      final binaryBitmap = BinaryBitmap(HybridBinarizer(luminanceSource));
      final reader = QRCodeReader();

      try {
        final result = reader.decode(binaryBitmap);
        setState(() {
          _result = result.text ?? 'Could not scan the QR code from the image';
        });
        if (_isValidUrl(_result)) {
          _launchURL(_result);
        }
      } catch (e) {
        setState(() {
          _result = 'Error decoding QR code: $e';
        });
      }
    } else {
      setState(() {
        _result = 'Could not decode the image';
      });
    }
  }

  bool _isValidUrl(String url) {
    return Uri.tryParse(url)?.hasAbsolutePath ?? false;
  }

  void _launchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      setState(() {
        _result = 'Could not launch the URL';
      });
    }
  }

  Int32List _createInt32List(img.Image image) {
    final pixels = image.getBytes();
    final int32List = Int32List(image.width * image.height);
    for (int i = 0, j = 0; i < pixels.length; i += 4, j++) {
      final a = pixels[i];
      final r = pixels[i + 1];
      final g = pixels[i + 2];
      final b = pixels[i + 3];
      int32List[j] = (a << 24) | (r << 16) | (g << 8) | b;
    }
    return int32List;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("QR Scanner Example In Flutter"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            Expanded(
              flex: 2,
              child: Center(
                child: _imageBytes != null
                    ? Image.memory(_imageBytes!)
                    : Text('No image selected'),
              ),
            ),
            Expanded(
              flex: 1,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _result,
                      style: TextStyle(fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _scanFromFile,
                      child: Text('Scan from Gallery'),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        textStyle: TextStyle(fontSize: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
