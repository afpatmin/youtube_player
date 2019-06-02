import 'dart:async';
import 'dart:html';
import 'dart:js';

import 'package:angular/angular.dart';
import 'package:angular_components/material_icon/material_icon.dart';

typedef YoutubeCallback = void Function(JsObject event);

@Component(
    selector: 'youtube-player',
    styleUrls: ['youtube_player_component.css'],
    templateUrl: 'youtube_player_component.html',
    directives: [MaterialIconComponent, NgIf])
class YouTubePlayerComponent implements AfterViewInit, OnDestroy {
  static int _index = 0;
  int playerIndex;
  final int maxRetries = 20;

  final StreamController<String> _onStateChangeController = StreamController();
  JsObject _player;
  String _videoId;

  String get videoId => _videoId;

  @Input('videoId')
  set videoId(String value) {
    if (value != _videoId) {
      _videoId = value;
      if (_player != null) {
        _player.callMethod('cueVideoById', [_videoId]);
      }
    }
  }

  @Input()
  bool autoplay = false;

  bool playing = false;

  bool started = false;

  YouTubePlayerComponent() {
    _index++;
    playerIndex = _index;
  }

  JsObject get params {
    final vars = <String, String>{};
    vars['fs'] = '1';
    vars['rel'] = '0'; // Show related videos at the end of playback
    vars['modestbranding'] = '0'; // Show minimal youtube branding
    vars['showinfo'] = '1';
    vars['origin'] = Uri.base.origin;
    vars['enablejsapi'] = '1';
    vars['autoplay'] = autoplay ? '1' : '0';
    vars['controls'] = '0';
    final events = <String, YoutubeCallback>{};
    events['onReady'] = _onReady;
    events['onStateChange'] = _onStateChange;
    final params = <String, dynamic>{};
    params['videoId'] = videoId;
    params['playerVars'] = vars;
    params['events'] = events;

    return JsObject.jsify(params);
  }

  @Output('stateChange')
  Stream<String> get stateChangeOutput => _onStateChangeController.stream;

  @override
  void ngOnDestroy() {
    _player.callMethod('destroy');
    _onStateChangeController.close();
  }

  @override
  void ngAfterViewInit() async {
    playing = autoplay;
    started = autoplay;

    if (document.head.querySelector('#fo-youtube') == null) {
      document.head.children.add(ScriptElement()
        ..src = 'https://www.youtube.com/iframe_api'
        ..id = 'fo-youtube');
      context['onYouTubeIframeAPIReady'] = _createPlayer;
    } else {
      for (var i = 0; i < maxRetries; i++) {
        await Future.delayed(const Duration(milliseconds: 10));
        try {
          return _createPlayer();
        } catch (e) {
          print(e);
          print('Youtube API not loaded, retrying ($i)');
        }
      }
    }
  }

  void onTouch() {
    if (playing) {
      _player.callMethod('pauseVideo');
      playing = false;
    } else {
      _player.callMethod('playVideo');
      Future.delayed(Duration(milliseconds: 200)).then((_) {
        playing = true;
      });
    }
  }

  void _createPlayer() {
    // Youtube API is ready, initialize video
    _player =
        JsObject(context['YT']['Player'], ['player-$playerIndex', params]);
  }

  void _onReady(JsObject event) {}
  void _onStateChange(JsObject event) {
    if (_player == null) return;
    switch (event['data']) {
      case -1:
        _onStateChangeController.add('Start');
        started = true;
        break;

      case 0:
        _onStateChangeController.add('End');
        playing = false;
        break;

      case 1:
        _onStateChangeController.add('Play');
        break;

      case 2:
        _onStateChangeController.add('Pause');
        break;

      case 3:
        _onStateChangeController.add('Navigate');
        break;

      default:
        break;
    }
  }
}
