import 'dart:io';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'dart:ui' as ui;
import 'expandable_fab.dart';
import 'package:intl/intl.dart';


void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
        snackBarTheme: const SnackBarThemeData(
          actionTextColor: Colors.blueAccent,
          backgroundColor: Color.fromARGB(255, 100, 100, 100),
          contentTextStyle: TextStyle(
            color: Colors.white
          )
        ),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  List<LinePoints> lines = <LinePoints>[];
  List<LinePoints> undoLines = <LinePoints>[];
  List<Offset> nowPoints = <Offset>[];
  List<Offset> queuePoints = <Offset>[];
  Offset? startPoint;
  Color nowColor = Colors.redAccent;
  bool isDrawing = false;
  bool isOldDrawing = false;
  bool showPallet = true;
  ui.Image? image;

  // ジェスチャー移動を検知
  void moveGestureDetector(Offset localPosition){
    if (!isDrawing) {
      return;
    }
    Offset p = Offset(localPosition.dx, localPosition.dy);
    if (isOldDrawing) {
      queuePoints.add(p);
    } else {
      setState(() {
        if (queuePoints.isNotEmpty) {
          nowPoints.addAll(queuePoints);
          queuePoints.clear();
        }
        nowPoints.add(p);
      });
    }
  }

  // 描画開始イベント
  Future<void> newGestureDetector(Offset globalPosition, Offset localPosition) async {
    int margin = 20;
    // 画面上下端からのスタートは無視する
    if (globalPosition.dy < margin
        || globalPosition.dy > (MediaQuery.of(context).size.height - margin)) {
      isDrawing = false;
      return;
    }
    isDrawing = true;
    isOldDrawing = true;
    if (nowPoints.isNotEmpty) {
      LinePoints l = LinePoints(List<Offset>.from(nowPoints), nowColor);
      lines.add(l);
      await setOldImage();
      nowPoints.clear();
    }
    Offset p = Offset(localPosition.dx, localPosition.dy);
    setState(() {
      undoLines.clear();
      queuePoints.add(p);
    });
    isOldDrawing = false;
  }

  // 線を Image にして保存
  Future<void> setOldImage() async{
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final p = Paint()
      ..isAntiAlias = true
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5.0;
    if (image != null) {
      canvas.drawImage(image!, const Offset(0, 0), p);
    }
    for (int i = 1; i < nowPoints.length; i++){
      Offset p1 = nowPoints[i - 1];
      Offset p2 = nowPoints[i];
      p.color = nowColor;
      canvas.drawLine(p1, p2, p);
    }

    final picture = recorder.endRecording();
    int w = MediaQuery.of(context).size.width.toInt();
    int h = MediaQuery.of(context).size.height.toInt();
    ui.Image tmp = await picture.toImage(w, h);
    setState(() {
      image = tmp;
    });
  }

  // undo, redo 用に全て描き直し
  Future<void> setAllImage() async{
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final p = Paint()
      ..isAntiAlias = true
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5.0;

    for (int i = 0; i < lines.length; i++) {
      LinePoints l = lines[i];
      for (int j = 1; j < l.points.length; j++){
        Offset p1 = l.points[j - 1];
        Offset p2 = l.points[j];
        p.color = l.lineColor;
        canvas.drawLine(p1, p2, p);
      }
    }

    final picture = recorder.endRecording();
    int w = MediaQuery.of(context).size.width.toInt();
    int h = MediaQuery.of(context).size.height.toInt();
    ui.Image tmp = await picture.toImage(w, h);
    setState(() {
      image = tmp;
    });
  }

  // 色変更
  Future<void> changeColor (Color c) async{
    if (nowPoints.isNotEmpty) {
      LinePoints l = LinePoints(List<Offset>.from(nowPoints), nowColor);
      lines.add(l);
      await setOldImage();
    }
    setState(() {
      nowPoints.clear();
      nowColor = c;
    });
  }

  List<MaterialAccentColor> colors = Colors.accents;

  // 描画を全てクリアする
  void _tapClear(){
    setState(() {
      image = null;
      lines.clear();
      nowPoints.clear();
      undoLines.clear();
    });
  }

  // 描画リストから取り除き、取り除いたものリストへ入れる
  Future<void> _undo() async{
    if (nowPoints.isNotEmpty) {
      LinePoints l = LinePoints(List<Offset>.from(nowPoints), nowColor);
      setState(() {
        undoLines.add(l);
        nowPoints.clear();
      });
      await setAllImage();
      return;
    }
    if (lines.isEmpty) {
      return;
    }
    setState(() {
      undoLines.add(lines.last);
      lines.removeLast();
    });
    await setAllImage();
  }

  // 取り除いたものリストから描画リストへセット
  Future<void>  _redo() async{
    if (undoLines.isEmpty) {
      return;
    }
    setState(() {
      lines.add(undoLines.last);
      undoLines.removeLast();
    });
    await setAllImage();
  }

  // 画面上部のパレットを出すかどうか
  void _showPallet(){
    setState((){
      showPallet = !showPallet;
    });
  }

  // 描画データがあるかどうか
  // 保存ボタンと削除ボタンの有効無効判定
  bool isWriteData(){
    return lines.isNotEmpty || nowPoints.isNotEmpty || undoLines.isNotEmpty;
  }

  // Undo できるかどうか
  bool canUndo() {
    return lines.isNotEmpty || nowPoints.isNotEmpty;
  }

  // Redo できるかどうか
  bool canRedo(){
    return undoLines.isNotEmpty;
  }

  // 画像を local に保存する
  Future<void> _saveImage() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(Colors.white, BlendMode.src);
    final p = Paint()
      ..isAntiAlias = true
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5.0;
    for (int i = 0; i < lines.length; i++) {
      LinePoints l = lines[i];
      for (int j = 1; j < l.points.length; j++){
        Offset p1 = l.points[j - 1];
        Offset p2 = l.points[j];
        p.color = l.lineColor;
        canvas.drawLine(p1, p2, p);
      }
    }
    for (int i = 1; i < nowPoints.length; i++){
      Offset p1 = nowPoints[i - 1];
      Offset p2 = nowPoints[i];
      p.color = nowColor;
      canvas.drawLine(p1, p2, p);
    }

    final picture = recorder.endRecording();
    int w = MediaQuery.of(context).size.width.toInt();
    int h = MediaQuery.of(context).size.height.toInt();
    final image = await picture.toImage(w, h);
    DateTime now = DateTime.now();
    DateFormat outputFormat = DateFormat('yyyy-MM-dd_hh-mm-ss');
    String fileName = "${outputFormat.format(now)}.png";
    if (Platform.isAndroid) {
      await _saveAndroid(fileName, image);
    } else {
      await _saveIos(fileName, image);
    }
  }

  // Android 用の保存処理
  Future<void> _saveAndroid(String fileName, ui.Image image) async {
    final directory = await path_provider.getTemporaryDirectory();
    final filePath = path.join(directory.path, fileName);

    final byteData = await image.toByteData(format: ImageByteFormat.png);
    final buffer = byteData!.buffer;

    File tempFile = await File(filePath)
        .writeAsBytes(buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
    await _saveFileToMediaStore(tempFile, fileName);
    await tempFile.delete();
  }

  // iOS 用の保存処理
  Future<void> _saveIos(String fileName, ui.Image image) async {
    final directory = await path_provider.getApplicationDocumentsDirectory();
    final filePath = path.join(directory.path, fileName);

    final byteData = await image.toByteData(format: ImageByteFormat.png);
    final buffer = byteData!.buffer;

    await File(filePath)
        .writeAsBytes(buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
  }

  // Android でメディアストアへ書き込み
  Future<void> _saveFileToMediaStore(File file, String fileName) async {
    final mediaStore = MediaStore();
    await mediaStore.addItem(file: file, name: fileName);
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> pallet = <Widget>[];
    for (int i = 0; i < colors.length; i++) {
      Color c = colors[i];
      pallet.add(ColorPallet(color: c,changeColor: changeColor,isSelect: c==nowColor,));
    }

    return Scaffold(
      primary: false,
      body: Container(
        decoration: const BoxDecoration(
            color: Colors.white
        ),
        child:Stack(
          children:<Widget>[
            Flex(
              direction: Axis.vertical,
              children: <Widget>[
                Expanded(
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width,
                      child: GestureDetector(
                        onPanDown: (DragDownDetails details){
                          newGestureDetector(details.globalPosition, details.localPosition);
                        },
                        onPanUpdate: (DragUpdateDetails details){
                          moveGestureDetector(details.localPosition);
                        },
                        child: CustomPaint(
                          painter: PaintCanvas(lines,nowPoints,nowColor,image),
                        ),
                      ),
                    )
                ),
              ],
            ),
            SafeArea(child:
              Visibility(
                visible: showPallet,
                child:Container(
                  decoration:const BoxDecoration(
                      color: Colors.black26
                  ),
                  height: 70.0,
                  width: MediaQuery.of(context).size.width,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: pallet,
                  ),
                ),
            )),

          ],
        ),
      ),
      floatingActionButton: ExpandableFab(
        distance: 150.0,
        children: [
          ActionButton(
            onPressed: () {
              if (!isWriteData()) {
                return;
              }
              _tapClear();
            },
            icon: const Icon(Icons.delete),
            enabled: isWriteData(),
          ),
          ActionButton(
            onPressed: () {
              if (!isWriteData()) {
                return;
              }
              _saveImage();
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('保存しました'),
                    duration: const Duration(seconds: 5),
                    action: SnackBarAction(
                      label: 'OK',
                      onPressed: () {},
                    ),
                  )
              );
            },
            icon: const Icon(Icons.save_alt),
            enabled: isWriteData(),
          ),
          ActionButton(
            onPressed: _undo,
            icon: const Icon(Icons.undo),
            enabled: canUndo(),
          ),
          ActionButton(
            onPressed: _redo,
            icon: const Icon(Icons.redo),
            enabled: canRedo(),
          ),
          ActionButton(
            onPressed: _showPallet,
            icon: Icon(showPallet ? Icons.color_lens_sharp : Icons.color_lens_outlined),
            enabled: true,
          ),
        ],
      ),
    );
  }
}

// 実際に描画するキャンバス
class PaintCanvas extends CustomPainter{

  final List<LinePoints> lines;
  final List<Offset> nowPoints;
  final Color nowColor;
  final ui.Image? image;

  PaintCanvas(this.lines, this.nowPoints, this.nowColor, this.image);

  @override
  void paint(Canvas canvas, Size size) {
    Paint p = Paint()
      ..isAntiAlias = true
      ..color = Colors.redAccent
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5.0;

    if (image != null) {
      canvas.drawImage(image!, const Offset(0, 0), p);
    }
    for (int i = 1; i < nowPoints.length; i++){
      Offset p1 = nowPoints[i - 1];
      Offset p2 = nowPoints[i];
      p.color = nowColor;
      canvas.drawLine(p1, p2, p);
    }
  }
  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}

// 一筆書き分の座標を持つClass
class LinePoints{
  final List<Offset> points;
  final Color lineColor;
  LinePoints(this.points, this.lineColor);
}

// 色を変えるボタンClass
class ColorPallet extends StatelessWidget {
  final Color color;
  final Function changeColor;
  const ColorPallet({Key? key, required this.color, required this.changeColor, required this.isSelect}) : super(key: key);
  final bool isSelect;

  void onPressed(){
    changeColor(color);
  }

  @override
  Widget build(BuildContext context) {
    return RawMaterialButton(
        onPressed: onPressed,
        constraints: const BoxConstraints(minWidth: 85.0,minHeight: 80.0),
        child: Container(
          margin: const EdgeInsets.only(top: 5.0,bottom: 5.0),
          width: 80.0,
          height: 80.0,
          decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.all(Radius.circular(40.0)),
              border: Border.all(color: Colors.white,width: isSelect?4.0:0.0)
          ),
        )) ;
  }
}

// Androidネイティブを呼び出す
class MediaStore {
  static const _channel = MethodChannel('flutter_media_store');

  Future<void> addItem({required File file, required String name}) async {
    await _channel.invokeMethod('addItem', {'path': file.path, 'name': name});
  }
}