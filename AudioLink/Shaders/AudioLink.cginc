// Map of where features in AudioLink are.
#define ALPASS_DFT                      int2(0,4)
#define ALPASS_WAVEFORM                 int2(0,6)
#define ALPASS_AUDIOLINK                int2(0,0)
#define ALPASS_AUDIOBASS                int2(0,0)
#define ALPASS_AUDIOLOWMIDS             int2(0,1)
#define ALPASS_AUDIOHIGHMIDS            int2(0,2)
#define ALPASS_AUDIOTREBLE              int2(0,3)
#define ALPASS_AUDIOLINKHISTORY         int2(1,0)
#define ALPASS_GENERALVU                int2(0,22)
#define ALPASS_GENERALVU_INSTANCE_TIME  int2(2,22)
#define ALPASS_GENERALVU_LOCAL_TIME     int2(3,22)
#define ALPASS_CCINTERNAL               int2(12,22)
#define ALPASS_CCSTRIP                  int2(0,24)
#define ALPASS_CCLIGHTS                 int2(0,25)
#define ALPASS_AUTOCORRELATOR           int2(0,27)

// Some basic constants to use (Note, these should be compatible with
// future version of AudioLink, but may change.
#define AUDIOLINK_SAMPHIST              3069        // Internal use for algos, do not change.
#define AUDIOLINK_SAMPLEDATA24          2046
#define AUDIOLINK_EXPBINS               24
#define AUDIOLINK_EXPOCT                10
#define AUDIOLINK_ETOTALBINS            (AUDIOLINK_EXPBINS * AUDIOLINK_EXPOCT)
#define AUDIOLINK_WIDTH                 128
#define AUDIOLINK_SPS                   48000       // Samples per second
#define AUDIOLINK_ROOTNOTE              0
#define AUDIOLINK_4BAND_FREQFLOOR       0.123
#define AUDIOLINK_4BAND_FREQCEILING     1
#define AUDIOLINK_BOTTOM_FREQUENCY      13.75
#define AUDIOLINK_BASE_AMPLITUDE        2.5
#define AUDIOLINK_DELAY_COEFFICIENT_MIN 0.3
#define AUDIOLINK_DELAY_COEFFICIENT_MAX 0.9
#define AUDIOLINK_DFT_Q                 4.0
#define AUDIOLINK_TREBLE_CORRECTION     5.0

// ColorChord constants
#define COLORCHORD_EMAXBIN              192
#define COLORCHORD_IIR_DECAY_1          0.90
#define COLORCHORD_IIR_DECAY_2          0.85
#define COLORCHORD_CONSTANT_DECAY_1     0.01
#define COLORCHORD_CONSTANT_DECAY_2     0.0
#define COLORCHORD_NOTE_CLOSEST         3.0
#define COLORCHORD_NEW_NOTE_GAIN        8.0
#define COLORCHORD_MAX_NOTES            10

// We use glsl_mod for most calculations because it behaves better
// on negative numbers, and in some situations actually outperforms
// HLSL's modf().
#ifndef glsl_mod
#define glsl_mod(x,y) (((x)-(y)*floor((x)/(y))))
#endif

uniform float4               _AudioTexture_TexelSize;

#ifdef SHADER_TARGET_SURFACE_ANALYSIS
#define AUDIOLINK_STANDARD_INDEXING
#endif

// Mechanism to index into texture.
#ifdef AUDIOLINK_STANDARD_INDEXING
    sampler2D _AudioTexture;
    #define AudioLinkData(xycoord) tex2Dlod(_AudioTexture, float4(uint2(xycoord) * _AudioTexture_TexelSize.xy, 0, 0))
#else
    uniform Texture2D<float4>   _AudioTexture;
    #define AudioLinkData(xycoord) _AudioTexture[uint2(xycoord)]
#endif

// Convenient mechanism to read from the AudioLink texture that handles reading off the end of one line and onto the next above it.
float4 AudioLinkDataMultiline(uint2 xycoord) { return AudioLinkData(uint2(xycoord.x % AUDIOLINK_WIDTH, xycoord.y + xycoord.x/AUDIOLINK_WIDTH)); }

// Mechanism to sample between two adjacent pixels and lerp between them, like "linear" supesampling
float4 AudioLinkLerp(float2 xy) { return lerp( AudioLinkData(xy), AudioLinkData(xy+int2(1,0)), frac( xy.x ) ); }

// Same as AudioLinkLerp but properly handles multiline reading.
float4 AudioLinkLerpMultiline(float2 xy) { return lerp(AudioLinkDataMultiline(xy), AudioLinkDataMultiline(xy+float2(1,0)), frac(xy.x)); }

//Tests to see if Audio Link texture is available
bool AudioLinkIsAvailable()
{
    #if !defined(AUDIOLINK_STANDARD_INDEXING)
        int width, height;
        _AudioTexture.GetDimensions(width, height);
        return width > 16;
    #else
        return _AudioTexture_TexelSize.z > 16;
    #endif
}

//Get version of audiolink present in the world, 0 if no audiolink is present
float AudioLinkGetVersion()
{
    int2 dims;
    #if !defined(AUDIOLINK_STANDARD_INDEXING)
        _AudioTexture.GetDimensions(dims.x, dims.y);
    #else
        dims = _AudioTexture_TexelSize.zw;
    #endif

    if (dims.x >= 128)
        return AudioLinkData(ALPASS_GENERALVU).x;
    else if (dims.x > 16)
        return 1;
    else
        return 0;
}

// Decompress a RGBA FP16 into a really big number, this is used in some sections of the info block.
#define DecodeLongFloat(vALValue)  (vALValue.r + vALValue.g*1024 + vALValue.b * 1048576 + vALValue.a * 1073741824)

// This pulls data from this texture.
#define GetSelfPixelData(xy) _SelfTexture2D[xy]

// Extra utility functions for time.
uint ALDecodeDataAsUInt(uint2 indexloc)
{
    half4 rpx = AudioLinkData(indexloc);
    return DecodeLongFloat(rpx);
}

//Note: This will truncate time to every 134,217.728 seconds (~1.5 days of an instance being up) to prevent floating point aliasing.
// if your code will alias sooner, you will need to use a different function.
float ALDecodeDataAsFloat(uint2 indexloc)
{
    return (ALDecodeDataAsUInt(indexloc) & 0x7ffffff) / 1000.;
}

float Remap(float t, float a, float b, float u, float v) { return ((t-a) / (b-a)) * (v-u) + u; }

float3 CCHSVtoRGB(float3 HSV)
{
    float3 RGB = 0;
    float C = HSV.z * HSV.y;
    float H = HSV.x * 6;
    float X = C * (1 - abs(fmod(H, 2) - 1));
    if (HSV.y != 0)
    {
        float I = floor(H);
        if (I == 0) { RGB = float3(C, X, 0); }
        else if (I == 1) { RGB = float3(X, C, 0); }
        else if (I == 2) { RGB = float3(0, C, X); }
        else if (I == 3) { RGB = float3(0, X, C); }
        else if (I == 4) { RGB = float3(X, 0, C); }
        else { RGB = float3(C, 0, X); }
    }
    float M = HSV.z - C;
    return RGB + M;
}

float3 CCtoRGB(float bin, float intensity, int rootNote)
{
    float note = bin / AUDIOLINK_EXPBINS;

    float hue = 0.0;
    note *= 12.0;
    note = glsl_mod(4. - note + rootNote, 12.0);
    {
        if(note < 4.0)
        {
            //Needs to be YELLOW->RED
            hue = (note) / 24.0;
        }
        else if(note < 8.0)
        {
            //            [4]  [8]
            //Needs to be RED->BLUE
            hue = (note-2.0) / 12.0;
        }
        else
        {
            //             [8] [12]
            //Needs to be BLUE->YELLOW
            hue = (note - 4.0) / 8.0;
        }
    }
    float val = intensity - 0.1;
    return CCHSVtoRGB(float3(fmod(hue, 1.0), 1.0, clamp(val, 0.0, 1.0)));
}


////////////////////////////////////////////////////////////////////
// General debug functions below here

// Shockingly, including the ability to render text doesn't
// slow down number printing if text isn't used.
// A basic versino of the debug screen without text was only 134
// instructions.

float PrintChar(uint selChar, float2 charUV, float2 softness)
{
	//.x = 15% .y = 35% added, it's 1.0. ( 0 1 would be 35% )
    const static uint2 bitmapNumberFont[31] = {
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

