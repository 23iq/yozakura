package hyprland

import "math"

// logicalMonitorSize mirrors CMonitor::m_size: the mode size, sides swapped
// for an odd transform (90/270 and their flipped variants), divided by the
// scale and rounded half away from zero (Vector2D::round).
func logicalMonitorSize(width, height int, scale float64, transform int) (int, int) {
	if transform%2 == 1 {
		width, height = height, width
	}
	if scale <= 0 {
		scale = 1
	}
	return int(math.Round(float64(width) / scale)), int(math.Round(float64(height) / scale))
}
