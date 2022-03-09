
/*
    This work is licensed under the Creative Commons Attribution-NonCommercial-NoDerivs 3.0 Unported License.
    To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-nd/3.0/ or send a letter to Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
*/

uniform int2 _Radius <
    ui_type = "drag";
    ui_label = "Mosaic Radius";
> = 32.0;

uniform int _Shape <
    ui_type = "slider";
    ui_label = "Mosaic Shape";
    ui_max = 2;
> = 0;

texture2D _RenderColor : COLOR;

sampler2D _SampleColor
{
    Texture = _RenderColor;
    AddressU = MIRROR;
    AddressV = MIRROR;
    #if BUFFER_COLOR_BIT_DEPTH == 8
        SRGBTexture = TRUE;
    #endif
};

texture2D _RenderMosaicLOD
{
    Width = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
    MipLevels = 9;
    Format = RGBA8;
};

sampler2D _SampleMosaicLOD
{
    Texture = _RenderMosaicLOD;
    AddressU = MIRROR;
    AddressV = MIRROR;
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

// Pixel shaders
// Circle mosaic: https://www.shadertoy.com/view/3sVcRh
// Triangle mosaic: https://www.shadertoy.com/view/4d2SWy

void BlitPS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
{
    OutputColor0 = tex2D(_SampleColor, TexCoord);
}

void MosaicPS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
{
    float2 PixelPosition = TexCoord * float2(BUFFER_WIDTH, BUFFER_HEIGHT);
    const float2 ScreenSize = float2(BUFFER_WIDTH, BUFFER_HEIGHT);
    float2 PixelSize = float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);
    float2 BlockCoord, MosaicCoord;
    float MaxRadius = max(_Radius.x, _Radius.y);

    switch(_Shape)
    {
        case 0:
            // Circle mosaic
            BlockCoord = floor(PixelPosition / MaxRadius) * MaxRadius;
            MosaicCoord = BlockCoord * PixelSize;
            float4 Color = tex2Dlod(_SampleMosaicLOD, float4(MosaicCoord, 0.0, log2(MaxRadius) - 1.0));

            float2 Offset = PixelPosition - BlockCoord;
            float2 Center = MaxRadius / 2.0;
            float Length = distance(Center, Offset);
            float Circle = 1.0 - smoothstep(-2.0 , 0.0, Length - Center.x);
            OutputColor0 = Color * Circle;
            break;
        case 1:
            // Triangle mosaic
            const float MaxLODLevel = log2(sqrt((BUFFER_WIDTH * BUFFER_HEIGHT) / (_Radius.x * _Radius.y)));
            const float2 Divisor = 1.0 / (2.0 * _Radius);
            BlockCoord = floor(TexCoord * _Radius) / _Radius;
            TexCoord -= BlockCoord;
            TexCoord *= _Radius;
            float2 Composite;
            Composite.x = step(1.0 - TexCoord.y, TexCoord.x);
            Composite.y = step(TexCoord.x, TexCoord.y);
            OutputColor0 = tex2Dlod(_SampleMosaicLOD, float4(BlockCoord + Composite * Divisor, 0.0, MaxLODLevel - 1.0));
            break;
        default:
            BlockCoord = round(PixelPosition / MaxRadius) * MaxRadius;
            MosaicCoord = BlockCoord * PixelSize;
            OutputColor0 = tex2Dlod(_SampleMosaicLOD, float4(MosaicCoord, 0.0, log2(MaxRadius) - 1.0));
            break;
    }
}

technique cMosaic
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = BlitPS;
        RenderTarget0 = _RenderMosaicLOD;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }

    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = MosaicPS;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }
}
