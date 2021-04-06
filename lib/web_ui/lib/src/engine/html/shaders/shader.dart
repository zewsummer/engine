// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.12
part of engine;

abstract class EngineGradient implements ui.Gradient {
  /// Hidden constructor to prevent subclassing.
  EngineGradient._();

  /// Creates a fill style to be used in painting.
  Object createPaintStyle(html.CanvasRenderingContext2D? ctx,
      ui.Rect? shaderBounds, double density);

  /// Creates a CanvasImageSource to paint gradient.
  Object createImageBitmap(
      ui.Rect? shaderBounds, double density, bool createDataUrl);
}

class GradientSweep extends EngineGradient {
  GradientSweep(this.center, this.colors, this.colorStops, this.tileMode,
      this.startAngle, this.endAngle, this.matrix4)
      : assert(_offsetIsValid(center)),
        assert(colors != null), // ignore: unnecessary_null_comparison
        assert(tileMode != null), // ignore: unnecessary_null_comparison
        assert(startAngle != null), // ignore: unnecessary_null_comparison
        assert(endAngle != null), // ignore: unnecessary_null_comparison
        assert(startAngle < endAngle),
        super._() {
    _validateColorStops(colors, colorStops);
  }

  @override
  Object createImageBitmap(
      ui.Rect? shaderBounds, double density, bool createDataUrl) {
    assert(shaderBounds != null);
    int widthInPixels = shaderBounds!.width.ceil();
    int heightInPixels = shaderBounds.height.ceil();
    assert(widthInPixels > 0 && heightInPixels > 0);

    initWebGl();
    // Render gradient into a bitmap and create a canvas pattern.
    _OffScreenCanvas offScreenCanvas =
        _OffScreenCanvas(widthInPixels, heightInPixels);
    _GlContext gl = _OffScreenCanvas.supported
        ? _GlContext.fromOffscreenCanvas(offScreenCanvas._canvas!)
        : _GlContext.fromCanvas(
            offScreenCanvas._glCanvas!, webGLVersion == WebGLVersion.webgl1);
    gl.setViewportSize(widthInPixels, heightInPixels);

    NormalizedGradient normalizedGradient =
        NormalizedGradient(colors, stops: colorStops);

    _GlProgram glProgram = gl.useAndCacheProgram(
        _WebGlRenderer.writeBaseVertexShader(),
        _createSweepFragmentShader(normalizedGradient, tileMode));

    Object tileOffset =
        gl.getUniformLocation(glProgram.program, 'u_tile_offset');
    double centerX = (center.dx - shaderBounds.left) / (shaderBounds.width);
    double centerY = (center.dy - shaderBounds.top) / (shaderBounds.height);
    gl.setUniform2f(tileOffset, 2 * (shaderBounds.width * (centerX - 0.5)),
        2 * (shaderBounds.height * (centerY - 0.5)));
    Object angleRange = gl.getUniformLocation(glProgram.program, 'angle_range');
    gl.setUniform2f(angleRange, startAngle, endAngle);
    normalizedGradient.setupUniforms(gl, glProgram);
    if (matrix4 != null) {
      Object gradientMatrix =
          gl.getUniformLocation(glProgram.program, 'm_gradient');
      gl.setUniformMatrix4fv(gradientMatrix, false, matrix4!);
    }
    if (createDataUrl) {
      return _glRenderer!.drawRectToImageUrl(
          ui.Rect.fromLTWH(0, 0, shaderBounds.width, shaderBounds.height),
          gl,
          glProgram,
          normalizedGradient,
          widthInPixels,
          heightInPixels);
    } else {
      return _glRenderer!.drawRect(
          ui.Rect.fromLTWH(0, 0, shaderBounds.width, shaderBounds.height),
          gl,
          glProgram,
          normalizedGradient,
          widthInPixels,
          heightInPixels)!;
    }
  }

  @override
  Object createPaintStyle(html.CanvasRenderingContext2D? ctx,
      ui.Rect? shaderBounds, double density) {
    Object? imageBitmap = createImageBitmap(shaderBounds, density, false);
    return ctx!.createPattern(imageBitmap, 'no-repeat')!;
  }

  String _createSweepFragmentShader(
      NormalizedGradient gradient, ui.TileMode tileMode) {
    ShaderBuilder builder = ShaderBuilder.fragment(webGLVersion);
    builder.floatPrecision = ShaderPrecision.kMedium;
    builder.addIn(ShaderType.kVec4, name: 'v_color');
    builder.addUniform(ShaderType.kVec2, name: 'u_resolution');
    builder.addUniform(ShaderType.kVec2, name: 'u_tile_offset');
    builder.addUniform(ShaderType.kVec2, name: 'angle_range');
    builder.addUniform(ShaderType.kMat4, name: 'm_gradient');
    ShaderDeclaration fragColor = builder.fragmentColor;
    ShaderMethod method = builder.addMethod('main');
    // Sweep gradient
    method.addStatement('vec2 center = 0.5 * (u_resolution + u_tile_offset);');
    method.addStatement(
        'vec4 localCoord = vec4(gl_FragCoord.x - center.x, center.y - gl_FragCoord.y, 0, 1) * m_gradient;');
    method.addStatement(
        'float angle = atan(-localCoord.y, -localCoord.x) + ${math.pi};');
    method.addStatement('float sweep = angle_range.y - angle_range.x;');
    method.addStatement('angle = (angle - angle_range.x) / sweep;');
    method.addStatement(''
        'float st = angle;');

    final String probeName =
        _writeSharedGradientShader(builder, method, gradient, tileMode);
    method.addStatement('${fragColor.name} = ${probeName} * scale + bias;');

    String shader = builder.build();
    return shader;
  }

  final ui.Offset center;
  final List<ui.Color> colors;
  final List<double>? colorStops;
  final ui.TileMode tileMode;
  final double startAngle;
  final double endAngle;
  final Float32List? matrix4;
}

class GradientLinear extends EngineGradient {
  GradientLinear(
    this.from,
    this.to,
    this.colors,
    this.colorStops,
    this.tileMode,
    Float32List? matrix,
  )   : assert(_offsetIsValid(from)),
        assert(_offsetIsValid(to)),
        assert(colors != null), // ignore: unnecessary_null_comparison
        assert(tileMode != null), // ignore: unnecessary_null_comparison
        this.matrix4 = matrix == null ? null : _FastMatrix32(matrix),
        super._() {
    if (assertionsEnabled) {
      _validateColorStops(colors, colorStops);
    }
  }

  final ui.Offset from;
  final ui.Offset to;
  final List<ui.Color> colors;
  final List<double>? colorStops;
  final ui.TileMode tileMode;
  final _FastMatrix32? matrix4;

  @override
  Object createPaintStyle(html.CanvasRenderingContext2D? ctx,
      ui.Rect? shaderBounds, double density) {
    if (tileMode == ui.TileMode.clamp || tileMode == ui.TileMode.decal) {
      return _createCanvasGradient(ctx, shaderBounds, density);
    } else {
      return _createGlGradient(ctx, shaderBounds, density);
    }
  }

  html.CanvasGradient _createCanvasGradient(html.CanvasRenderingContext2D? ctx,
      ui.Rect? shaderBounds, double density) {
    _FastMatrix32? matrix4 = this.matrix4;
    html.CanvasGradient gradient;
    final double offsetX = shaderBounds!.left;
    final double offsetY = shaderBounds.top;
    if (matrix4 != null) {
      final centerX = (from.dx + to.dx) / 2.0;
      final centerY = (from.dy + to.dy) / 2.0;
      matrix4.transform(from.dx - centerX, from.dy - centerY);
      final double fromX = matrix4.transformedX + centerX;
      final double fromY = matrix4.transformedY + centerY;
      matrix4.transform(to.dx - centerX, to.dy - centerY);
      gradient = ctx!.createLinearGradient(
          fromX - offsetX,
          fromY - offsetY,
          matrix4.transformedX + centerX - offsetX,
          matrix4.transformedY - offsetY + centerY);
    } else {
      gradient = ctx!.createLinearGradient(from.dx - offsetX, from.dy - offsetY,
          to.dx - offsetX, to.dy - offsetY);
    }
    _addColorStopsToCanvasGradient(
        gradient, colors, colorStops, tileMode == ui.TileMode.decal);
    return gradient;
  }

  @override
  Object createImageBitmap(
      ui.Rect? shaderBounds, double density, bool createDataUrl) {
    assert(shaderBounds != null);
    int widthInPixels = shaderBounds!.width.ceil();
    int heightInPixels = shaderBounds.height.ceil();
    assert(widthInPixels > 0 && heightInPixels > 0);
    initWebGl();
    // Render gradient into a bitmap and create a canvas pattern.
    _OffScreenCanvas offScreenCanvas =
        _OffScreenCanvas(widthInPixels, heightInPixels);
    _GlContext gl = _OffScreenCanvas.supported
        ? _GlContext.fromOffscreenCanvas(offScreenCanvas._canvas!)
        : _GlContext.fromCanvas(
            offScreenCanvas._glCanvas!, webGLVersion == WebGLVersion.webgl1);
    gl.setViewportSize(widthInPixels, heightInPixels);

    NormalizedGradient normalizedGradient =
        NormalizedGradient(colors, stops: colorStops);

    _GlProgram glProgram = gl.useAndCacheProgram(
        _WebGlRenderer.writeBaseVertexShader(),
        _createLinearFragmentShader(normalizedGradient, tileMode));

    // Setup from/to uniforms.
    //
    // To compute t value between 0..1 for any point on the screen,
    // we need to use from,to point pair to construct a matrix that will
    // take any fragment coordinate and transform it to a t value.
    //
    // We compute the matrix by:
    // 1- Shift from,to vector to origin.
    // 2- Rotate the vector to align with x axis.
    // 3- Scale it to unit vector.
    final double fromX = from.dx;
    final double fromY = from.dy;
    final double toX = to.dx;
    final double toY = to.dy;

    final double dx = toX - fromX;
    final double dy = toY - fromY;
    final double length = math.sqrt(dx * dx + dy * dy);
    // sin(theta) = dy / length.
    // cos(theta) = dx / length.
    // Flip dy for gl flip.
    final double sinVal = length < kFltEpsilon ? 0 : -dy / length;
    final double cosVal = length < kFltEpsilon ? 1 : dx / length;
    // If tile mode is repeated we need to shift the center of from->to
    // vector to the center of shader bounds.
    final bool isRepeated = tileMode != ui.TileMode.clamp;
    double originX = isRepeated
        ? (shaderBounds.width / 2)
        : (fromX + toX) / 2.0 - shaderBounds.left;
    double originY = isRepeated
        ? (shaderBounds.height / 2)
        : (fromY + toY) / 2.0 - shaderBounds.top;

    final Matrix4 translateToOrigin =
        Matrix4.translationValues(-originX, -originY, 0);
    // Rotate around Z axis.
    final Matrix4 rotationZ = Matrix4.identity();
    final Float32List storage = rotationZ.storage;
    storage[0] = cosVal;
    // Sign is flipped since gl coordinate system is flipped around y axis.
    storage[1] = sinVal;
    storage[4] = -sinVal;
    storage[5] = cosVal;
    Matrix4 gradientTransform = Matrix4.identity();
    // We compute location based on gl_FragCoord to center distance which
    // returns 0.0 at center. To make sure we align center of gradient to this
    // point, we shift by 0.5 to get st value for center of gradient.
    if (tileMode != ui.TileMode.repeated) {
      gradientTransform.translate(0.5, 0);
    }
    if (length > kFltEpsilon) {
      gradientTransform.scale(1.0 / length);
    }
    if (matrix4 != null) {
      // Flutter GradientTransform is defined in shaderBounds coordinate system
      // with flipped y axis.
      // We flip y axis, translate to center, multiply matrix and translate
      // and flip back so it is applied correctly.
      final Matrix4 m4 = Matrix4.fromFloat32List(matrix4!.matrix);
      gradientTransform.scale(1, -1);
      gradientTransform.translate(
          -shaderBounds.center.dx, -shaderBounds.center.dy);
      gradientTransform.multiply(m4);
      gradientTransform.translate(
          shaderBounds.center.dx, shaderBounds.center.dy);
      gradientTransform.scale(1, -1);
    }

    gradientTransform.multiply(rotationZ);
    gradientTransform.multiply(translateToOrigin);
    // Setup gradient uniforms for t search.
    normalizedGradient.setupUniforms(gl, glProgram);
    // Setup matrix transform uniform.
    Object gradientMatrix =
        gl.getUniformLocation(glProgram.program, 'm_gradient');
    gl.setUniformMatrix4fv(gradientMatrix, false, gradientTransform.storage);

    Object uRes = gl.getUniformLocation(glProgram.program, 'u_resolution');
    gl.setUniform2f(uRes, widthInPixels.toDouble(), heightInPixels.toDouble());

    if (createDataUrl) {
      return _glRenderer!.drawRectToImageUrl(
        ui.Rect.fromLTWH(0, 0, shaderBounds.width,
            shaderBounds.height) /* !! shaderBounds */,
        gl,
        glProgram,
        normalizedGradient,
        widthInPixels,
        heightInPixels,
      );
    } else {
      return _glRenderer!.drawRect(
        ui.Rect.fromLTWH(0, 0, shaderBounds.width,
            shaderBounds.height) /* !! shaderBounds */,
        gl,
        glProgram,
        normalizedGradient,
        widthInPixels,
        heightInPixels,
      )!;
    }
  }

  /// Creates a linear gradient with tiling repeat or mirror.
  html.CanvasPattern _createGlGradient(html.CanvasRenderingContext2D? ctx,
      ui.Rect? shaderBounds, double density) {
    final Object imageBitmap = createImageBitmap(shaderBounds, density, false);
    return ctx!.createPattern(imageBitmap, 'no-repeat')!;
  }

  String _createLinearFragmentShader(
      NormalizedGradient gradient, ui.TileMode tileMode) {
    ShaderBuilder builder = ShaderBuilder.fragment(webGLVersion);
    builder.floatPrecision = ShaderPrecision.kMedium;
    builder.addIn(ShaderType.kVec4, name: 'v_color');
    builder.addUniform(ShaderType.kVec2, name: 'u_resolution');
    builder.addUniform(ShaderType.kMat4, name: 'm_gradient');
    ShaderDeclaration fragColor = builder.fragmentColor;
    ShaderMethod method = builder.addMethod('main');
    // Linear gradient.
    // Multiply with m_gradient transform to convert from fragment coordinate to
    // distance on the from-to line.
    method.addStatement('vec4 localCoord = m_gradient * vec4(gl_FragCoord.x, '
        'u_resolution.y - gl_FragCoord.y, 0, 1);');
    method.addStatement('float st = localCoord.x;');
    final String probeName =
        _writeSharedGradientShader(builder, method, gradient, tileMode);
    method.addStatement('${fragColor.name} = ${probeName} * scale + bias;');
    String shader = builder.build();
    return shader;
  }
}

void _addColorStopsToCanvasGradient(html.CanvasGradient gradient,
    List<ui.Color> colors, List<double>? colorStops, bool isDecal) {
  double scale, offset;
  if (isDecal) {
    scale = 0.999;
    offset = (1.0 - scale) / 2.0;
    gradient.addColorStop(0, '#00000000');
  } else {
    scale = 1.0;
    offset = 0.0;
  }
  if (colorStops == null) {
    assert(colors.length == 2);
    gradient.addColorStop(offset, colorToCssString(colors[0])!);
    gradient.addColorStop(1 - offset, colorToCssString(colors[1])!);
  } else {
    for (int i = 0; i < colors.length; i++) {
      gradient.addColorStop(
          colorStops[i] * scale + offset, colorToCssString(colors[i])!);
    }
  }
  if (isDecal) {
    gradient.addColorStop(1, '#00000000');
  }
}

/// Writes shader code to map fragment value to gradient color.
///
/// Returns name of gradient treshold variable to use to compute color.
String _writeSharedGradientShader(ShaderBuilder builder, ShaderMethod method,
    NormalizedGradient gradient, ui.TileMode tileMode) {
  method.addStatement('vec4 bias;');
  method.addStatement('vec4 scale;');
  // Write uniforms for each threshold, bias and scale.
  for (int i = 0; i < (gradient.thresholdCount - 1) ~/ 4 + 1; i++) {
    builder.addUniform(ShaderType.kVec4, name: 'threshold_${i}');
  }
  for (int i = 0; i < gradient.thresholdCount; i++) {
    builder.addUniform(ShaderType.kVec4, name: 'bias_$i');
    builder.addUniform(ShaderType.kVec4, name: 'scale_$i');
  }

  // Use st variable name if clamped or decaled, otherwise write code to compute
  // tiled_st.
  String probeName = 'st';
  switch (tileMode) {
    case ui.TileMode.clamp:
      method.addStatement('float tiled_st = clamp(st, 0.0, 1.0);');
      probeName = 'tiled_st';
      break;
    case ui.TileMode.decal:
      break;
    case ui.TileMode.repeated:
      // st represents our distance from center. Flutter maps the center to
      // center of gradient ramp so we need to add 0.5 to make sure repeated
      // pattern center is at origin.
      method.addStatement('float tiled_st = fract(st);');
      probeName = 'tiled_st';
      break;
    case ui.TileMode.mirror:
      method.addStatement('float t_1 = (st - 1.0);');
      method.addStatement(
          'float tiled_st = abs((t_1 - 2.0 * floor(t_1 * 0.5)) - 1.0);');
      probeName = 'tiled_st';
      break;
  }
  _writeUnrolledBinarySearch(method, 0, gradient.thresholdCount - 1,
      probe: probeName,
      sourcePrefix: 'threshold',
      biasName: 'bias',
      scaleName: 'scale');
  return probeName;
}

class GradientRadial extends EngineGradient {
  GradientRadial(this.center, this.radius, this.colors, this.colorStops,
      this.tileMode, this.matrix4)
      : super._() {}

  final ui.Offset center;
  final double radius;
  final List<ui.Color> colors;
  final List<double>? colorStops;
  final ui.TileMode tileMode;
  final Float32List? matrix4;

  @override
  Object createPaintStyle(html.CanvasRenderingContext2D? ctx,
      ui.Rect? shaderBounds, double density) {
    if (tileMode == ui.TileMode.clamp || tileMode == ui.TileMode.decal) {
      return _createCanvasGradient(ctx, shaderBounds, density);
    } else {
      return _createGlGradient(ctx, shaderBounds, density);
    }
  }

  Object _createCanvasGradient(html.CanvasRenderingContext2D? ctx,
      ui.Rect? shaderBounds, double density) {
    final double offsetX = shaderBounds!.left;
    final double offsetY = shaderBounds.top;
    final html.CanvasGradient gradient = ctx!.createRadialGradient(
        center.dx - offsetX,
        center.dy - offsetY,
        0,
        center.dx - offsetX,
        center.dy - offsetY,
        radius);
    _addColorStopsToCanvasGradient(
        gradient, colors, colorStops, tileMode == ui.TileMode.decal);
    return gradient;
  }

  @override
  Object createImageBitmap(
      ui.Rect? shaderBounds, double density, bool createDataUrl) {
    assert(shaderBounds != null);
    int widthInPixels = shaderBounds!.width.ceil();
    int heightInPixels = shaderBounds.height.ceil();
    assert(widthInPixels > 0 && heightInPixels > 0);

    initWebGl();
    // Render gradient into a bitmap and create a canvas pattern.
    _OffScreenCanvas offScreenCanvas =
        _OffScreenCanvas(widthInPixels, heightInPixels);
    _GlContext gl = _OffScreenCanvas.supported
        ? _GlContext.fromOffscreenCanvas(offScreenCanvas._canvas!)
        : _GlContext.fromCanvas(
            offScreenCanvas._glCanvas!, webGLVersion == WebGLVersion.webgl1);
    gl.setViewportSize(widthInPixels, heightInPixels);

    NormalizedGradient normalizedGradient =
        NormalizedGradient(colors, stops: colorStops);

    _GlProgram glProgram = gl.useAndCacheProgram(
        _WebGlRenderer.writeBaseVertexShader(),
        _createRadialFragmentShader(
            normalizedGradient, shaderBounds, tileMode));

    Object tileOffset =
        gl.getUniformLocation(glProgram.program, 'u_tile_offset');
    double centerX = (center.dx - shaderBounds.left) / (shaderBounds.width);
    double centerY = (center.dy - shaderBounds.top) / (shaderBounds.height);
    gl.setUniform2f(tileOffset, 2 * (shaderBounds.width * (centerX - 0.5)),
        2 * (shaderBounds.height * (centerY - 0.5)));
    Object radiusUniform = gl.getUniformLocation(glProgram.program, 'u_radius');
    gl.setUniform1f(radiusUniform, radius);
    normalizedGradient.setupUniforms(gl, glProgram);

    Object gradientMatrix =
        gl.getUniformLocation(glProgram.program, 'm_gradient');
    gl.setUniformMatrix4fv(gradientMatrix, false,
        matrix4 == null ? Matrix4.identity().storage : matrix4!);

    if (createDataUrl) {
      return _glRenderer!.drawRectToImageUrl(
          ui.Rect.fromLTWH(0, 0, shaderBounds.width, shaderBounds.height),
          gl,
          glProgram,
          normalizedGradient,
          widthInPixels,
          heightInPixels);
    } else {
      return _glRenderer!.drawRect(
          ui.Rect.fromLTWH(0, 0, shaderBounds.width, shaderBounds.height),
          gl,
          glProgram,
          normalizedGradient,
          widthInPixels,
          heightInPixels)!;
    }
  }

  /// Creates a radial gradient with tiling repeat or mirror.
  html.CanvasPattern _createGlGradient(html.CanvasRenderingContext2D? ctx,
      ui.Rect? shaderBounds, double density) {
    final Object imageBitmap = createImageBitmap(shaderBounds, density, false);
    return ctx!.createPattern(imageBitmap, 'no-repeat')!;
  }

  String _createRadialFragmentShader(
      NormalizedGradient gradient, ui.Rect shaderBounds, ui.TileMode tileMode) {
    ShaderBuilder builder = ShaderBuilder.fragment(webGLVersion);
    builder.floatPrecision = ShaderPrecision.kMedium;
    builder.addIn(ShaderType.kVec4, name: 'v_color');
    builder.addUniform(ShaderType.kVec2, name: 'u_resolution');
    builder.addUniform(ShaderType.kVec2, name: 'u_tile_offset');
    builder.addUniform(ShaderType.kFloat, name: 'u_radius');
    builder.addUniform(ShaderType.kMat4, name: 'm_gradient');
    ShaderDeclaration fragColor = builder.fragmentColor;
    ShaderMethod method = builder.addMethod('main');
    // Sweep gradient
    method.addStatement('vec2 center = 0.5 * (u_resolution + u_tile_offset);');
    method.addStatement(
        'vec4 localCoord = vec4(gl_FragCoord.x - center.x, center.y - gl_FragCoord.y, 0, 1) * m_gradient;');
    method.addStatement('float dist = length(localCoord);');
    method.addStatement(''
        'float st = abs(dist / u_radius);');
    final String probeName =
        _writeSharedGradientShader(builder, method, gradient, tileMode);
    method.addStatement('${fragColor.name} = ${probeName} * scale + bias;');
    String shader = builder.build();
    return shader;
  }
}

/// TODO: Implement focal https://github.com/flutter/flutter/issues/76643.
class GradientConical extends GradientRadial {
  GradientConical(
      this.focal,
      this.focalRadius,
      ui.Offset center,
      double radius,
      List<ui.Color> colors,
      List<double>? colorStops,
      ui.TileMode tileMode,
      Float32List? matrix4)
      : super(center, radius, colors, colorStops, tileMode, matrix4);

  final ui.Offset focal;
  final double focalRadius;

  @override
  Object createPaintStyle(html.CanvasRenderingContext2D? ctx,
      ui.Rect? shaderBounds, double density) {
    if ((tileMode == ui.TileMode.clamp || tileMode == ui.TileMode.decal) &&
        focalRadius == 0.0 &&
        focal == const ui.Offset(0, 0)) {
      return _createCanvasGradient(ctx, shaderBounds, density);
    } else {
      initWebGl();
      return _createGlGradient(ctx, shaderBounds, density);
    }
  }

  @override
  String _createRadialFragmentShader(
      NormalizedGradient gradient, ui.Rect shaderBounds, ui.TileMode tileMode) {
    /// If distance between centers is nearly zero we can pretend we're radial
    /// to prevent divide by zero in computing gradient.
    final double centerDistanceX = center.dx - focal.dx;
    final double centerDistanceY = center.dy - focal.dy;
    final double centerDistanceSq =
        centerDistanceX * centerDistanceX + centerDistanceY * centerDistanceY;
    if (centerDistanceSq < kFltEpsilonSquared) {
      return super
          ._createRadialFragmentShader(gradient, shaderBounds, tileMode);
    }
    double centerDistance = math.sqrt(centerDistanceSq);
    double r0 = focalRadius / centerDistance;
    double r1 = radius / centerDistance;
    double fFocalX = r0 / (r0 - r1);

    if ((fFocalX - 1).abs() < SPath.scalarNearlyZero) {
      // swap r0, r1
      double temp = r0;
      r0 = r1;
      r1 = temp;
      fFocalX = 0.0; // because r0 is now 0
    }

    ShaderBuilder builder = ShaderBuilder.fragment(webGLVersion);
    builder.floatPrecision = ShaderPrecision.kMedium;
    builder.addIn(ShaderType.kVec4, name: 'v_color');
    builder.addUniform(ShaderType.kVec2, name: 'u_resolution');
    builder.addUniform(ShaderType.kVec2, name: 'u_tile_offset');
    builder.addUniform(ShaderType.kFloat, name: 'u_radius');
    builder.addUniform(ShaderType.kMat4, name: 'm_gradient');
    ShaderDeclaration fragColor = builder.fragmentColor;
    ShaderMethod method = builder.addMethod('main');
    // Sweep gradient
    method.addStatement('vec2 center = 0.5 * (u_resolution + u_tile_offset);');
    method.addStatement(
        'vec4 localCoord = vec4(gl_FragCoord.x - center.x, center.y - gl_FragCoord.y, 0, 1) * m_gradient;');
    method.addStatement('float dist = length(localCoord);');
    final String f = (focalRadius /
            (math.min(shaderBounds.width, shaderBounds.height) / 2.0))
        .toStringAsPrecision(8);
    method.addStatement(focalRadius == 0.0
        ? 'float st = dist / u_radius;'
        : 'float st = ((dist / u_radius) - $f) / (1.0 - $f);');
    if (tileMode == ui.TileMode.clamp) {
      method.addStatement('if (st < 0.0) { st = -1.0; }');
    }
    final String probeName =
        _writeSharedGradientShader(builder, method, gradient, tileMode);
    method.addStatement('${fragColor.name} = ${probeName} * scale + bias;');
    return builder.build();
  }
}

/// Backend implementation of [ui.ImageFilter].
///
/// Currently only `blur` is supported.
class EngineImageFilter implements ui.ImageFilter {
  EngineImageFilter.blur({this.sigmaX = 0.0, this.sigmaY = 0.0});

  final double sigmaX;
  final double sigmaY;

  @override
  bool operator ==(Object other) {
    return other is EngineImageFilter &&
        other.sigmaX == sigmaX &&
        other.sigmaY == sigmaY;
  }

  @override
  int get hashCode => ui.hashValues(sigmaX, sigmaY);

  @override
  String toString() {
    return 'ImageFilter.blur($sigmaX, $sigmaY)';
  }
}
