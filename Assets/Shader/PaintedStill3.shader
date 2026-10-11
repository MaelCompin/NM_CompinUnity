Shader "Custom/PaintedStill"
{
    Properties
    {
        [MainTexture] _BaseMap ("Albedo", 2D) = "white" {}
        [MainColor] _BaseColor ("Couleur", Color) = (1,1,1,1)
        _Cutoff ("Alpha cutoff (0 = desactive, > 0 = masked)", Range(0,1)) = 0
        _Exposure ("Luminosite de la texture", Range(0.5,4)) = 1
        _Unlit ("Auto-eclairage (0 = normal, 1 = sans ombre ni teinte)", Range(0,1)) = 0
        _TexDetail ("Detail de la texture (0 = aplat, 1 = original)", Range(0,1)) = 1
        _Blur ("Flou de la texture", Range(0,6)) = 0

        [Header(Bandes de lumiere)]
        _LitColor ("Teinte lumiere", Color) = (1.0, 0.90, 0.78, 1)
        _MidColor ("Teinte demi-ton", Color) = (0.62, 0.52, 0.80, 1)
        _ShadowColor ("Teinte ombre", Color) = (0.24, 0.20, 0.50, 1)
        _LitCut ("Seuil lumiere", Range(0,1)) = 0.45
        _ShadowCut ("Seuil ombre", Range(0,1)) = 0.08
        _Softness ("Douceur des bandes", Range(0.001,0.3)) = 0.05

        [Header(Effet pinceau)]
        _BrushScale ("Taille du bruit pinceau", Range(1,80)) = 18
        _BrushStrength ("Force du bruit pinceau", Range(0,0.5)) = 0.12

        [Header(Reflet en aplat (metal))]
        _SpecTint ("Couleur du reflet (noir = aucun)", Color) = (0,0,0,1)
        _Gloss ("Brillance", Range(1,256)) = 48
        _SpecCut ("Seuil du reflet", Range(0,1)) = 0.5
        _SpecSoft ("Douceur du reflet", Range(0.001,0.3)) = 0.03

        [Header(Rim light)]
        _RimColor ("Couleur du rim", Color) = (1.0, 0.89, 0.69, 1)
        _RimStrength ("Force du rim", Range(0,2)) = 0.8
        _RimWidth ("Largeur du rim", Range(0.01,0.8)) = 0.3
        _RimSoft ("Douceur du rim", Range(0.01,0.5)) = 0.08

        [Header(Lumieres additionnelles)]
        _AddCut ("Seuil lumieres additionnelles", Range(0,1)) = 0.2
        _AddStrength ("Force lumieres additionnelles", Range(0,2)) = 0.6

        [Header(Grain)]
        _Grain ("Grain", Range(0,0.2)) = 0.03
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" "Queue"="Geometry" }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        TEXTURE2D(_BaseMap);
        SAMPLER(sampler_BaseMap);

        CBUFFER_START(UnityPerMaterial)
            float4 _BaseMap_ST;
            half4 _BaseColor;
            half _Cutoff;
            half _Exposure;
            half _Unlit;
            half _TexDetail;
            half _Blur;
            half4 _LitColor;
            half4 _MidColor;
            half4 _ShadowColor;
            half _LitCut;
            half _ShadowCut;
            half _Softness;
            half _BrushScale;
            half _BrushStrength;
            half4 _SpecTint;
            half _Gloss;
            half _SpecCut;
            half _SpecSoft;
            half4 _RimColor;
            half _RimStrength;
            half _RimWidth;
            half _RimSoft;
            half _AddCut;
            half _AddStrength;
            half _Grain;
        CBUFFER_END
        ENDHLSL

        // ------------------------------------------------------------
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForward" }
            Cull Back
            ZWrite On

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _FORWARD_PLUS _CLUSTER_LIGHT_LOOP
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DBuffer.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float2 uv         : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS   : TEXCOORD1;
                float2 uv         : TEXCOORD2;
            };

            // --- bruit de valeur 3D (effet coup de pinceau) ---
            float hash13(float3 p3)
            {
                p3 = frac(p3 * 0.1031);
                p3 += dot(p3, p3.zyx + 31.32);
                return frac((p3.x + p3.y) * p3.z);
            }

            float vnoise(float3 x)
            {
                float3 i = floor(x);
                float3 f = frac(x);
                f = f * f * (3.0 - 2.0 * f);
                float n000 = hash13(i + float3(0,0,0));
                float n100 = hash13(i + float3(1,0,0));
                float n010 = hash13(i + float3(0,1,0));
                float n110 = hash13(i + float3(1,1,0));
                float n001 = hash13(i + float3(0,0,1));
                float n101 = hash13(i + float3(1,0,1));
                float n011 = hash13(i + float3(0,1,1));
                float n111 = hash13(i + float3(1,1,1));
                return lerp(lerp(lerp(n000, n100, f.x), lerp(n010, n110, f.x), f.y),
                            lerp(lerp(n001, n101, f.x), lerp(n011, n111, f.x), f.y), f.z);
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                VertexPositionInputs pos = GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs nrm = GetVertexNormalInputs(IN.normalOS);
                OUT.positionCS = pos.positionCS;
                OUT.positionWS = pos.positionWS;
                OUT.normalWS = nrm.normalWS;
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                float3 N = normalize(IN.normalWS);
                float3 V = normalize(GetWorldSpaceViewDir(IN.positionWS));

                // texture : floutee, puis ramenee vers sa couleur moyenne (effet aplat peint)
                half4 tex = SAMPLE_TEXTURE2D_BIAS(_BaseMap, sampler_BaseMap, IN.uv, _Blur);
                half3 avgColor = SAMPLE_TEXTURE2D_LOD(_BaseMap, sampler_BaseMap, IN.uv, 10).rgb;
                half4 albedo;
                albedo.rgb = lerp(avgColor, tex.rgb, _TexDetail) * _BaseColor.rgb;
                albedo.a = tex.a * _BaseColor.a;
                if (_Cutoff > 0) clip(albedo.a - _Cutoff);
                albedo.rgb *= _Exposure;

                // decals (URP Decal Projector en mode DBuffer)
                #if defined(_DBUFFER)
                    ApplyDecalToBaseColor(IN.positionCS, albedo.rgb);
                #endif

                // --- lumiere principale (soleil de la fenetre) ---
                float4 shadowCoord = TransformWorldToShadowCoord(IN.positionWS);
                Light mainLight = GetMainLight(shadowCoord);

                float ndl = saturate(dot(N, mainLight.direction));
                float l = ndl * mainLight.shadowAttenuation;

                // le bruit fait trembler la frontiere des bandes comme un coup de pinceau
                float brush = vnoise(IN.positionWS * _BrushScale) - 0.5;
                l += brush * _BrushStrength;

                float sMid = smoothstep(_ShadowCut - _Softness, _ShadowCut + _Softness, l);
                float sLit = smoothstep(_LitCut - _Softness, _LitCut + _Softness, l);

                float3 tint = lerp(_ShadowColor.rgb, _MidColor.rgb, sMid);
                tint = lerp(tint, _LitColor.rgb * mainLight.color, sLit);

                float3 col = albedo.rgb * tint;

                // --- lumieres additionnelles (bougie, lampe) en bandes aussi ---
                #if defined(_ADDITIONAL_LIGHTS)
                {
                    InputData inputData = (InputData)0;
                    inputData.positionWS = IN.positionWS;
                    inputData.normalWS = N;
                    inputData.viewDirectionWS = V;
                    inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(IN.positionCS);
                    half4 shadowMask = half4(1,1,1,1);

                    float3 extra = 0;
                    uint pixelLightCount = GetAdditionalLightsCount();

                    #if USE_FORWARD_PLUS
                    for (uint fpIndex = 0; fpIndex < min(URP_FP_DIRECTIONAL_LIGHTS_COUNT, MAX_VISIBLE_LIGHTS); fpIndex++)
                    {
                        FORWARD_PLUS_SUBTRACTIVE_LIGHT_CHECK
                        Light fpLight = GetAdditionalLight(fpIndex, IN.positionWS, shadowMask);
                        float w = saturate(dot(N, fpLight.direction)) * fpLight.distanceAttenuation * fpLight.shadowAttenuation;
                        extra += fpLight.color * smoothstep(_AddCut - _Softness, _AddCut + _Softness, w);
                    }
                    #endif

                    LIGHT_LOOP_BEGIN(pixelLightCount)
                        Light light = GetAdditionalLight(lightIndex, IN.positionWS, shadowMask);
                        float w = saturate(dot(N, light.direction)) * light.distanceAttenuation * light.shadowAttenuation;
                        extra += light.color * smoothstep(_AddCut - _Softness, _AddCut + _Softness, w);
                    LIGHT_LOOP_END

                    col += albedo.rgb * extra * _AddStrength;
                }
                #endif

                // --- reflet en aplat (utile pour le laiton) ---
                float3 H = normalize(mainLight.direction + V);
                float spec = pow(saturate(dot(N, H)), _Gloss) * mainLight.shadowAttenuation;
                spec = smoothstep(_SpecCut - _SpecSoft, _SpecCut + _SpecSoft, spec);
                col += _SpecTint.rgb * spec * mainLight.color;

                // --- rim light cote lumiere ---
                float fres = 1.0 - saturate(dot(N, V));
                float rim = smoothstep(1.0 - _RimWidth, 1.0 - _RimWidth + _RimSoft, fres);
                rim *= smoothstep(-0.1, 0.4, dot(N, mainLight.direction));
                col += _RimColor.rgb * rim * _RimStrength;

                // --- auto-eclairage : retrouve la couleur brute (fenetre, rideau, sources) ---
                col = lerp(col, albedo.rgb, _Unlit);

                // --- grain ---
                float g = hash13(float3(IN.positionCS.xy, 0.0)) - 0.5;
                col *= 1.0 + g * _Grain;

                return half4(col, 1.0);
            }
            ENDHLSL
        }

        // ------------------------------------------------------------
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode"="ShadowCaster" }
            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull Back

            HLSLPROGRAM
            #pragma vertex ShadowVert
            #pragma fragment ShadowFrag
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            float3 _LightDirection;
            float3 _LightPosition;

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float2 uv         : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv         : TEXCOORD0;
            };

            Varyings ShadowVert(Attributes IN)
            {
                Varyings OUT;
                float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                float3 normalWS = TransformObjectToWorldNormal(IN.normalOS);

                #if _CASTING_PUNCTUAL_LIGHT_SHADOW
                    float3 lightDirectionWS = normalize(_LightPosition - positionWS);
                #else
                    float3 lightDirectionWS = _LightDirection;
                #endif

                float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));

                #if UNITY_REVERSED_Z
                    positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE * positionCS.w);
                #else
                    positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE * positionCS.w);
                #endif

                OUT.positionCS = positionCS;
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                return OUT;
            }

            half4 ShadowFrag(Varyings IN) : SV_Target
            {
                if (_Cutoff > 0)
                {
                    half a = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv).a * _BaseColor.a;
                    clip(a - _Cutoff);
                }
                return 0;
            }
            ENDHLSL
        }

        // ------------------------------------------------------------
        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode"="DepthOnly" }
            ZWrite On
            ColorMask R
            Cull Back

            HLSLPROGRAM
            #pragma vertex DepthVert
            #pragma fragment DepthFrag

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv         : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv         : TEXCOORD0;
            };

            Varyings DepthVert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                return OUT;
            }

            half DepthFrag(Varyings IN) : SV_Target
            {
                if (_Cutoff > 0)
                {
                    half a = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv).a * _BaseColor.a;
                    clip(a - _Cutoff);
                }
                return IN.positionCS.z;
            }
            ENDHLSL
        }
    }
}
