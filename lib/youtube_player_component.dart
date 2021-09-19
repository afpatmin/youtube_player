import 'dart:async';
import 'dart:html';
import 'dart:js';

import 'package:angular/angular.dart';
import 'package:fo_components/components/fo_icon/fo_icon_component.dart';

typedef YoutubeCallback = void Function(JsObject event);

@Component(
  selector: 'youtube-player',
  styleUrls: ['youtube_player_component.css'],
  templateUrl: 'youtube_player_component.html',
  directives: [FoIconComponent, NgIf],
  changeDetection: ChangeDetectionStrategy.OnPush,
)
class YouTubePlayerComponent implements AfterViewInit, OnDestroy {
  final ChangeDetectorRef _changeDetectorRef;
  static int _index = 0;
  late int playerIndex;
  final int maxRetries = 20;

  final StreamController<String> _onStateChangeController = StreamController();
  JsObject? _player;
  String? _videoId;

  String? get videoId => _videoId;

  @Input('videoId')
  set videoId(String? value) {
    if (value != _videoId) {
      _videoId = value;
      _player?.callMethod('cueVideoById', [_videoId]);
    }
  }

  @Input()
  bool autoplay = false;

  bool playing = false;
  bool started = false;

  YouTubePlayerComponent(this._changeDetectorRef) {
    _index++;
    playerIndex = _index;
  }

  JsObject get params {
    final vars = <String, String>{};
    vars['autoplay'] = autoplay ? '1' : '0';
    vars['color'] = 'red';
    vars['controls'] = '0';
    vars['disabledkb'] = '0'; // Disable keyboard
    vars['enablejsapi'] = '1';
    vars['fs'] = '1'; // Show fullscreen option
    vars['loop'] = '0'; // Loop video
    vars['modestbranding'] = '1'; // Show minimal youtube branding
    vars['rel'] = '1'; // Suggested videos are related
    vars['origin'] = Uri.base.origin;
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
    try {
      _player?.callMethod('destroy');
    } catch (e) {
      print(e);
    }
    _onStateChangeController.close();
  }

  @override
  void ngAfterViewInit() async {
    playing = autoplay;
    started = autoplay;

    if (document.head!.querySelector('#fo-youtube') == null) {
      document.head!.children.add(ScriptElement()
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
      playing = false;
      Future.delayed(const Duration(milliseconds: 400)).then((_) {
        _player?.callMethod('pauseVideo');
        _changeDetectorRef.markForCheck();
      });
    } else {
      _player?.callMethod('playVideo');
      Future.delayed(const Duration(milliseconds: 400)).then((_) {
        playing = true;
        started = true;
        _changeDetectorRef.markForCheck();
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
