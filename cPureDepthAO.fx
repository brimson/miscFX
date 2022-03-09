
/*
    Work In-Progress
    Pure Depth Ambient Occlusion

    Source
        http://theorangeduck.com/page/pure-depth-ssao
    Original Port by Jose Negrete AKA BlueSkyDefender
        https://github.com/BlueSkyDefender/Depth3D
*/

#include "ReShade.fxh"

uniform float _TotalStrength <
    ui_type = "drag";
    ui_min = 0.0;
    ui_label = "Total Strength";
    ui_category = "Ambient Occlusion";
> = 1.0;

uniform float _Base <
    ui_type = "drag";
    ui_min = 0.0;
    ui_label = "Base Amount";
    ui_category = "Ambient Occlusion";
> = 0.0;

uniform float _Area <
    ui_type = "drag";
    ui_min = 0.0;
    ui_label = "Area Amount";
    ui_category = "Ambient Occlusion";
> = 1.0;

uniform float _Falloff <
    ui_type = "drag";
    ui_min = 0.0;
    ui_label = "Falloff Amount";
    ui_category = "Ambient Occlusion";
> = 0.001;

uniform float _Radius <
    ui_type = "drag";
    ui_min = 0.0;
    ui_label = "Radius Amount";
    ui_category = "Ambient Occlusion";
> = 0.007;

uniform float _DepthMapAdjust <
    ui_type = "drag";
    ui_min = 0.0;
    ui_label = "Depth Map Adjustment";
    ui_tooltip = "This allows for you to adjust the DM precision.\n"
                 "Adjust this to keep it as low as possible.\n"
                 "Default is 7.5";
    ui_category = "Depth Buffer";
> = 0.1;

uniform int _Debug <
    ui_type = "combo";
    ui_items = "Off\0Depth\0AO\0Occlusion\0Direction\0";
    ui_label = "Debug View";
    ui_tooltip = "View Debug Buffers.";
    ui_category = "Debug Buffer";
> = 0;

texture2D _RenderColor : COLOR;

sampler2D _SampleColor
{
    Texture = _RenderColor;
    #if BUFFER_COLOR_BIT_DEPTH == 8
        SRGBTexture = TRUE;
    #endif
};

texture2D _RenderOcclusion
{
    Width = BUFFER_WIDTH / 2;
    Height = BUFFER_HEIGHT / 2;
    MipLevels = 2;
    Format = R16F;
};

sampler2D _SampleOcclusion
{
    Texture = _RenderOcclusion;
};

texture2D _RenderData0_Depth
{
    Width = BUFFER_WIDTH / 4;
    Height = BUFFER_HEIGHT / 4;
    Format = R16F;
};

sampler2D _SampleData0
{
    Texture = _RenderData0_Depth;
    AddressU = MIRROR;
    AddressV = MIRROR;
};

texture2D _RenderData1_Depth
{
    Width = BUFFER_WIDTH / 4;
    Height = BUFFER_HEIGHT / 4;
    Format = R16F;
};

sampler2D _SampleData1
{
    Texture = _RenderData1_Depth;
    AddressU = MIRROR;
    AddressV = MIRROR;
};

// Pixel shaders

float2 DepthMap(float2 TexCoord)
{
    float ZBuffer = ReShade::GetLinearizedDepth(TexCoord).x;
    //ZBuffer /= _DepthMapAdjust;
    return float2(ZBuffer, smoothstep(-1.0, 1.0, ZBuffer));
}

float3 NormalFromDepth(float2 TexCoord)
{
    const float2 PixelSize = 1.0 / (float2(BUFFER_WIDTH, BUFFER_HEIGHT));
    const float2 Offset1 = float2(0.0, PixelSize.y);
    const float2 Offset2 = float2(PixelSize.x, 0.0);
    float Depth1 = DepthMap(TexCoord + Offset1).x;
    float Depth2 = DepthMap(TexCoord + Offset2).x;
    float3 P1 = float3(Offset1, Depth1 - DepthMap(TexCoord).x);
    float3 P2 = float3(Offset2, Depth2 - DepthMap(TexCoord).x);
    float3 Normal = cross(P1, P2);
    Normal.z = -Normal.z;
    return normalize(Normal);
}

/*
    Stored random vectors inside a sphere unit
    TODO: Use Vogel sphere disc for dynamic samples
    http://blog.marmakoide.org/?p=1
*/

float Interleaved_Gradient_Noise(float2 TC)
{   //Magic Numbers
    float3 MNums = float3(0.06711056, 0.00583715, 52.9829189);
    return frac(MNums.z * frac(dot(TC,MNums.xy)) );
}

void GradientNoise(float2 Position, float Seed, inout float Noise)
{
    const float Pi = 3.1415926535 * 1e-1;
    const float GoldenRatio = 1.6180339887 * 1e-1;
    const float SquareRoot2 = sqrt(2.0) * 1e+4;
    float2 Parameter1 = Position * ((Seed + 20.0) + GoldenRatio);
    float2 Parameter2 = float2(GoldenRatio, Pi);
    Noise = frac(tan(distance(Parameter1, Parameter2)) * SquareRoot2);
}

float2 Rotate2D( float2 r, float l )
{   float2 Directions;
    sincos(l,Directions[0],Directions[1]);
    return float2(dot(r, float2(Directions[1], -Directions[0])), dot(r, Directions.xy));
}

void OcclusionPS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
{
    const int Samples = 16;

    const float3 Sample_Sphere[Samples] = {
        float3( 0.5381, 0.1856,-0.4319), float3( 0.1379, 0.2486, 0.4430),
        float3( 0.3371, 0.5679,-0.0057), float3(-0.6999,-0.0451,-0.0019),
        float3( 0.0689,-0.1598,-0.8547), float3( 0.0560, 0.0069,-0.1843),
        float3(-0.0146, 0.1402, 0.0762), float3( 0.0100,-0.1924,-0.0344),
        float3(-0.3577,-0.5301,-0.4358), float3(-0.3169, 0.1063, 0.0158),
        float3( 0.0103,-0.5869, 0.0046), float3(-0.0897,-0.4940, 0.3287),
        float3( 0.7119,-0.0154,-0.0918), float3(-0.0533, 0.0596,-0.5411),
        float3( 0.0352,-0.0631, 0.5460), float3(-0.4776, 0.2847,-0.0271)
    };

    float2 FragPosition = (TexCoord * float2(BUFFER_WIDTH, BUFFER_HEIGHT));
    float Random = Interleaved_Gradient_Noise(FragPosition.xy);

    float Depth = DepthMap(TexCoord.xy).x;
    float3 ScreenPosition = float3(TexCoord.xy, Depth);
    float3 Normal = NormalFromDepth(TexCoord);
    float RadiusDepth = _Radius / DepthMap(TexCoord.xy).y;
    float Occlusion = 0.0;

    for(int i = 0; i < Samples; i++)
    {
        float3 Ray = 0.03 * RadiusDepth * reflect(Sample_Sphere[i], normalize(Rotate2D(Sample_Sphere[i].xy, Random).xyy)) / RadiusDepth;
        float3 Hemi_Ray = ScreenPosition + sign(dot(Ray, Normal)) * Ray;
        float OcclusionDepth = DepthMap(saturate(Hemi_Ray.xy)).x;
        float Difference = Depth - OcclusionDepth;
        Occlusion += step(_Falloff, Difference) * (1.0 - smoothstep(_Falloff, _Area, Difference));
    }

    float AmbientOcclusion = 1.0 - _TotalStrength * Occlusion * (1.0 / Samples);
    OutputColor0 = saturate(AmbientOcclusion + _Base);
}

static const float KernelSize = 14;

float GaussianWeight(const int Position)
{
    const float Sigma = KernelSize / 3.0;
    const float Pi = 3.1415926535897932384626433832795f;
    float Output = rsqrt(2.0 * Pi * (Sigma * Sigma));
    return Output * exp(-(Position * Position) / (2.0 * (Sigma * Sigma)));
}

float GaussianBlur(sampler2D Source, float2 TexCoord, float2 Direction)
{
    const float2 ScreenSize = float2(BUFFER_WIDTH, BUFFER_HEIGHT) / 4.0;
    const float2 PixelSize = 1.0 / ScreenSize;
    float TotalWeight = GaussianWeight(0.0);
    float Output = tex2D(Source, TexCoord).x * TotalWeight;

    for(int i = 1; i < KernelSize; i++)
    {
        float Offset1 = i;
        float Offset2 = i + 1;
        float Weight1 = GaussianWeight(Offset1);
        float Weight2 = GaussianWeight(Offset2);
        float LinearWeight = Weight1 + Weight2;
        float LinearOffset = ((Offset1 * Weight1) + (Offset2 * Weight2)) / LinearWeight;

        Output += tex2D(Source, TexCoord - LinearOffset * PixelSize * Direction).x * LinearWeight;
        Output += tex2D(Source, TexCoord + LinearOffset * PixelSize * Direction).x * LinearWeight;
        TotalWeight += LinearWeight * 2.0;
    }

    return Output / TotalWeight;
}

void BlitPS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float OutputColor0 : SV_Target0)
{
    OutputColor0 = tex2D(_SampleOcclusion, TexCoord).x;
}

void HorizontalBlurPS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float OutputColor0 : SV_Target0)
{
    OutputColor0 = GaussianBlur(_SampleData0, TexCoord, float2(1.0, 0.0)).x;
}

void VerticalBlurPS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float OutputColor0 : SV_Target0)
{
    OutputColor0 = GaussianBlur(_SampleData1, TexCoord, float2(0.0, 1.0)).x;
}

void ImagePS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float3 OutputColor0 : SV_Target0)
{

    switch(_Debug)
    {
        case 0:
            OutputColor0 = tex2D(_SampleColor, TexCoord).rgb * tex2D(_SampleData0, TexCoord).x;
            break;
        case 1:
            OutputColor0 = DepthMap(TexCoord).x;
            break;
        case 2:
            OutputColor0 = tex2D(_SampleData0, TexCoord).x;
            break;
        case 3:
            OutputColor0 = tex2D(_SampleOcclusion, TexCoord).x;
            break;
        default:
            OutputColor0 = NormalFromDepth(TexCoord);
            break;
    }
}

technique cPureDepthAO
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = OcclusionPS;
        RenderTarget0 = _RenderOcclusion;
    }

    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = BlitPS;
        RenderTarget0 = _RenderData0_Depth;
    }

    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = HorizontalBlurPS;
        RenderTarget0 = _RenderData1_Depth;
    }

    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = VerticalBlurPS;
        RenderTarget0 = _RenderData0_Depth;
    }

    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = ImagePS;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }
}
