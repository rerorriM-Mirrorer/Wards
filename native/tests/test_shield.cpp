#include "../ShieldGeometry.h"

#include <cassert>
#include <cmath>
#include <iostream>

int main() {
    using wards_shield::Point;
    assert(std::fabs(wards_shield::wave_alpha(4.f,4.f,1.f)-1.f)<.0001f);
    assert(wards_shield::wave_alpha(2.f,4.f,1.f)==0.f);
    assert(wards_shield::wave_alpha(5.f,4.f,1.f)==0.f);
    assert(std::fabs(wards_shield::wave_alpha(4.5f,4.f,1.f)-.5f)<.0001f);
    assert(wards_shield::wave_alpha(4.f,4.f,0.f)==0.f);

    const Point first=wards_shield::hex_vertex(0.f,0.f,1.f,0,0.f);
    const Point second=wards_shield::hex_vertex(0.f,0.f,1.f,1,0.f);
    assert(std::fabs(first.x-1.f)<.0001f && std::fabs(first.y)<.0001f);
    assert(std::fabs(second.x-.5f)<.0001f && std::fabs(second.y-.8660254f)<.0001f);

    assert(wards_shield::cell_inside_circle(0.f,0.f,.1f,1.f));
    assert(!wards_shield::cell_inside_circle(.9f,0.f,.2f,1.f));
    const Point even=wards_shield::grid_center(0,0,1.f);
    const Point odd=wards_shield::grid_center(0,1,1.f);
    assert(std::fabs(even.x)<.0001f && std::fabs(even.y)<.0001f);
    assert(std::fabs(odd.x-.75f)<.0001f && std::fabs(odd.y-1.7320508f)<.0001f);
    std::cout << "Shield geometry: 11 assertions passed\n";
}
