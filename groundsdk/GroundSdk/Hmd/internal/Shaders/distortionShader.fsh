// Copyright (C) 2019 Parrot Drones SAS
//
//    Redistribution and use in source and binary forms, with or without
//    modification, are permitted provided that the following conditions
//    are met:
//    * Redistributions of source code must retain the above copyright
//      notice, this list of conditions and the following disclaimer.
//    * Redistributions in binary form must reproduce the above copyright
//      notice, this list of conditions and the following disclaimer in
//      the documentation and/or other materials provided with the
//      distribution.
//    * Neither the name of the Parrot Company nor the names
//      of its contributors may be used to endorse or promote products
//      derived from this software without specific prior written
//      permission.
//
//    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
//    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
//    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
//    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
//    PARROT COMPANY BE LIABLE FOR ANY DIRECT, INDIRECT,
//    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
//    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
//    OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
//    AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
//    OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
//    OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
//    SUCH DAMAGE.

uniform sampler2D uTexture0;
varying highp vec2 vTexCoord0;
varying highp vec2 vTexCoord1;
varying highp vec2 vTexCoord2;
varying highp vec4 vColor;
uniform int uLensLimits;

void main()
{
    highp float ResultA = 1.0;

    highp float ResultR;

    if (vTexCoord0.x > 1.0 || vTexCoord0.y > 1.0 || vTexCoord0.x < 0.0 || vTexCoord0.y < 0.0)
    {

        ResultR = (uLensLimits == 1 ? 0.1 : 0.0);
    }
    else
    {
        ResultR = texture2D(uTexture0, vTexCoord0).r;
        ResultA = texture2D(uTexture0, vTexCoord1).a;
    }

    highp float ResultG;
    if (vTexCoord1.x > 1.0 || vTexCoord1.y > 1.0 || vTexCoord1.x < 0.0 || vTexCoord1.y < 0.0)
    {
        ResultG = (uLensLimits == 1 ? 0.2 : 0.0);
    }
    else
    {
        ResultG = texture2D(uTexture0, vTexCoord1).g;
    }

    highp float ResultB;
    if (vTexCoord2.x > 1.0 || vTexCoord2.y > 1.0 || vTexCoord2.x < 0.0 || vTexCoord2.y < 0.0)
    {
        ResultB = (uLensLimits == 1 ? 0.3 : 0.0);
    }
    else
    {
        ResultB = texture2D(uTexture0, vTexCoord2).b;
    }

    gl_FragColor = vec4(ResultR * vColor.r, ResultG * vColor.g , ResultB * vColor.b, ResultA);

}

