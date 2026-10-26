#version 460 core

precision mediump float;

#include <flutter/runtime_effect.glsl>

uniform vec2 u_resolution;
uniform float u_intensity; // 0.0 (desactivado) a 1.0 (máxima belleza)
uniform sampler2D u_image;

out vec4 fragColor;

// Detección de rango de tono de piel humana
bool isSkinTone(vec3 rgb) {
    float r = rgb.r;
    float g = rgb.g;
    float b = rgb.b;
    return (r > 0.35 && g > 0.20 && b > 0.15 && r > g && r > b && (r - g) > 0.05);
}

void main() {
    vec2 uv = FlutterFragCoord().xy / u_resolution;
    vec4 originalColor = texture(u_image, uv);

    if (u_intensity <= 0.01) {
        fragColor = originalColor;
        return;
    }

    vec2 texelSize = 1.0 / u_resolution;
    vec3 colorSum = vec3(0.0);
    float weightSum = 0.0;

    // Filtro bilateral de suavizado con preservación de bordes
    const int RADIUS = 3;
    float spatialSigma = 3.0;
    float colorSigma = 0.15;

    for (int x = -RADIUS; x <= RADIUS; x++) {
        for (int y = -RADIUS; y <= RADIUS; y++) {
            vec2 offset = vec2(float(x), float(y)) * texelSize;
            vec3 neighborColor = texture(u_image, uv + offset).rgb;

            float spatialDist = float(x * x + y * y);
            float spatialWeight = exp(-spatialDist / (2.0 * spatialSigma * spatialSigma));

            float colorDist = length(neighborColor - originalColor.rgb);
            float colorWeight = exp(-(colorDist * colorDist) / (2.0 * colorSigma * colorSigma));

            float totalWeight = spatialWeight * colorWeight;
            colorSum += neighborColor * totalWeight;
            weightSum += totalWeight;
        }
    }

    vec3 blurredColor = colorSum / weightSum;

    // Aplicar solo si es tono de piel para preservar ojos, labios y cuerdas de guitarra
    vec3 finalRgb = originalColor.rgb;
    if (isSkinTone(originalColor.rgb)) {
        // Mezclar según la intensidad escogida por el usuario
        finalRgb = mix(originalColor.rgb, blurredColor, u_intensity * 0.85);

        // Realce sutil de luminosidad
        finalRgb += vec3(0.02 * u_intensity);
    }

    fragColor = vec4(finalRgb, originalColor.a);
}
