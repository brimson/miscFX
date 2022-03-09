
/*
    Enables one of Watch Dogs' tonemapping algorithms. No tweaking values.
    Full credits to the ReShade team. Ported by Insomnia
    Change: use gamma conversion before and after processing
*/

texture2D _RenderColor : COLOR;

sampler2D _SampleColor
{
    Texture = _RenderColor;
    #if BUFFER_COLOR_BIT_DEPTH == 8
        SRGBTexture = TRUE;
    #endif
};

// Vertex shaders

void PostProcessVS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float2 TexCoord : TEXCOORD0)
{
    TexCoord.x = (ID == 2) ? 2.0 : 0.0;
    TexCoord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(TexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

/* [ Pixel Shaders ] */

float3 Tonemap(float3 N)
{
    const float3 A = float3(0.55f, 0.50f, 0.45f); // Shoulder strength
    const float3 B = float3(0.30f, 0.27f, 0.22f); // Linear strength
    const float3 C = float3(0.10f, 0.10f, 0.10f); // Linear angle
    const float3 D = float3(0.10f, 0.07f, 0.03f); // Toe strength
    const float3 E = float3(0.01f, 0.01f, 0.01f); // Toe Numerator
    const float3 F = float3(0.30f, 0.30f, 0.30f); // Toe Denominator
    return mad(N, mad(A, N, C * B), D * E) / mad(N, mad(A, N, B), D * F) - (E / F);
}

void TonemapPS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
{
    float3 LinearColor = tex2D(_SampleColor, TexCoord).rgb;
    const float3 WhitePoint = 1.0 / Tonemap(float3(2.80f, 2.90f, 3.10f));
    LinearColor = Tonemap(LinearColor) * 1.25 * WhitePoint;
    OutputColor0 = pow(abs(LinearColor), 1.25);
}

technique cTonemap
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = TonemapPS;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }
}
