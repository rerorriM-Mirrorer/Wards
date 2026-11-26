#pragma once

#include <algorithm>
#include <cmath>

namespace wards_shield {

struct Point {
    float x;
    float y;
};

inline float smoothstep(float value) {
    const float x=std::clamp(value,0.f,1.f);
    return x*x*(3.f-2.f*x);
}

inline float wave_alpha(float distance,float wave_radius,float half_width) {
    if(!std::isfinite(distance)||!std::isfinite(wave_radius)||!std::isfinite(half_width)||half_width<=0.f)
        return 0.f;
    return smoothstep(1.f-std::fabs(distance-wave_radius)/half_width);
}

// Flat-top hexes on a staggered grid. Keeping the entire cell inside the disk
// guarantees that no clipped edge can flash outside the shield perimeter.
inline bool cell_inside_circle(float x,float y,float hex_radius,float shield_radius) {
    if(!std::isfinite(x)||!std::isfinite(y)||!std::isfinite(hex_radius)||!std::isfinite(shield_radius))
        return false;
    return hex_radius>0.f && shield_radius>0.f &&
        std::hypot(x,y)+hex_radius<=shield_radius*.94f;
}

inline Point hex_vertex(float center_x,float center_y,float radius,int vertex,float rotation) {
    constexpr float two_pi=6.28318530718f;
    const float angle=rotation+two_pi*static_cast<float>(vertex)/6.f;
    return {center_x+radius*std::cos(angle),center_y+radius*std::sin(angle)};
}

inline Point grid_center(int column,int row,float radius) {
    constexpr float row_factor=1.73205080757f;
    const float x=static_cast<float>(column)*1.5f*radius+((row%2)!=0?radius*.75f:0.f);
    const float y=static_cast<float>(row)*row_factor*radius;
    return {x,y};
}

} // namespace wards_shield
