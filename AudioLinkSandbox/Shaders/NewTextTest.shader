﻿Shader "Unlit/NewTextTest"
{
    Properties
    {
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };
			
#ifndef glsl_mod
#define glsl_mod(x,y) (((x)-(y)*floor((x)/(y))))
#endif


////////////////////////////////////////////////////////////////////
// General debug functions below here

// Shockingly, including the ability to render text doesn't
// slow down number printing if text isn't used.
// A basic versino of the debug screen without text was only 134
// instructions.

float PrintChar(uint selChar, float2 charUV, float2 softness)
{
	//.x = 15% .y = 35% added, it's 1.0. ( 0 1 would be 35% )
    const static uint2 bitmapNumberFont[32] = {
		{  6990528,  15379168 }, //  0  '0' // 0110 1010 1010 1010 1100 0000      1110 1010 1010 1010 1110 0000
		{  4998368,   4998368 }, //  1  '1' // 0100 1100 0100 0100 1110 0000      0100 1100 0100 0100 1110 0000
		{ 14870752,  14870752 }, //  2  '2' // 1110 0010 1110 1000 1110 0000      1110 0010 1110 1000 1110 0000
		{ 14828256,  14836448 }, //  3  '3' // 1110 0010 0100 0010 1110 0000      1110 0010 0110 0010 1110 0000
		{  9101856,   9101856 }, //  4  '4' // 1000 1010 1110 0010 0010 0000      1000 1010 1110 0010 0010 0000
		{ 15262432,  15262432 }, //  5  '5' // 1110 1000 1110 0010 1110 0000      1110 1000 1110 0010 1110 0000
		{  6875872,  15264480 }, //  6  '6' // 0110 1000 1110 1010 1110 0000      1110 1000 1110 1010 1110 0000
		{ 14829120,  14836800 }, //  7  '7' // 1110 0010 0100 0110 0100 0000      1110 0010 0110 0100 0100 0000
		{ 15395552,  15395552 }, //  8  '8' // 1110 1010 1110 1010 1110 0000      1110 1010 1110 1010 1110 0000
		{ 15393472,  15393504 }, //  9  '9' // 1110 1010 1110 0010 1100 0000      1110 1010 1110 0010 1110 0000
		{        0,         0 }, // 10  ' '
		{  4472896,   4472896 }, // 11  '!' // 0100 0100 0100 0000 0100 0000      0100 0100 0100 0000 0100 0000  
		{ 11141120,  11141120 }, // 12  '"' // 1010 1010 0000 0000 0000 0000      1010 1010 0000 0000 0000 0000
		{ 11447968,  11447968 }, // 13  '#' // 1010 1110 1010 1110 1010 0000      1010 1110 1010 1110 1010 0000
		{  5162724,   5162724 }, // 14  '$' // 0100 1110 1100 0110 1110 0100      0100 1110 1100 0110 1110 0100
		{  4868704,  15395552 }, // 15  '&' // 0100 1010 0100 1010 0110 0000      1110 1010 1110 1010 1110 0000
		{  4456448,   4456448 }, // 16  ''' // 0100 0100 0000 0000 0000 0000      1110 1010 1110 1010 1110 0000
		{  2376736,   6571104 }, // 17  '(' // 0010 0100 0100 0100 0010 0000      0110 0100 0100 0100 0110 0000
		{  8668288,  12862656 }, // 18  ')' // 1000 0100 0100 0100 1000 0000      1100 0100 0100 0100 1100 0000
		{   674304,    978432 }, // 19  '*' // 0000 1010 0100 1010 0000 0000      0000 1110 1110 1110 0000 0000
		{   320512,    320512 }, // 20  '+' // 0000 0100 1110 0100 0000 0000      0000 0100 1110 0100 0000 0000
		{     1088,      1228 }, // 21  ',' // 0000 0000 0000 0100 0100 0000      0000 0000 0000 0100 1100 1100
		{    57344,     57344 }, // 22  '-' // 0000 0000 1110 0000 0000 0000      0000 0000 1110 0000 0000 0000
		{       64,        64 }, // 23  '.' // 0000 0000 0000 0000 0100 0000      0000 0000 0000 0000 0100 0000
		{  2246784,   2287744 }, // 24  '/' // 0010 0010 0100 1000 1000 0000      0010 0010 1110 1000 1000 0000
		{   263168,    263168 }, // 25  ':' // 0000 0100 0000 0100 0000 0000      0000 0100 0000 0100 0000 0000
		{   263232,    263244 }, // 26  ';' // 0000 0100 0000 0100 0100 0000      0000 0100 0000 0100 0100 1100
		{  2393120,   7261792 }, // 27  '<' // 0010 0100 1000 0100 0010 0000      0110 1110 1100 1110 0110 0000
		{   921088,    921088 }, // 28  '=' // 0000 1110 0000 1110 0000 0000      0000 1110 0000 1110 0000 0000
		{  8660096,  13528768 }, // 29  '>' // 1000 0100 0010 0100 1000 0000      1100 1110 0110 1110 1100 0000
		{ 12730432,  14836800 }, // 30  '?' // 1100 0010 0100 0000 0100 0000      1110 0010 0110 0100 0100 0000
		{ 0,  0 }, // 31  '@' // Not written yet.
		//Maybe follow ascii?
    };

	charUV += float2( 0, 0.5);
    uint2 bitmap = bitmapNumberFont[selChar];
    uint2 charXY = charUV;
    uint index = charXY.x + charXY.y * 4-4;
    uint4 shft = uint4( 0, 1, 4, 5 ) + index;
    float4 neighbors = (( bitmap.y >> shft ) & 1 )?( ( ( bitmap.x >> shft ) & 1 ) ? 1 : .35 ) : ( ( ( bitmap.x >> shft ) & 1 ) ? .15 : 0 );
    float2 shift = smoothstep(0, 1, frac(charUV));
    float o = lerp(
        lerp(neighbors.x, neighbors.y, shift.x),
        lerp(neighbors.z, neighbors.w, shift.x), shift.y);
    return saturate( o * softness - softness / 2);
}


// Used for debugging
float PrintNumberOnLine(float number, uint fixeddiv, uint digit, float2 charUV, int offset, bool leadzero, float2 softness)
{
    uint selnum;
    if(number < 0 && digit == 0)
    {
        selnum = 22;  // - sign
    }
    else
    {
        number = abs(number);

        if(digit == fixeddiv)
        {
            selnum = 23; // .
        }
        else
        {
            int dmfd = (int)digit - (int)fixeddiv;
            if(dmfd > 0)
            {
                //fractional part.
                float l10 = pow(10., dmfd);
                selnum = ((uint)(number * l10)) % 10;
            }
            else
            {
                float l10 = pow(10., (float)(dmfd + 1));
                selnum = ((uint)(number * l10));

                //Disable leading 0's?
                if(!leadzero && dmfd != -1 && selnum == 0 && dmfd < 0.5)
                    selnum = 10; // space
                else
                    selnum %= (uint)10;
            }
        }
    }

    return PrintChar(selnum, charUV, softness);
}


            sampler2D _MainTex;
            float4 _MainTex_ST;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
		
                float2 iuv = i.uv;
                iuv.y = 1.-iuv.y;
                const uint rows = 10;
                const uint cols = 10;
                const uint number_area_cols = 11;
                
                float2 pos = iuv*float2(cols,rows);
                uint2 dig = (uint2)(pos);

                // This line of code is tricky;  We determine how much we should soften the edge of the text
                // based on how quickly the text is moving across our field of view.  This gives us realy nice
                // anti-aliased edges.
                float2 softness = 2./pow( length( float2( ddx( pos.x ), ddy( pos.y ) ) ), 0.5 );

                // Another option would be to set softness to 20 and YOLO it.

                float2 fmxy = float2( 4, 6 ) - (glsl_mod(pos,1.)*float2(4.,6.));

                
				if( dig.y < 2 )
				{
					uint charlines[20] = { 
						13, 13, 13, 13, 13, 13, 13, 13, 13, 13,
						13, 13, 13, 13, 13, 13, 13, 13, 13, 13,
						};
                    return PrintChar( charlines[dig.x+dig.y*10], fmxy, softness );
				}
				else if( dig.y == 2 )
				{
					int offset = 3;
					float value = _Time.y;
					return PrintNumberOnLine( value, number_area_cols-offset, dig.x, fmxy, offset, false, softness );                
				}
				else
				{
					uint sendchar = (dig.y-3)*10 + dig.x;
                    return PrintChar( sendchar, fmxy, softness );
				}
            }
            ENDCG
        }
    }
}
