// ============================================================================
// Vael'Thor Targeting Visor - violet heat scanner (GUI/GUIVTVision.lua).
// Built on the vanilla alien vision shader (shaders/DarkVision.hlsl): same inputs (the depth texture's r =
// view depth in metres, g > 0.5 = entity, r < 0.4 = view model). The world turns into a dark, desaturated
// violet with faint edges; every entity (players, structures, eggs) glows as a heat signature, hot white-pink
// at its silhouette edges over a violet body, dimming with distance. A slow scanline sweeps down the screen.
// ============================================================================
#include <renderer/RenderSetup.hlsl>

struct VS_INPUT
{
   float3 ssPosition   : POSITION;
   float2 texCoord     : TEXCOORD0;
   float4 color        : COLOR0;
};

struct VS_OUTPUT
{
   float2 texCoord     : TEXCOORD0;
   float4 color        : COLOR0;
   float4 ssPosition   : SV_POSITION;
};

struct PS_INPUT
{
   float2 texCoord     : TEXCOORD0;
   float4 color        : COLOR0;
};

sampler2D       baseTexture;
sampler2D       depthTexture;
sampler2D       normalTexture;

cbuffer LayerConstants
{
    float        startTime;
    float        amount;
    float        time;
};

VS_OUTPUT SFXBasicVS(VS_INPUT input)
{
   VS_OUTPUT output;
   output.ssPosition = float4(input.ssPosition, 1);
   output.texCoord   = input.texCoord + texelCenter;
   output.color      = input.color;
   return output;
}

float2 clamp_tex2D( sampler2D tex, float2 coord )
{
    return tex2D( tex, clamp( coord, float2( 0.001, 0.001 ), float2( 0.999, 0.999 ) ) );
}

const float4 worldTint   = float4(0.30, 0.16, 0.55, 0);   // dark violet world
const float4 worldEdge   = float4(0.55, 0.30, 1.00, 0);   // faint violet geometry edges
const float4 heatCold    = float4(0.35, 0.05, 0.75, 0);   // body of a heat signature
const float4 heatWarm    = float4(0.85, 0.25, 1.00, 0);
const float4 heatHot     = float4(1.00, 0.85, 1.00, 0);   // silhouette edges

float4 SFXVTHeatVisionPS(PS_INPUT input) : COLOR0
{
    float2 texCoord = input.texCoord;
    float4 inputPixel = tex2D(baseTexture, texCoord);

    if (amount == 0)
    {
        return inputPixel;
    }

    float2 depth1 = tex2D(depthTexture, texCoord).rg;

    float offset = 0.0008;
    float depth2 = clamp_tex2D(depthTexture, texCoord + float2(-offset, -offset)).r;
    float depth3 = clamp_tex2D(depthTexture, texCoord + float2(-offset,  offset)).r;
    float depth4 = clamp_tex2D(depthTexture, texCoord + float2( offset, -offset)).r;
    float depth5 = clamp_tex2D(depthTexture, texCoord + float2( offset,  offset)).r;

    float edge =
            abs(depth2 - depth1.r) +
            abs(depth3 - depth1.r) +
            abs(depth4 - depth1.r) +
            abs(depth5 - depth1.r);

    float luminance = dot(inputPixel.rgb, float3(0.299, 0.587, 0.114));

    // slow scanline sweeping down the screen (2.5 s per pass)
    float scan = frac((time - startTime) * 0.4);
    float scanLine = saturate(1 - abs(texCoord.y - scan) * 60) * 0.25;

    if (depth1.g > 0.5) // entities
    {
        if (depth1.r < 0.4) // view model: untouched
        {
            return inputPixel;
        }

        float distanceFade = saturate(1.2 - depth1.r / 45.0);
        float heat = saturate(0.35 + luminance * 0.8);
        float4 body = lerp(heatCold, heatWarm, heat);
        float4 signature = lerp(body, heatHot, saturate(edge * 1.5)) * (0.55 + 0.45 * distanceFade);
        signature += heatHot * scanLine;
        return saturate(lerp(inputPixel, signature, 0.85 * amount));
    }
    else // world geometry
    {
        edge = edge * step(depth1.r, 100); // no edges for skyboxes
        float4 world = worldTint * (0.15 + luminance * 0.9) + worldEdge * saturate(edge * 0.15) + worldEdge * scanLine * 0.4;
        return saturate(lerp(inputPixel, world, 0.75 * amount));
    }
}
