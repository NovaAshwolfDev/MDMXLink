Shader "Milo/MDMXLink/Standard"
{
    Properties
    {
        _Channel ("Start DMX Channel", Float) = 1352 // tilt bars ok
        _FixtureCount ("Fixture Count", Float) = 4
        _FixtureType ("Fixture Type", Range(0, 2)) = 0
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
        float CHANNEL_SPACING = 6; // 7 (never let me comment again)
        #define FIXTURE_TILTBAR 0
        #define FIXTURE_SPOTLIGHT 1
        #define FIXTURE_LASER2D 2

        sampler2D _Udon_MDMX, _Albedo, _Normal, _MaskMap;
        float4 _Udon_MDMX_TexelSize;

        float _Channel, _FixtureCount;
        float _Metallic, _Smoothness;
        float _FixtureType;

        struct MDMXFixtureMap {
            int dimmer;
            int strobe;
            int red;
            int green;
            int blue;
        };

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
        void GetFixtureMap(int type, out MDMXFixtureMap map)
        {
            // gobo spotlight
            if (type == 1)
            {
                map.dimmer = 5;
                map.strobe = 6;
                map.red    = 7;
                map.green  = 8;
                map.blue   = 9;
                CHANNEL_SPACING = 13;
                return;
            }
            // 2D laser
            if (type == 2)
            {
                map.dimmer = 5;
                map.strobe = 6;
                map.red    = 7;
                map.green  = 8;
                map.blue   = 9;
                CHANNEL_SPACING = 26;
                return;
            }
            // fallback
            map.dimmer = -1;
            map.strobe = -1;
            map.red    = -1;
            map.green  = -1;
            map.blue   = -1;
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

            float3 colA;
            float3 colB;

            int fx = (int)_FixtureType;

            if (fx == FIXTURE_TILTBAR)
            {
                float brightnessA = SampleDMX(chA - 1); // i almost forgot this sorry guys
                float strobeA     = SampleDMX(chA + 3);

                float brightnessB = SampleDMX(chB - 1); 
                float strobeB     = SampleDMX(chB + 3); // + 3 for the strobe i think

                colA = ReadFixtureRGB(chA) * brightnessA * getStrobe(strobeA);
                colB = ReadFixtureRGB(chB) * brightnessB * getStrobe(strobeB);
            }
            else
            {
                MDMXFixtureMap m;
                GetFixtureMap(fx, m);

                float dimA    = SampleDMX(chA + m.dimmer);
                float strobeA = SampleDMX(chA + m.strobe);
                float3 rgbA = float3(
                    SampleDMX(chA + m.red),
                    SampleDMX(chA + m.green),
                    SampleDMX(chA + m.blue)
                );

                float dimB    = SampleDMX(chB + m.dimmer);
                float strobeB = SampleDMX(chB + m.strobe);
                float3 rgbB = float3(
                    SampleDMX(chB + m.red),
                    SampleDMX(chB + m.green),
                    SampleDMX(chB + m.blue)
                );

                colA = rgbA * dimA * getStrobe(strobeA);
                colB = rgbB * dimB * getStrobe(strobeB);
            }

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
    CustomEditor "MDMXLinkGUI"
}
