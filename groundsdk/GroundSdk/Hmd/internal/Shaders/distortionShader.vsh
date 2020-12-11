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

attribute highp vec2 aPosition;
attribute highp vec2 aTexCoord;
attribute highp vec4 aColor;

uniform highp vec2 uEyeToSourceOffset;
uniform highp vec2 uEyeToSourceScale;
uniform highp vec2 uTextureCoordOffset;
uniform highp vec2 uTextureCoordScale;
uniform highp vec3 uTextureCoordScaleDistFactor;

varying highp vec2 vTexCoord0;
varying highp vec2 vTexCoord1;
varying highp vec2 vTexCoord2;
varying highp vec4 vColor;

void main()
{
    gl_Position.x = aPosition.x * uEyeToSourceScale.x + uEyeToSourceOffset.x;
    gl_Position.y = aPosition.y * uEyeToSourceScale.y + uEyeToSourceOffset.y;
    gl_Position.z = 0.5;
    gl_Position.w = 1.0;

    float var = 0.5;
    vec2 center = vec2(0.5,0.5);

    vTexCoord0 = ((aTexCoord - center) * (uTextureCoordScale * uTextureCoordScaleDistFactor.x) ) + center + uTextureCoordOffset;
    vTexCoord1 = ((aTexCoord - center) * (uTextureCoordScale * uTextureCoordScaleDistFactor.y) ) + center + uTextureCoordOffset;
    vTexCoord2 = ((aTexCoord - center) * (uTextureCoordScale * uTextureCoordScaleDistFactor.z) ) + center + uTextureCoordOffset;

    vColor = aColor;
}
