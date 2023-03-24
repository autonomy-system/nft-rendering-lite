//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';

// ignore: depend_on_referenced_packages
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';
import 'package:webviewx/webviewx.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class RenderingType {
  static const image = 'image';
  static const svg = 'svg';
  static const gif = 'gif';
  static const audio = 'audio';
  static const video = 'video';
  static const pdf = 'application/pdf';
  static const webview = 'webview';
  static const modelViewer = 'modelViewer';
}

class RenderingPayload {
  final String renderingType;
  final String thumbnailURL;
  final String previewUrl;
  String? overriddenHtml;

  final Widget loadingWidget;
  final Widget errorWidget;
  final Function({int? time})? onLoaded;

  RenderingPayload({
    required this.renderingType,
    required this.thumbnailURL,
    required this.previewUrl,
    this.loadingWidget = const Center(child: CircularProgressIndicator()),
    this.errorWidget = const Center(child: Icon(Icons.error)),
    this.onLoaded,
    this.overriddenHtml,
  });
}

abstract class ArtworkRendering extends Widget {
  factory ArtworkRendering({
    required RenderingPayload renderingPayload,
  }) {
    switch (renderingPayload.renderingType) {
      case RenderingType.gif:
      case RenderingType.image:
        return ImageRendering(renderingPayload: renderingPayload);
      case RenderingType.svg:
        return WebviewRendering(renderingPayload: renderingPayload);
      case RenderingType.audio:
        return AudioRendering(renderingPayload: renderingPayload);
      case RenderingType.video:
        return VideoRendering(renderingPayload: renderingPayload);
      case RenderingType.pdf:
        return PDFRendering(renderingPayload: renderingPayload);
      case RenderingType.webview:
        return WebviewRendering(renderingPayload: renderingPayload);

      case RenderingType.modelViewer:
        return const UnsupportedRendering();
      default:
        return WebviewRendering(renderingPayload: renderingPayload);
    }
  }
}

class ImageRendering extends StatefulWidget implements ArtworkRendering {
  final RenderingPayload renderingPayload;

  const ImageRendering({
    Key? key,
    required this.renderingPayload,
  }) : super(key: key);

  @override
  State<ImageRendering> createState() => _ImageRenderingState();
}

class _ImageRenderingState extends State<ImageRendering> {
  @override
  Widget build(BuildContext context) {
    return Image.network(
      widget.renderingPayload.previewUrl,
      cacheHeight: 1000,
      cacheWidth: 1000,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress != null &&
            loadingProgress.expectedTotalBytes ==
                loadingProgress.cumulativeBytesLoaded) {
          widget.renderingPayload.onLoaded?.call();
        }
        if (loadingProgress == null) return child;
        return widget.renderingPayload.loadingWidget;
      },
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          child: child,
        );
      },
      errorBuilder: (context, error, stackTrace) =>
          widget.renderingPayload.errorWidget,
    );
  }
}

class AudioRendering extends StatefulWidget implements ArtworkRendering {
  final RenderingPayload renderingPayload;

  const AudioRendering({
    Key? key,
    required this.renderingPayload,
  }) : super(key: key);

  @override
  State<AudioRendering> createState() => _AudioRenderingState();
}

class _AudioRenderingState extends State<AudioRendering> {
  late AudioPlayer? _player;

  final _progressStreamController = StreamController<double>();

  @override
  void initState() {
    super.initState();
    _playAudio(widget.renderingPayload.previewUrl);
  }

  @override
  void dispose() {
    super.dispose();
    _progressStreamController.close();
    _player?.dispose();
  }

  Future _playAudio(String audioURL) async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      _player = AudioPlayer();
      _player?.positionStream.listen((event) {
        final progress =
            event.inMilliseconds / (_player?.duration?.inMilliseconds ?? 1);
        _progressStreamController.sink.add(progress);
      });
      widget.renderingPayload.onLoaded?.call(
        time: _player?.duration?.inSeconds,
      );

      await _player?.setAudioSource(AudioSource.uri(Uri.parse(audioURL)));
      await _player?.play();
    } catch (e) {
      // print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Image.network(
            widget.renderingPayload.thumbnailURL,
            errorBuilder: (context, error, stackTrace) =>
                widget.renderingPayload.errorWidget,
            loadingBuilder: (context, child, loadingProgress) =>
                widget.renderingPayload.loadingWidget,
          ),
        ),
        StreamBuilder<double>(
          stream: _progressStreamController.stream,
          builder: (context, snapshot) {
            return LinearProgressIndicator(
              value: snapshot.data ?? 0,
              color: Colors.white,
              backgroundColor: Colors.black,
            );
          },
        ),
      ],
    );
  }
}

class VideoRendering extends StatefulWidget implements ArtworkRendering {
  final RenderingPayload renderingPayload;

  const VideoRendering({Key? key, required this.renderingPayload})
      : super(key: key);

  @override
  State<VideoRendering> createState() => _VideoRenderingState();
}

class _VideoRenderingState extends State<VideoRendering> {
  late VideoPlayerController _controller;
  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(
      widget.renderingPayload.previewUrl,
    );
    _controller.initialize().then((value) {
      setState(() {});
      widget.renderingPayload.onLoaded?.call(
        time: _controller.value.duration.inSeconds,
      );
      _controller.play();
      _controller.setLooping(true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _controller.value.isInitialized
        ? AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          )
        : widget.renderingPayload.loadingWidget;
  }
}

class PDFRendering extends StatefulWidget implements ArtworkRendering {
  final RenderingPayload renderingPayload;
  const PDFRendering({Key? key, required this.renderingPayload})
      : super(key: key);

  @override
  State<PDFRendering> createState() => _PDFRenderingState();
}

class _PDFRenderingState extends State<PDFRendering> {
  bool _isLoading = true;
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SfPdfViewer.network(
          widget.renderingPayload.previewUrl,
          key: Key(widget.renderingPayload.previewUrl),
          onDocumentLoaded: (_) {
            widget.renderingPayload.onLoaded?.call();
            setState(() {
              _isLoading = false;
            });
          },
          onDocumentLoadFailed: (error) {
            widget.renderingPayload.onLoaded?.call();
            setState(() {
              _isLoading = false;
            });
          },
        ),
        if (_isLoading) widget.renderingPayload.loadingWidget,
      ],
    );
  }
}

class WebviewRendering extends StatefulWidget implements ArtworkRendering {
  final RenderingPayload renderingPayload;
  const WebviewRendering({Key? key, required this.renderingPayload})
      : super(key: key);

  @override
  State<WebviewRendering> createState() => _WebviewRenderingState();
}

class _WebviewRenderingState extends State<WebviewRendering> {
  late WebViewXController webviewController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    return Stack(
      children: [
        WebViewX(
          initialContent: widget.renderingPayload.overriddenHtml != null
              ? 'about:blank'
              : widget.renderingPayload.previewUrl,
          onWebViewCreated: (controller) {
            webviewController = controller;
            if (widget.renderingPayload.overriddenHtml != null) {
              controller.loadContent(
                widget.renderingPayload.overriddenHtml!,
                SourceType.html,
              );
            }
          },
          navigationDelegate: (navigation) {
            return NavigationDecision.prevent;
          },
          onPageFinished: (src) {
            widget.renderingPayload.onLoaded?.call();
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (error) {
            setState(() {
              _isLoading = false;
            });
          },
          height: height,
          width: width,
        ),
        Visibility(
          visible: _isLoading,
          child: widget.renderingPayload.loadingWidget,
        ),
      ],
    );
  }
}

class UnsupportedRendering extends StatelessWidget implements ArtworkRendering {
  const UnsupportedRendering({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final widthRatio = MediaQuery.of(context).size.width / 1920;
    final heightRatio = MediaQuery.of(context).size.height / 1080;

    return SizedBox(
      width: widthRatio * 375,
      height: heightRatio * 375,
      child: Center(
        child: Stack(
          children: [
            Image.asset("assets/images/unsupported_token.png"),
            Container(
              padding: EdgeInsets.all(widthRatio * 20.0),
              child: Align(
                alignment: AlignmentDirectional.topStart,
                child: Text(
                  "UNSUPPORTED TOKEN",
                  style: TextStyle(
                      color: const Color(0xff6d6b6b),
                      fontFamily: "IBMPlexMono",
                      fontWeight: FontWeight.w400,
                      fontSize: widthRatio * 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
