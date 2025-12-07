Shader "Milo/MDMXLink/Standard"
{
    Properties
    {
        _Channel      ("Start DMX Channel", Float) = 1352 // tilt bars ok
        _FixtureCount ("Fixture Count", Float) = 4
        _Albedo ("Albedo Map", 2D) = "white" {}
        _Normal ("Normal Map", 2D) = "white" {}
        _MaskMap  ("Mask Map", 2D) = "white" {}
        _Metallic ("Metallic", Range(0,1)) = 0
        _Smoothness ("Smoothness", Range(0,1)) = 0.5
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" }
        LOD 300

        CGPROGRAM
        #pragma surface surf Standard fullforwardshadows vertex:vert
        #pragma target 3.0
        #include "UnityCG.cginc"
        #define CHANNEL_SPACING 6 // 7 (never let me comment again)
        sampler2D _Udon_MDMX, _Albedo, _Normal, _MaskMap;
        float4 _Udon_MDMX_TexelSize;

        float _Channel, _FixtureCount;
        float _Metallic, _Smoothness;

        static const float2 DMXSize = float2(128.0, 128.0);

        float2 GetDMXUV(float channel)
        {
            float idx = max(channel - 1.0, 0.0);

            float x = fmod(idx, DMXSize.x);
            float y = floor(idx / DMXSize.x);

            return (float2(x + 0.5, y + 0.5) / DMXSize);
        }

        float SampleDMX(float channel)
        {
            float2 uv = GetDMXUV(channel);
            return tex2D(_Udon_MDMX, uv).r;
        }

        float3 ReadFixtureRGB(float baseCh)
        {
            float r = SampleDMX(baseCh);
            float g = SampleDMX(baseCh + 1);
            float b = SampleDMX(baseCh + 2);
            return float3(r, g, b);
        }
        float getStrobe(float strobeVal)
        {
            return strobeVal == 0 ? 1.0 : strobeVal;
        }

        struct Input
        {
            float2 uv_Albedo;
            float3 objPos : SV_POSITION; // for the gradient position
        };

        void vert(inout appdata_full v, out Input o)
        {
            UNITY_INITIALIZE_OUTPUT(Input, o);
            o.objPos = v.vertex.xyz;
        }

        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            float3 mainTex = tex2D(_Albedo, IN.uv_Albedo);
            float4 normal = tex2D(_Normal, IN.uv_Albedo);
            float mask = tex2D(_MaskMap, IN.uv_Albedo).r;

            float startCh = round(_Channel);
            int count = max((int)_FixtureCount, 1);

            float t = saturate(IN.objPos.y); // awesome!!

            float fIdx = t * (count - 1);
            int idxA = (int)floor(fIdx);
            int idxB = min(idxA + 1, count - 1);

            float blend = frac(fIdx);

            float chA = startCh + idxA * CHANNEL_SPACING;
            float chB = startCh + idxB * CHANNEL_SPACING;

            float brightnessA = SampleDMX(chA - 1); // i almost forgot this sorry guys
            float strobeA     = SampleDMX(chA + 3);
            
            float brightnessB = SampleDMX(chB - 1); 
            float strobeB     = SampleDMX(chB + 3); // + 3 for the strobe i think

            float3 colA =  ReadFixtureRGB(chA) * brightnessA * getStrobe(strobeA);
            float3 colB =  ReadFixtureRGB(chB) * brightnessB * getStrobe(strobeB);

            float3 finalColor = lerp(colA, colB, blend) * mask;
            o.Albedo = mainTex;
            o.Normal = UnpackNormal(normal);
            o.Emission = finalColor;
            o.Metallic = _Metallic;
            o.Smoothness = _Smoothness;
            o.Alpha = 1.0;
        }

        ENDCG
    }
    FallBack "Diffuse"
}
