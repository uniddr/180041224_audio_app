import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Audioplayer',
      theme: ThemeData(
        primarySwatch: Colors.amber,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => DirSelect(),
        MyHomePage.routeName: (context) => MyHomePage()
      },
    );
  }
}

class listarg {
  final String? pathName;

  listarg(this.pathName);
}

class AudioMetadata {
  final String title;

  AudioMetadata({required this.title});
}

Future<String?> _selectfolder() async {
  try {
    String? selectDir = await FilePicker.platform.getDirectoryPath();
    return selectDir;
  } catch (e) {}
  return null;
}

class DirSelect extends StatefulWidget {
  const DirSelect({Key? key}) : super(key: key);

  @override
  State<DirSelect> createState() => _DirSelectState();
}

class _DirSelectState extends State<DirSelect> {
  String? pickresult;

  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('DDR Audio Player'),
        ),
        body: Builder(builder: (BuildContext context) {
          return Container(
            color: Colors.brown[800],
            child: Center(
              child: ElevatedButton(
                  onPressed: () async {
                    //
                    pickresult = await _selectfolder();
                    pickresult == null
                        ? ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(
                            content: Text(
                                'Couldn\'t find your files! Please make sure to select the folder where they are stored!'),
                            duration: Duration(seconds: 3),
                          ))
                        : Navigator.pushNamed(context, MyHomePage.routeName,
                            arguments: listarg(pickresult!));
                  },
                  child: const Text('Select your audio folder')),
            ),
          );
        }));
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  final String title = 'List of Audio Files';
  static const routeName = '/audiolist';

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<FileSystemEntity> listFiles = [];
  final _player = AudioPlayer();
  var args = listarg("");

  Future<void> _makeList(BuildContext context) async {
    args = ModalRoute.of(context)?.settings.arguments as listarg;
    String name = args.pathName!;
    var dir = Directory(name);
    listFiles.clear();
    await dir.list(recursive: true).forEach((element) {
      RegExp regExp = new RegExp("\.(mp3|wav|m4a)", caseSensitive: false);
      print(
          'dir contains: $element is playable media? ${regExp.hasMatch('$element')}');
      // Only add in List if file in path is supported
      if (element is File && regExp.hasMatch('$element')) {
        listFiles.add(element);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Inform the operating system of our app's audio attributes etc.
    // We pick a reasonable default for an app that plays speech.
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    // Listen to errors during playback.
    _player.playbackEventStream.listen((event) {},
        onError: (Object e, StackTrace stackTrace) {
      print('A stream error occurred: $e');
    });
    try {
      // await _player.setAudioSource(AudioSource.uri(Uri.file(
      //     listFiles[0].path), tag: AudioMetadata(title: basenameWithoutExtension(listFiles[0].path))));
    } catch (e) {
      print("Error loading audio source: $e");
    }
  }

  @override
  void dispose() {
    // Release decoders and buffers back to the operating system making them
    // available for other apps to use.
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: Colors.black),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
        body: FutureBuilder(
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error encountered : ${snapshot.error}',
                    style: TextStyle(fontSize: 18),
                  ),
                );
              } else {
                return Column(
                  children: [
                    Expanded(
                      flex: 7,
                      child: Container(
                        color: Colors.brown[800],
                        child: ListView.separated(
                          separatorBuilder: (BuildContext context, int index) {
                            return Divider(
                              height: 1,
                              thickness: 3,
                              color: Colors.amber[500],
                            );
                          },
                            itemCount: listFiles.length,
                            itemBuilder: (context, index) {
                              final item = listFiles[index];

                              return Container(
                                color: Colors.brown[400],
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // ignore: prefer_const_constructors
                                    Flexible(
                                      flex: 50,
                                      fit: FlexFit.tight,
                                      child: Text(" ${basename(item.path)}",
                                          style: const TextStyle(
                                              color: Colors.black,
                                              overflow: TextOverflow.ellipsis,
                                              fontWeight: FontWeight.w500,
                                              fontSize: 18)),
                                    ),
                                    const Spacer(
                                      flex: 1,
                                    ),
                                    StreamBuilder<PlayerState>(
                                      stream: _player.playerStateStream,
                                      builder: (context, snapshot) {
                                        final playerState = snapshot.data;
                                        final processingState =
                                            playerState?.processingState;
                                        final playing = playerState?.playing;
                                        if (processingState ==
                                                ProcessingState.idle ||
                                            _player.sequenceState?.currentSource
                                                    ?.tag.title !=
                                                basenameWithoutExtension(
                                                    item.path)) {
                                          return ElevatedButton(
                                            style: ButtonStyle(
                                              minimumSize: MaterialStateProperty.all(Size(28.0, 35.0)),
                                                backgroundColor:
                                                    MaterialStateProperty.all(
                                                        Colors.white54)),
                                            onPressed: () async {
                                              await _player.setAudioSource(
                                                  AudioSource.uri(
                                                      Uri.file(item.path),
                                                      tag: AudioMetadata(
                                                          title:
                                                              basenameWithoutExtension(
                                                                  item.path))));
                                              _player.play();
                                            },
                                            child: const Icon(Icons.play_arrow),
                                          );
                                        } else if (processingState ==
                                                ProcessingState.loading ||
                                            processingState ==
                                                ProcessingState.buffering) {
                                          return const CircularProgressIndicator();
                                        } else if (playing != true) {
                                          return ElevatedButton(
                                            style: ButtonStyle(
                                                minimumSize: MaterialStateProperty.all(const Size(28.0, 35.0)),
                                                backgroundColor:
                                                    MaterialStateProperty.all(
                                                        Colors.white54)),
                                            onPressed: () async {
                                              _player.play();
                                            },
                                            child: const Icon(Icons.play_arrow),
                                          );
                                        } else if (processingState !=
                                            ProcessingState.completed) {
                                          return ElevatedButton(
                                            style: ButtonStyle(
                                                minimumSize: MaterialStateProperty.all(const Size(28.0, 35.0)),
                                                backgroundColor:
                                                    MaterialStateProperty.all(
                                                        Colors.white54)),
                                            onPressed: _player.pause,
                                            child: const Icon(Icons.pause),
                                          );
                                        } else {
                                          return ElevatedButton(
                                            style: ButtonStyle(
                                                minimumSize: MaterialStateProperty.all(const Size(28.0, 35.0)),
                                                backgroundColor:
                                                    MaterialStateProperty.all(
                                                        Colors.white54)),
                                            onPressed: () async {
                                              if (_player
                                                      .sequenceState
                                                      ?.currentSource
                                                      ?.tag
                                                      .title ==
                                                  basenameWithoutExtension(
                                                      item.path)) {
                                                _player.seek(Duration.zero);
                                              } else {
                                                await _player.setAudioSource(
                                                    AudioSource.uri(
                                                        Uri.file(item.path),
                                                        tag: AudioMetadata(
                                                            title:
                                                                basenameWithoutExtension(
                                                                    item.path))));
                                                _player.play();
                                              }
                                            },
                                            child: const Icon(Icons.replay),
                                          );
                                        }
                                      },
                                    ),
                                    StreamBuilder<PlayerState>(
                                      stream: _player.playerStateStream,
                                      builder: (context, snapshot) {
                                        final playerState = snapshot.data;
                                        final processingState =
                                            playerState?.processingState;
                                        return Padding(
                                          padding:
                                              const EdgeInsets.only(left: 2.0),
                                          child: ElevatedButton(
                                            style: ButtonStyle(
                                                minimumSize: MaterialStateProperty.all(const Size(28.0, 35.0)),
                                                backgroundColor:
                                                    MaterialStateProperty.all(
                                                        Colors.white54)),
                                            onPressed: () async {
                                              if (_player
                                                          .sequenceState
                                                          ?.currentSource
                                                          ?.tag
                                                          .title ==
                                                      basenameWithoutExtension(
                                                          item.path) &&
                                                  processingState !=
                                                      ProcessingState.completed) {
                                                _player.stop();
                                              }
                                            },
                                            child: const Icon(Icons.stop_sharp),
                                          ),
                                        );
                                      },
                                    ),
                                    const Spacer(
                                      flex: 1,
                                    ),
                                  ],
                                ),
                              );
                            }),
                      ),
                    ),
                    StreamBuilder<PlayerState>(
                      stream: _player.playerStateStream,
                      builder: (context, snapshot) {
                        final playerState = snapshot.data;
                        final playing = playerState?.playing;
                        return Expanded(
                            child: Container(
                              color: Colors.brown[600],
                              padding: const EdgeInsets.all(6.0),
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.start,
                                      children: [
                                        Text(
                                          ("Currently playing: ${(playing == true) ? _player.sequenceState?.currentSource?.tag.title : (' ').toUpperCase()}"),
                                          style: TextStyle(
                                              color: Colors.amber[200], fontSize: 18, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ));
                      },
                    )
                  ],
                );
              }
            }
            return const Center(
              child: CircularProgressIndicator(),
            );
          },
          future: _makeList(context),
        ));
  }
}
