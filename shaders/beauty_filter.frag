#version 460 core

precision mediump float;

#include <flutter/runtime_effect.glsl>

uniform vec2 u_resolution;
uniform float u_intensity; // 0.0 (desactivado) a 1.0 (máxima belleza)
uniform sampler2D u_image;

out vec4 fragColor;

// Estimador continuo y adaptativo de tono de piel humana (multitono: claro, medio, moreno)
float calculateSkinWeight(vec3 rgb) {
    float r = rgb.r;
    float g = rgb.g;
    float b = rgb.b;

    // Reglas universales de tono de piel en RGB: r > g, g >= b, diferencia suave
    float isSkin = 0.0;
    if (r > g && g > (b * 0.8) && (r - g) > 0.015 && (r - b) > 0.03) {
        // Ponderar por la presencia de tonos cálidos
        float warmFactor = clamp((r - b) * 3.5, 0.0, 1.0);
        isSkin = warmFactor;
    }
    return isSkin;
}

void main() {
    vec2 uv = FlutterFragCoord().xy / u_resolution;
    vec4 originalColor = texture(u_image, uv);

    if (u_intensity <= 0.01) {
        fragColor = originalColor;
        return;
    }

    // Paso de muestreo adaptativo ampliado según intensidad para suavizado visible de estudio
    float stepScale = 1.0 + (u_intensity * 2.2);
    vec2 texelSize = (1.0 / u_resolution) * stepScale;

    vec3 colorSum = vec3(0.0);
    float weightSum = 0.0;

    // Filtro bilateral de suavizado con preservación de bordes
    const int RADIUS = 4;
    float spatialSigma = 3.5;
    float colorSigma = 0.22;

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

    vec3 blurredColor = colorSum / max(weightSum, 0.0001);

    // Detección adaptativa de piel
    float skin = calculateSkinWeight(originalColor.rgb);
    float effectiveBlend = u_intensity * (0.4 + 0.6 * skin);

    // Mezcla de suavizado facial de alta intensidad
    vec3 finalRgb = mix(originalColor.rgb, blurredColor, clamp(effectiveBlend, 0.0, 0.95));

    // Resplandor sutil y favorecedor de iluminación de estudio
    finalRgb += vec3(0.035 * u_intensity * skin);

    fragColor = vec4(finalRgb, originalColor.a);
}
