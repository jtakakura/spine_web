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
import 'dart:math';

import 'package:spine_core/spine_core.dart';
import 'package:spine_web/spine_canvas.dart';
import 'package:tuple/tuple.dart';

void main() {
  new App()..init();
}

class App {
  double lastFrameTime = DateTime.now().millisecond / 1000;
  CanvasRenderingContext2D context;
  CanvasElement canvas;
  AssetManager assetManager;
  Skeleton skeleton;
  AnimationState state;
  Bounds bounds;
  SkeletonRenderer skeletonRenderer;
  String skelName = 'spineboy';
  String animName = 'walk';

  void init() {
    canvas = querySelector('#canvas');
    canvas.width = window.innerWidth;
    canvas.height = window.innerHeight;
    context = canvas.getContext('2d');

    skeletonRenderer = new SkeletonRenderer(context);
    skeletonRenderer.debugRendering = true;
    skeletonRenderer.triangleRendering = true;

    assetManager = new AssetManager(pathPrefix: 'assets/$skelName/');
    assetManager.loadText('$skelName.json');
    assetManager.loadText('$skelName.atlas');
    assetManager.loadTexture('$skelName.png');

    window.requestAnimationFrame(load);
  }

  void load(double timeStamp) {
    if (assetManager.isLoadingComplete()) {
      final Tuple3<Skeleton, AnimationState, Bounds> data =
          loadSkeleton(skelName, animName, skin: 'default');
      skeleton = data.item1;
      state = data.item2;
      bounds = data.item3;
      window.requestAnimationFrame(render);
    } else {
      window.requestAnimationFrame(load);
    }
  }

  Tuple3<Skeleton, AnimationState, Bounds> loadSkeleton(
      String name, String initialAnimation,
      {String skin = 'default'}) {
    assetManager.get('spineboy.png');
    final TextureAtlas atlas = new TextureAtlas(
        assetManager.get('$name.atlas'), (path) => assetManager.get('$path'));
    final AtlasAttachmentLoader atlasLoader = new AtlasAttachmentLoader(atlas);
    final SkeletonJson skeletonJson = new SkeletonJson(atlasLoader);

    SkeletonData skeletonData =
        skeletonJson.readSkeletonData(assetManager.get('$name.json'));
    Skeleton skeleton = new Skeleton(skeletonData);
    skeleton.flipY = true;
    Bounds bounds = calculateBounds(skeleton);
    skeleton.setSkinByName(skin);
    AnimationState animationState =
        new AnimationState(new AnimationStateData(skeleton.data));
    animationState.setAnimation(0, initialAnimation, true);
    return Tuple3.fromList([skeleton, animationState, bounds]);
  }

  Bounds calculateBounds(skeleton) {
    skeleton.setToSetupPose();
    skeleton.updateWorldTransform();
    Vector2 offset = new Vector2();
    Vector2 size = new Vector2();
    skeleton.getBounds(offset, size, []);
    return new Bounds(offset, size);
  }

  void render(double timeStamp) {
    final double now = DateTime.now().millisecond / 1000;
    final double delta = now - lastFrameTime;
    lastFrameTime = now;
    resize();
    context.save();
    context.setTransform(1, 0, 0, 1, 0, 0);
    context.fillStyle = '#cccccc';
    context.fillRect(0, 0, canvas.width, canvas.height);
    context.restore();
    state.update(delta);
    state.apply(skeleton);
    skeleton.updateWorldTransform();
    skeletonRenderer.draw(skeleton);
    context.strokeStyle = 'green';
    context.beginPath();
    context.moveTo(-1000, 0);
    context.lineTo(1000, 0);
    context.moveTo(0, -1000);
    context.lineTo(0, 1000);
    context.stroke();
    window.requestAnimationFrame(render);
  }

  void resize() {
    int w = canvas.clientWidth;
    int h = canvas.clientHeight;
    if (canvas.width != w || canvas.height != h) {
      canvas.width = w;
      canvas.height = h;
    }
    // magic
    final double centerX = bounds.offset.x + bounds.size.x / 2;
    final double centerY = bounds.offset.y + bounds.size.y / 2;
    final double scaleX = bounds.size.x / canvas.width;
    final double scaleY = bounds.size.y / canvas.height;
    double scale = max(scaleX, scaleY) * 1.2;
    if (scale < 1) scale = 1.0;
    final double width = canvas.width * scale;
    final double height = canvas.height * scale;
    context.setTransform(1, 0, 0, 1, 0, 0);
    context.scale(1 / scale, 1 / scale);
    context.translate(-centerX, -centerY);
    context.translate(width / 2, height / 2);
  }
}
