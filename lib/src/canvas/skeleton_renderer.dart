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

part of spine_canvas;

class SkeletonRenderer {
  static const List<int> quadTriangles = <int>[0, 1, 2, 2, 3, 0];
  static const int vertexSize = 2 + 2 + 4;
  final CanvasRenderingContext2D ctx;
  final core.Color _tempColor = new core.Color();

  Float32List _vertices = new Float32List(8 * 1024);
  bool triangleRendering = false;
  bool debugRendering = false;

  SkeletonRenderer(this.ctx);

  void draw(core.Skeleton skeleton) {
    if (triangleRendering)
      _drawTriangles(skeleton);
    else
      _drawImages(skeleton);
  }

  void _drawImages(core.Skeleton skeleton) {
    final CanvasRenderingContext2D ctx = this.ctx;
    final List<core.Slot> drawOrder = skeleton.drawOrder;

    if (debugRendering) ctx.strokeStyle = 'green';

    ctx.save();

    final int n = drawOrder.length;
    for (int i = 0; i < n; i++) {
      final core.Slot slot = drawOrder[i];
      final core.Attachment attachment = slot.getAttachment();
      core.RegionAttachment regionAttachment;
      core.TextureAtlasRegion region;
      ImageElement image;

      if (attachment is! core.RegionAttachment) continue;

      regionAttachment = attachment;
      region = regionAttachment.region;
      image = region.texture.image;

      final core.Skeleton skeleton = slot.bone.skeleton;
      final core.Color skeletonColor = skeleton.color;
      final core.Color slotColor = slot.color;
      final core.Color regionColor = regionAttachment.color;
      final double alpha = skeletonColor.a * slotColor.a * regionColor.a;
      final core.Color color = _tempColor
        ..set(
            skeletonColor.r * slotColor.r * regionColor.r,
            skeletonColor.g * slotColor.g * regionColor.g,
            skeletonColor.b * slotColor.b * regionColor.b,
            alpha);

      final core.Bone bone = slot.bone;
      double w = region.width.toDouble();
      double h = region.height.toDouble();
      final double atlasScale = regionAttachment.width / w;
      ctx
        ..save()
        ..transform(bone.a, bone.c, bone.b, bone.d, bone.worldX, bone.worldY)
        ..translate(regionAttachment.offset[0], regionAttachment.offset[1])
        ..rotate(regionAttachment.rotation * math.pi / 180)
        ..scale(atlasScale * regionAttachment.scaleX,
            atlasScale * regionAttachment.scaleY)
        ..translate(w / 2, h / 2);
      if (regionAttachment.region.rotate) {
        final double t = w;
        w = h;
        h = t;
        ctx.rotate(-math.pi / 2);
      }
      ctx
        ..scale(1, -1)
        ..translate(-w / 2, -h / 2);
      if (color.r != 1 || color.g != 1 || color.b != 1 || color.a != 1) {
        ctx.globalAlpha = color.a;
        // experimental tinting via compositing, doesn't work
        // ctx.globalCompositeOperation = "source-atop";
        // ctx.fillStyle = "rgba(" + (color.r * 255 | 0) + ", " + (color.g * 255 | 0)  + ", " + (color.b * 255 | 0) + ", " + color.a + ")";
        // ctx.fillRect(0, 0, w, h);
      }
      ctx.drawImageScaledFromSource(
          image, region.x, region.y, w, h, 0, 0, w, h);
      if (debugRendering) ctx.strokeRect(0, 0, w, h);
      ctx.restore();
    }

    ctx.restore();
  }

  void _drawTriangles(core.Skeleton skeleton) {
    core.BlendMode blendMode;

    final List<core.Slot> drawOrder = skeleton.drawOrder;
    Float32List vertices = _vertices;
    List<int> triangles;

    final int n = drawOrder.length;
    for (int i = 0; i < n; i++) {
      final core.Slot slot = drawOrder[i];
      final core.Attachment attachment = slot.getAttachment();
      ImageElement texture;
      core.TextureAtlasRegion region;
      core.Color attachmentColor;
      if (attachment is core.RegionAttachment) {
        final core.RegionAttachment regionAttachment = attachment;
        vertices = _computeRegionVertices(slot, regionAttachment, false);
        triangles = SkeletonRenderer.quadTriangles;
        region = regionAttachment.region;
        texture = region.texture.image;
        attachmentColor = regionAttachment.color;
      } else if (attachment is core.MeshAttachment) {
        final core.MeshAttachment mesh = attachment;
        vertices = _computeMeshVertices(slot, mesh, false);
        triangles = mesh.triangles;
        texture = mesh.region.renderObject.texture.image;
        attachmentColor = mesh.color;
      } else
        continue;

      if (texture != null) {
        final core.BlendMode slotBlendMode = slot.data.blendMode;
        if (slotBlendMode != blendMode) {
          blendMode = slotBlendMode;
        }

        final core.Skeleton skeleton = slot.bone.skeleton;
        final core.Color skeletonColor = skeleton.color;
        final core.Color slotColor = slot.color;
        final double alpha = skeletonColor.a * slotColor.a * attachmentColor.a;
        final core.Color color = _tempColor
          ..set(
              skeletonColor.r * slotColor.r * attachmentColor.r,
              skeletonColor.g * slotColor.g * attachmentColor.g,
              skeletonColor.b * slotColor.b * attachmentColor.b,
              alpha);

        final CanvasRenderingContext2D ctx = this.ctx;

        if (color.r != 1 || color.g != 1 || color.b != 1 || color.a != 1) {
          ctx.globalAlpha = color.a;
          // experimental tinting via compositing, doesn't work
          // ctx.globalCompositeOperation = "source-atop";
          // ctx.fillStyle = "rgba(" + (color.r * 255 | 0) + ", " + (color.g * 255 | 0)  + ", " + (color.b * 255 | 0) + ", " + color.a + ")";
          // ctx.fillRect(0, 0, w, h);
        }

        for (int j = 0; j < triangles.length; j += 3) {
          final int t1 = triangles[j] * 8,
              t2 = triangles[j + 1] * 8,
              t3 = triangles[j + 2] * 8;

          final double x0 = vertices[t1],
              y0 = vertices[t1 + 1],
              u0 = vertices[t1 + 6],
              v0 = vertices[t1 + 7];
          final double x1 = vertices[t2],
              y1 = vertices[t2 + 1],
              u1 = vertices[t2 + 6],
              v1 = vertices[t2 + 7];
          final double x2 = vertices[t3],
              y2 = vertices[t3 + 1],
              u2 = vertices[t3 + 6],
              v2 = vertices[t3 + 7];

          _drawTriangle(
              texture, x0, y0, u0, v0, x1, y1, u1, v1, x2, y2, u2, v2);

          if (debugRendering) {
            ctx
              ..strokeStyle = 'green'
              ..beginPath()
              ..moveTo(x0, y0)
              ..lineTo(x1, y1)
              ..lineTo(x2, y2)
              ..lineTo(x0, y0)
              ..stroke();
          }
        }
      }
    }

    ctx.globalAlpha = 1;
  }

  // Adapted from http://extremelysatisfactorytotalitarianism.com/blog/?p=2120
  // Apache 2 licensed
  void _drawTriangle(
      ImageElement img,
      double x0,
      double y0,
      double u0,
      double v0,
      double x1,
      double y1,
      double u1,
      double v1,
      double x2,
      double y2,
      double u2,
      double v2) {
    final CanvasRenderingContext2D ctx = this.ctx;

    u0 *= img.width;
    v0 *= img.height;
    u1 *= img.width;
    v1 *= img.height;
    u2 *= img.width;
    v2 *= img.height;

    ctx
      ..beginPath()
      ..moveTo(x0, y0)
      ..lineTo(x1, y1)
      ..lineTo(x2, y2)
      ..closePath();

    x1 -= x0;
    y1 -= y0;
    x2 -= x0;
    y2 -= y0;

    u1 -= u0;
    v1 -= v0;
    u2 -= u0;
    v2 -= v0;

    final double det = 1 / (u1 * v2 - u2 * v1),
        // linear transformation
        a = (v2 * x1 - v1 * x2) * det,
        b = (v2 * y1 - v1 * y2) * det,
        c = (u1 * x2 - u2 * x1) * det,
        d = (u1 * y2 - u2 * y1) * det,
        // translation
        e = x0 - a * u0 - c * v0,
        f = y0 - b * u0 - d * v0;

    ctx
      ..save()
      ..transform(a, b, c, d, e, f)
      ..clip()
      ..drawImage(img, 0, 0)
      ..restore();
  }

  Float32List _computeRegionVertices(
      core.Slot slot, core.RegionAttachment region, bool pma) {
    final core.Skeleton skeleton = slot.bone.skeleton;
    final core.Color skeletonColor = skeleton.color;
    final core.Color slotColor = slot.color;
    final core.Color regionColor = region.color;
    final double alpha = skeletonColor.a * slotColor.a * regionColor.a;
    final double multiplier = pma ? alpha : 1.0;
    final core.Color color = _tempColor
      ..set(
          skeletonColor.r * slotColor.r * regionColor.r * multiplier,
          skeletonColor.g * slotColor.g * regionColor.g * multiplier,
          skeletonColor.b * slotColor.b * regionColor.b * multiplier,
          alpha);

    region.computeWorldVertices2(
        slot.bone, _vertices, 0, SkeletonRenderer.vertexSize);

    final Float32List vertices = _vertices;
    final Float32List uvs = region.uvs;

    vertices[core.RegionAttachment.c1r] = color.r;
    vertices[core.RegionAttachment.c1g] = color.g;
    vertices[core.RegionAttachment.c1b] = color.b;
    vertices[core.RegionAttachment.c1a] = color.a;
    vertices[core.RegionAttachment.u1] = uvs[0];
    vertices[core.RegionAttachment.v1] = uvs[1];

    vertices[core.RegionAttachment.c2r] = color.r;
    vertices[core.RegionAttachment.c2g] = color.g;
    vertices[core.RegionAttachment.c2b] = color.b;
    vertices[core.RegionAttachment.c2a] = color.a;
    vertices[core.RegionAttachment.u2] = uvs[2];
    vertices[core.RegionAttachment.v2] = uvs[3];

    vertices[core.RegionAttachment.c3r] = color.r;
    vertices[core.RegionAttachment.c3g] = color.g;
    vertices[core.RegionAttachment.c3b] = color.b;
    vertices[core.RegionAttachment.c3a] = color.a;
    vertices[core.RegionAttachment.u3] = uvs[4];
    vertices[core.RegionAttachment.v3] = uvs[5];

    vertices[core.RegionAttachment.c4r] = color.r;
    vertices[core.RegionAttachment.c4g] = color.g;
    vertices[core.RegionAttachment.c4b] = color.b;
    vertices[core.RegionAttachment.c4a] = color.a;
    vertices[core.RegionAttachment.u4] = uvs[6];
    vertices[core.RegionAttachment.v4] = uvs[7];

    return vertices;
  }

  Float32List _computeMeshVertices(
      core.Slot slot, core.MeshAttachment mesh, bool pma) {
    final core.Skeleton skeleton = slot.bone.skeleton;
    final core.Color skeletonColor = skeleton.color;
    final core.Color slotColor = slot.color;
    final core.Color regionColor = mesh.color;
    final double alpha = skeletonColor.a * slotColor.a * regionColor.a;
    final double multiplier = pma ? alpha : 1;
    final core.Color color = _tempColor
      ..set(
          skeletonColor.r * slotColor.r * regionColor.r * multiplier,
          skeletonColor.g * slotColor.g * regionColor.g * multiplier,
          skeletonColor.b * slotColor.b * regionColor.b * multiplier,
          alpha);

    final int numVertices = mesh.worldVerticesLength ~/ 2;
    if (_vertices.length < mesh.worldVerticesLength) {
      _vertices = new Float32List(mesh.worldVerticesLength);
    }
    final Float32List vertices = _vertices;
    mesh.computeWorldVertices(slot, 0, mesh.worldVerticesLength, vertices, 0,
        SkeletonRenderer.vertexSize);

    final Float32List uvs = mesh.uvs;
    final int n = numVertices;
    for (int i = 0, u = 0, v = 2; i < n; i++) {
      vertices[v++] = color.r;
      vertices[v++] = color.g;
      vertices[v++] = color.b;
      vertices[v++] = color.a;
      vertices[v++] = uvs[u++];
      vertices[v++] = uvs[u++];
      v += 2;
    }

    return vertices;
  }
}
