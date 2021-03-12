// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Custom/glass"
{
    Properties
    {
        _Color0 ("Glass Color", Color) = (1,1,1,1)
        _Color1 ("Dirt Color",Color) = (1,1,1,1)
        _CubeMap ("Cube Map", Cube) = "Skybox" {}
        _BumpMap("Normal Map",2D)="bump"{}
        _Mask ("Mask",2D)="white" {}
        _FresnelScale("Fresnel Scale", Range(0,1))=0.5
    }
    SubShader
    {
        Tags { "Queue"="Overlay" "RenderType"="Fade"}
        LOD 200
        Pass{
           Tags{"LightMode"="ForwardBase"}

            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite On
            CGPROGRAM
            
            #pragma multi_compile_fwdbase
            #pragma vertex vert
            #pragma fragment frag

            #include "Lighting.cginc"
            #include "AutoLight.cginc"

            float4 _Color0;
            float4 _Color1;

            sampler2D _BumpMap;
            float4 _BumpMap_ST;
           
            sampler2D _Mask;
            float4 _Mask_ST;

            samplerCUBE _CubeMap;
            //float4 _CubeMap_ST;

            float _FresnelScale;

            struct a2v{
            float4 vertex : POSITION;
            float3 normal : NORMAL;
            float4 tangent : TANGENT;
            float2 texcoord:TEXCOORD0;

			};
            struct v2f{
                float4 pos : SV_POSITION;
                float4 uv : TEXCOORD0;

                float4 TtoW0 : TEXCOORD1;
                float4 TtoW1 : TEXCOORD2;
                float4 TtoW2 : TEXCOORD3;

                float4 scrPos : TEXCOORD4;

			};

            v2f vert(a2v v){
                v2f o;
                o.pos=UnityObjectToClipPos(v.vertex);
                o.scrPos=ComputeGrabScreenPos(o.pos);

                o.uv.xy=TRANSFORM_TEX(v.texcoord,_BumpMap);

                float3 worldPos =mul(unity_ObjectToWorld,v.vertex).xyz;
                fixed3 worldNormal =UnityObjectToWorldNormal(v.normal);
                fixed3 worldTangent =UnityObjectToWorldDir(v.tangent.xyz);
                fixed3 worldBinormal =cross(worldNormal,worldTangent)*v.tangent.w;

                o.TtoW0 = float4(worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x);
                o.TtoW1 = float4(worldTangent.y, worldBinormal.y, worldNormal.y, worldPos.y);
                o.TtoW2 = float4(worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z);

                return o; 
			} 

            fixed4 frag(v2f i):SV_Target{
                float3 worldPos = float3(i.TtoW0.w, i.TtoW1.w, i.TtoW2.w);
				fixed3 worldViewDir = normalize(UnityWorldSpaceViewDir(worldPos));
			    fixed3 lightDir =normalize(UnityWorldSpaceLightDir(worldPos));
			    fixed3 bump = UnpackNormal(tex2D(_BumpMap, i.uv.xy));	
			 
                float texMask =tex2D(_Mask, i.uv.xy).r;
                // texMask =saturate(texMask+_Color0.a);
			    float opaqMask =min(saturate(texMask+_Color0.a)*4,1);
                //fixed3 col=tex2D(_RefractionTex,i.scrPos.xy/i.scrPos.w).rgb;

				bump = normalize(half3(dot(i.TtoW0.xyz, bump), dot(i.TtoW1.xyz, bump), dot(i.TtoW2.xyz, bump)));
				fixed3 reflDir = reflect(-worldViewDir, bump);
				//fixed4 texColor = tex2D(_MainTex, i.uv.xy);
                
              //  fixed4 skyData =UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0,reflDir,1);
              //  fixed3 skyColor =DecodeHDR(skyData,unity_SpecCube0_HDR);

                fixed3 skyColor = texCUBE(_CubeMap,reflDir).rgb;

                fixed3 diffuse = _LightColor0.rgb*_Color1*(0.5*dot(bump,lightDir)+0.5);

			    fixed3 baseColor = diffuse*opaqMask+_Color0*(1-opaqMask);
               
                
                fixed fresnel = _FresnelScale+(1-_FresnelScale)*pow(1-dot(worldViewDir,bump),5);
                skyColor=lerp(baseColor,skyColor,saturate(fresnel));
                fixed3 finalColor = baseColor*texMask+skyColor*(1-texMask);

				return fixed4(finalColor,saturate(texMask+_Color0.a));
            }

            ENDCG
        }
     // */
    }
    FallBack "Diffuse"
}
