// ******************************************************************************
// Spine Runtimes Software License v2.5
//
// Copyright (c) 2013-2016, Esoteric Software
// All rights reserved.
//
// You are granted a perpetual, non-exclusive, non-sublicensable, and
// non-transferable license to use, install, execute, and perform the Spine
// Runtimes software and derivative works solely for personal or internal
// use. Without the written permission of Esoteric Software (see Section 2 of
// the Spine Software License Agreement), you may not (a) modify, translate,
// adapt, or develop new applications using the Spine Runtimes or otherwise
// create derivative works or improvements of the Spine Runtimes or (b) remove,
// delete, alter, or obscure any trademarks or any copyright, trademark, patent,
// or other intellectual property or proprietary rights notices on or in the
// Software, including any copy thereof. Redistributions in binary or source
// form must include this license and terms.
//
// THIS SOFTWARE IS PROVIDED BY ESOTERIC SOFTWARE "AS IS" AND ANY EXPRESS OR
// IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
// MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
// EVENT SHALL ESOTERIC SOFTWARE BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
// PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES, BUSINESS INTERRUPTION, OR LOSS OF
// USE, DATA, OR PROFITS) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
// IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.
// ******************************************************************************

import 'dart:html';
import 'dart:typed_data';

import 'package:spine_core/spine_core.dart' as core;

typedef core.Texture TextureLoader(ImageElement image);
typedef void ResponseCallback<T>(int status, T data);
typedef void LoadedCallback<T>(String path, T data);

class AssetManager implements core.Disposable {
  final String pathPrefix;
  final TextureLoader textureLoader;
  final Map<String, String> errors = <String, String>{};
  final Map<String, dynamic> _assets = <String, dynamic>{};
  int _toLoad = 0;
  int _loaded = 0;

  AssetManager(this.textureLoader, {this.pathPrefix = ''});

  void loadText(String path,
      {LoadedCallback<String> success, LoadedCallback<String> error}) {
    final String key = pathPrefix + path;
    _toLoad++;

    _downloadText(key, (int status, String data) {
      _assets[key] = data;
      _toLoad--;
      _loaded++;
      if (success != null) success(path, data);
    }, (int status, String responseText) {
      final String msg =
          'Couldn\'t load text $path: status $status, $responseText';
      errors[path] = msg;
      _toLoad--;
      _loaded++;
      if (error != null) error(path, msg);
    });
  }

  void loadTexture(String path,
      {LoadedCallback<ImageElement> success, LoadedCallback<String> error}) {
    final String key = pathPrefix + path;
    _toLoad++;
    final ImageElement img = new ImageElement(src: key)
      ..crossOrigin = 'anonymous';
    img.onLoad.listen((Event e) {
      final core.Texture texture = textureLoader(img);
      _assets[key] = texture;
      _toLoad--;
      _loaded++;
      if (success != null) success(path, img);
    });
    img.onError.listen((Event e) {
      final String msg = 'Couldn\'t load image $path';
      errors[path] = msg;
      _toLoad--;
      _loaded++;
      if (error != null) error(path, msg);
    });
  }

  void loadTextureData(String path,
      {LoadedCallback<ImageElement> success, LoadedCallback<String> error}) {
    final String key = pathPrefix + path;
    _toLoad++;
    final ImageElement img = new ImageElement(src: path)
      ..crossOrigin = 'anonymous';
    img.onLoad.listen((Event e) {
      final core.Texture texture = textureLoader(img);
      _assets[key] = texture;
      _toLoad--;
      _loaded++;
      if (success != null) success(path, img);
    });
    img.onError.listen((Event e) {
      final String msg = 'Couldn\'t load image $path';
      errors[path] = msg;
      _toLoad--;
      _loaded++;
      if (error != null) error(path, msg);
    });
  }

  void loadTextureAtlas(String path,
      {LoadedCallback<core.TextureAtlas> success,
      LoadedCallback<String> error}) {
    final String parent = path.lastIndexOf('/') >= 0
        ? path.substring(0, path.lastIndexOf('/'))
        : '';
    final String key = pathPrefix + path;
    _toLoad++;

    _downloadText(key, (int status, String atlasData) {
      int pagesLoadedCount = 0;
      final List<String> atlasPages = <String>[];
      try {
        new core.TextureAtlas(atlasData, (String path) {
          atlasPages.add(parent + '/' + path);
          final ImageElement image =
              document.createElement('img') as ImageElement
                ..width = 16
                ..height = 16;
          return new core.FakeTexture(image: image);
        });
      } on Exception catch (e) {
        final String msg = 'Couldn\'t load texture atlas $path: $e';
        errors[path] = msg;
        _toLoad--;
        _loaded++;
        if (error != null) error(path, msg);
        return;
      }

      atlasPages.forEach((String atlasPage) {
        bool pageLoadError = false;
        loadTexture(atlasPage, success: (String imagePath, ImageElement image) {
          pagesLoadedCount++;

          if (pagesLoadedCount == atlasPages.length) {
            if (!pageLoadError) {
              try {
                final core.TextureAtlas atlas = new core.TextureAtlas(
                    atlasData, (String path) => get(parent + '/' + path));
                _assets[path] = atlas;
                if (success != null) success(path, atlas);
                _toLoad--;
                _loaded++;
              } on Exception catch (e) {
                final String msg = 'Couldn\'t load texture atlas $path: $e';
                errors[path] = msg;
                _toLoad--;
                _loaded++;
                if (error != null) error(path, msg);
              }
            } else {
              final String msg =
                  'Couldn\'t load texture atlas page $imagePath of atlas $path';
              errors[path] = msg;
              _toLoad--;
              _loaded++;
              if (error != null) error(path, msg);
            }
          }
        }, error: (String imagePath, String errorMessage) {
          pageLoadError = true;
          pagesLoadedCount++;

          if (pagesLoadedCount == atlasPages.length) {
            final String msg =
                'Couldn\'t load texture atlas page $imagePath of atlas $path';
            errors[path] = msg;
            _toLoad--;
            _loaded++;
            if (error != null) error(path, msg);
          }
        });
      });
    }, (int status, String responseText) {
      final String msg =
          'Couldn\'t load texture atlas $path: status $status, $responseText';
      errors[path] = msg;
      _toLoad--;
      _loaded++;
      if (error != null) error(path, msg);
    });
  }

  dynamic get(String path) => _assets[pathPrefix + path];

  void remove(String path) {
    final String key = pathPrefix + path;
    final dynamic asset = _assets[key];
    if (asset is core.Disposable) {
      asset.dispose();
    }
    _assets[key] = null;
  }

  void removeAll() {
    _assets
      ..forEach((String key, Object asset) {
        if (asset is core.Disposable) {
          asset.dispose();
        }
      })
      ..clear();
  }

  bool isLoadingComplete() => _toLoad == 0;
  int get toLoad => _toLoad;
  int get loaded => _loaded;
  bool hasErrors() => errors.keys.isNotEmpty;

  @override
  void dispose() {
    removeAll();
  }

  static void _downloadText(
      String url,
      ResponseCallback<String> successCallback,
      ResponseCallback<String> errorCallback) {
    HttpRequest.request(url, method: 'GET').then((HttpRequest request) {
      if (request.status == 200) {
        successCallback(request.status, request.responseText);
      } else {
        errorCallback(request.status, request.responseText);
      }
    });
  }

  static void _downloadBinary(
      String url,
      ResponseCallback<Uint8List> successCallback,
      ResponseCallback<String> errorCallback) {
    HttpRequest.request(url, method: 'GET').then((HttpRequest request) {
      if (request.status == 200) {
        final ByteBuffer buffer = request.response as ByteBuffer;
        successCallback(request.status, new Uint8List.view(buffer));
      } else {
        errorCallback(request.status, request.responseText);
      }
    });
  }
}
