Shader "Skybox/GradientAube"
{
    Properties
    {
        _TopColor ("Haut du ciel", Color) = (0.29, 0.31, 0.66, 1)
        _MidColor ("Milieu du ciel", Color) = (0.89, 0.56, 0.66, 1)
        _HorizonColor ("Horizon", Color) = (1.0, 0.77, 0.54, 1)
        _BottomColor ("Sous l'horizon", Color) = (0.35, 0.25, 0.45, 1)
        _MidPosition ("Position du milieu", Range(0.05, 0.95)) = 0.35
        _Sharpness ("Fermete du degrade", Range(0.2, 4)) = 1
    }

    SubShader
    {
        Tags { "Queue"="Background" "RenderType"="Background" "PreviewType"="Skybox" "RenderPipeline"="UniversalPipeline" }
        Cull Off
        ZWrite Off

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
                half4 _TopColor;
                half4 _MidColor;
                half4 _HorizonColor;
                half4 _BottomColor;
                half _MidPosition;
                half _Sharpness;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 dir        : TEXCOORD0;
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.dir = IN.positionOS.xyz;
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                float h = normalize(IN.dir).y;

                half3 col;
                if (h >= 0)
                {
                    float t = pow(saturate(h), _Sharpness);
                    half3 low  = lerp(_HorizonColor.rgb, _MidColor.rgb, smoothstep(0.0, _MidPosition, t));
                    col = lerp(low, _TopColor.rgb, smoothstep(_MidPosition, 1.0, t));
                }
                else
                {
                    col = lerp(_HorizonColor.rgb, _BottomColor.rgb, smoothstep(0.0, 0.25, -h));
                }

                return half4(col, 1);
            }
            ENDHLSL
        }
    }
}
